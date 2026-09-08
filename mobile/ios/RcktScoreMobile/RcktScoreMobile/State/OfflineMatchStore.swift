import Foundation
import Combine

enum OfflineMatchActionKind: String, Codable {
    case scorePoint = "score_point"
    case stroke
    case letCall = "let"
    case serveSide = "serve_side"
    case receiverChoice = "receiver_choice"
    case server
    case timer
    case undo = "undo_action"
    case endMatch = "end_match"
    case matchSettings = "match_settings"
}

struct OfflineQueuedMatchAction: Codable, Identifiable {
    let id: String
    let matchID: String
    let kind: OfflineMatchActionKind
    let scorer: String?
    let playerSide: String?
    let note: String?
    let side: String?
    let currentServer: String?
    let currentServerSide: String?
    let serviceSide: String?
    let matchDurationSeconds: Int?
    let currentServerParticipantID: String?
    let currentReceiver: String?
    let currentReceiverSide: String?
    let currentReceiverParticipantID: String?
    let serveOrder: [String]?
    let receiverDeuceOrder: [String: String]?
    let scoreType: Int?
    let bestOf: Int?
    let player1ShirtColor: String?
    let player2ShirtColor: String?
    let optimisticState: MatchState
    let createdAt: Date

    func send(using apiClient: APIClient) async throws -> MatchDetail {
        switch kind {
        case .scorePoint:
            return try await apiClient.scorePoint(
                matchID: matchID,
                scorer: scorer ?? "player1",
                clientActionID: id
            )
        case .stroke:
            return try await apiClient.awardStroke(
                matchID: matchID,
                playerSide: playerSide ?? "player1",
                clientActionID: id
            )
        case .letCall:
            return try await apiClient.callLet(
                matchID: matchID,
                playerSide: playerSide,
                note: note ?? "General let",
                clientActionID: id
            )
        case .serveSide:
            return try await apiClient.setServeSide(
                matchID: matchID,
                side: side ?? "Right",
                clientActionID: id
            )
        case .receiverChoice:
            return try await apiClient.chooseNoAdReceiverSide(
                matchID: matchID,
                side: side ?? "Right",
                clientActionID: id
            )
        case .server:
            return try await apiClient.selectFirstServer(
                matchID: matchID,
                currentServer: currentServer ?? "",
                currentServerSide: currentServerSide ?? "player1",
                serviceSide: serviceSide ?? "Right",
                currentServerParticipantID: currentServerParticipantID,
                currentReceiver: currentReceiver,
                currentReceiverSide: currentReceiverSide,
                currentReceiverParticipantID: currentReceiverParticipantID,
                serveOrder: serveOrder,
                receiverDeuceOrder: receiverDeuceOrder,
                clientActionID: id
            )
        case .timer:
            return try await apiClient.recordMatchDuration(
                matchID: matchID,
                durationSeconds: matchDurationSeconds ?? 0,
                clientActionID: id
            )
        case .undo:
            return try await apiClient.undoAction(matchID: matchID, clientActionID: id)
        case .endMatch:
            return try await apiClient.endMatchEarly(
                matchID: matchID,
                reason: note ?? "Ended by operator",
                matchDurationSeconds: matchDurationSeconds,
                clientActionID: id
            )
        case .matchSettings:
            return try await apiClient.updateMatchSettings(
                matchID: matchID,
                scoreType: scoreType ?? optimisticState.scoreType,
                bestOf: bestOf ?? optimisticState.bestOf,
                player1ShirtColor: player1ShirtColor,
                player2ShirtColor: player2ShirtColor,
                clientActionID: id
            )
        }
    }
}

private struct OfflineMatchSnapshot: Codable {
    let ownerUsername: String
    let ownerOrganizationID: Int
    var serverMatch: MatchDetail
    var queuedActions: [OfflineQueuedMatchAction]
    var cachedAt: Date
}

@MainActor
final class OfflineMatchStore: ObservableObject {
    @Published private var snapshot: OfflineMatchSnapshot?
    @Published private(set) var isSyncing = false
    @Published private(set) var syncMessage: String?

    private let storageKey = "rcktscore.mobile.offlineActiveMatch"

    init() {
        load()
    }

    var pendingActionCount: Int {
        snapshot?.queuedActions.count ?? 0
    }

    func cachedMatch(matchID: String, session: UserSession?) -> MatchDetail? {
        guard let snapshot,
              snapshot.serverMatch.id == matchID,
              snapshot.ownerUsername.caseInsensitiveCompare(session?.username ?? "") == .orderedSame,
              snapshot.ownerOrganizationID == session?.organizationID else {
            return nil
        }
        return snapshot.serverMatch
    }

    func cachedActiveMatch(session: UserSession?) -> MatchDetail? {
        guard let snapshot,
              snapshot.ownerUsername.caseInsensitiveCompare(session?.username ?? "") == .orderedSame,
              snapshot.ownerOrganizationID == session?.organizationID,
              snapshot.serverMatch.status.lowercased() != "completed" || !snapshot.queuedActions.isEmpty else {
            return nil
        }
        return snapshot.serverMatch
    }

    func projectedState(matchID: String) -> MatchState? {
        guard let snapshot, snapshot.serverMatch.id == matchID else {
            return nil
        }
        return snapshot.queuedActions.last?.optimisticState ?? snapshot.serverMatch.state
    }

    func cache(_ match: MatchDetail, session: UserSession) {
        if var existing = snapshot,
           existing.serverMatch.id == match.id,
           existing.ownerUsername.caseInsensitiveCompare(session.username) == .orderedSame,
           existing.ownerOrganizationID == session.organizationID {
            existing.serverMatch = match
            existing.cachedAt = Date()
            snapshot = existing
        } else {
            snapshot = OfflineMatchSnapshot(
                ownerUsername: session.username,
                ownerOrganizationID: session.organizationID,
                serverMatch: match,
                queuedActions: [],
                cachedAt: Date()
            )
        }
        persist()
    }

    @discardableResult
    func enqueue(
        kind: OfflineMatchActionKind,
        matchID: String,
        scorer: String? = nil,
        playerSide: String? = nil,
        note: String? = nil,
        side: String? = nil,
        currentServer: String? = nil,
        currentServerSide: String? = nil,
        serviceSide: String? = nil,
        matchDurationSeconds: Int? = nil,
        currentServerParticipantID: String? = nil,
        currentReceiver: String? = nil,
        currentReceiverSide: String? = nil,
        currentReceiverParticipantID: String? = nil,
        serveOrder: [String]? = nil,
        receiverDeuceOrder: [String: String]? = nil,
        scoreType: Int? = nil,
        bestOf: Int? = nil,
        player1ShirtColor: String? = nil,
        player2ShirtColor: String? = nil
    ) -> Bool {
        guard var snapshot,
              snapshot.serverMatch.id == matchID,
              let currentState = snapshot.queuedActions.last?.optimisticState ?? snapshot.serverMatch.state else {
            return false
        }

        let draft = OfflineQueuedMatchAction(
            id: UUID().uuidString,
            matchID: matchID,
            kind: kind,
            scorer: scorer,
            playerSide: playerSide,
            note: note,
            side: side,
            currentServer: currentServer,
            currentServerSide: currentServerSide,
            serviceSide: serviceSide,
            matchDurationSeconds: matchDurationSeconds,
            currentServerParticipantID: currentServerParticipantID,
            currentReceiver: currentReceiver,
            currentReceiverSide: currentReceiverSide,
            currentReceiverParticipantID: currentReceiverParticipantID,
            serveOrder: serveOrder,
            receiverDeuceOrder: receiverDeuceOrder,
            scoreType: scoreType,
            bestOf: bestOf,
            player1ShirtColor: player1ShirtColor,
            player2ShirtColor: player2ShirtColor,
            optimisticState: currentState,
            createdAt: Date()
        )
        let projected = OfflineScoringReducer.apply(draft, to: currentState, match: snapshot.serverMatch)
        let action = OfflineQueuedMatchAction(
            id: draft.id,
            matchID: draft.matchID,
            kind: draft.kind,
            scorer: draft.scorer,
            playerSide: draft.playerSide,
            note: draft.note,
            side: draft.side,
            currentServer: draft.currentServer,
            currentServerSide: draft.currentServerSide,
            serviceSide: draft.serviceSide,
            matchDurationSeconds: draft.matchDurationSeconds,
            currentServerParticipantID: draft.currentServerParticipantID,
            currentReceiver: draft.currentReceiver,
            currentReceiverSide: draft.currentReceiverSide,
            currentReceiverParticipantID: draft.currentReceiverParticipantID,
            serveOrder: draft.serveOrder,
            receiverDeuceOrder: draft.receiverDeuceOrder,
            scoreType: draft.scoreType,
            bestOf: draft.bestOf,
            player1ShirtColor: draft.player1ShirtColor,
            player2ShirtColor: draft.player2ShirtColor,
            optimisticState: projected,
            createdAt: draft.createdAt
        )
        snapshot.queuedActions.append(action)
        snapshot.cachedAt = Date()
        self.snapshot = snapshot
        syncMessage = "Offline changes waiting to sync."
        persist()
        return true
    }

    func undoLastQueuedAction(matchID: String) -> Bool {
        guard var snapshot,
              snapshot.serverMatch.id == matchID,
              !snapshot.queuedActions.isEmpty else {
            return false
        }
        snapshot.queuedActions.removeLast()
        snapshot.cachedAt = Date()
        self.snapshot = snapshot
        syncMessage = snapshot.queuedActions.isEmpty ? nil : "Offline changes waiting to sync."
        persist()
        return true
    }

    func sync(using apiClient: APIClient, session: UserSession?) async {
        guard !isSyncing,
              let session,
              !session.isExpired,
              var current = snapshot,
              current.ownerUsername.caseInsensitiveCompare(session.username) == .orderedSame,
              current.ownerOrganizationID == session.organizationID,
              !current.queuedActions.isEmpty else {
            return
        }

        isSyncing = true
        syncMessage = "Synchronising offline scoring…"
        defer { isSyncing = false }

        while let action = current.queuedActions.first {
            do {
                let updatedMatch = try await action.send(using: apiClient)
                current.serverMatch = updatedMatch
                current.queuedActions.removeFirst()
                current.cachedAt = Date()
                snapshot = current
                persist()
            } catch {
                syncMessage = "Offline changes are saved and will retry when a connection is available."
                return
            }
        }

        syncMessage = "Offline scoring synchronised."
    }

    func clear() {
        snapshot = nil
        isSyncing = false
        syncMessage = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(OfflineMatchSnapshot.self, from: data) else {
            return
        }
        snapshot = decoded
    }

    private func persist() {
        guard let snapshot, let data = try? JSONEncoder().encode(snapshot) else {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

private enum OfflineScoringReducer {
    static func apply(_ action: OfflineQueuedMatchAction, to state: MatchState, match: MatchDetail) -> MatchState {
        var next = MutableMatchState(state)
        let previousGameHistoryCount = state.gameHistory.count

        switch action.kind {
        case .scorePoint, .stroke:
            let scoringSide = action.scorer ?? action.playerSide ?? "player1"
            if (match.sport ?? "squash").lowercased() == "tennis" {
                TennisScoringReducer.applyPoint(to: &next, scoringSide: scoringSide, match: match)
            } else {
                applyRacketPoint(to: &next, scoringSide: scoringSide, match: match)
            }
        case .letCall:
            break
        case .serveSide:
            next.serviceSide = action.side ?? next.serviceSide
        case .receiverChoice:
            TennisScoringReducer.applyReceiverChoice(to: &next, side: action.side ?? "Right", match: match)
        case .server:
            next.currentServer = action.currentServer ?? next.currentServer
            next.currentServerSide = action.currentServerSide ?? next.currentServerSide
            next.serviceSide = action.serviceSide ?? next.serviceSide
            next.currentServerParticipantID = action.currentServerParticipantID ?? next.currentServerParticipantID
            next.currentReceiver = action.currentReceiver ?? next.currentReceiver
            next.currentReceiverSide = action.currentReceiverSide ?? next.currentReceiverSide
            next.currentReceiverParticipantID = action.currentReceiverParticipantID ?? next.currentReceiverParticipantID
            next.serveOrder = action.serveOrder ?? next.serveOrder
            next.receiverDeuceOrder = action.receiverDeuceOrder ?? next.receiverDeuceOrder
        case .timer:
            next.matchDurationSeconds = action.matchDurationSeconds ?? next.matchDurationSeconds
        case .undo:
            break
        case .endMatch:
            next.matchComplete = true
            next.matchDurationSeconds = action.matchDurationSeconds ?? next.matchDurationSeconds
            if next.player1GamesWon > next.player2GamesWon {
                next.winnerName = match.player1Name
            } else if next.player2GamesWon > next.player1GamesWon {
                next.winnerName = match.player2Name
            }
        case .matchSettings:
            next.scoreType = action.scoreType ?? next.scoreType
            next.bestOf = action.bestOf ?? next.bestOf
            next.player1ShirtColor = action.player1ShirtColor ?? next.player1ShirtColor
            next.player2ShirtColor = action.player2ShirtColor ?? next.player2ShirtColor
        }

        if action.kind != .undo {
            appendLocalEvent(
                action,
                to: &next,
                match: match,
                previousGameHistoryCount: previousGameHistoryCount
            )
        }

        return next.value
    }

    private static func applyRacketPoint(to state: inout MutableMatchState, scoringSide: String, match: MatchDetail) {
        let previousServer = state.currentServerSide ?? "player1"
        if scoringSide == "player1" {
            state.player1Score += 1
        } else {
            state.player2Score += 1
        }
        state.currentServerSide = scoringSide
        state.currentServer = scoringSide == "player1" ? match.player1Name : match.player2Name
        state.serviceSide = scoringSide == previousServer
            ? ((state.serviceSide ?? "Right").lowercased() == "right" ? "Left" : "Right")
            : serviceSideForReceiver(match: match, serverSide: scoringSide)

        let high = max(state.player1Score, state.player2Score)
        let low = min(state.player1Score, state.player2Score)
        let gameComplete = high >= state.scoreType && high - low >= 2
        guard gameComplete else { return }

        let winnerName = state.player1Score > state.player2Score ? match.player1Name : match.player2Name
        state.gameHistory.append(
            GameHistoryEntry(
                gameNumber: state.currentGameNumber,
                player1Score: state.player1Score,
                player2Score: state.player2Score,
                winnerName: winnerName
            )
        )
        if scoringSide == "player1" {
            state.player1GamesWon += 1
        } else {
            state.player2GamesWon += 1
        }
        let gamesToWin = (state.bestOf / 2) + 1
        if state.player1GamesWon >= gamesToWin || state.player2GamesWon >= gamesToWin {
            state.matchComplete = true
            state.winnerName = winnerName
        } else {
            state.currentGameNumber += 1
            state.player1Score = state.handicap?.enabled == true ? state.handicap?.player1Offset ?? 0 : 0
            state.player2Score = state.handicap?.enabled == true ? state.handicap?.player2Offset ?? 0 : 0
            state.currentServerSide = scoringSide
            state.currentServer = winnerName
            state.serviceSide = serviceSideForReceiver(match: match, serverSide: scoringSide)
        }
    }

    private static func serviceSideForReceiver(match: MatchDetail, serverSide: String) -> String {
        let receiverHandedness = serverSide == "player1"
            ? match.player2Handedness
            : match.player1Handedness
        return receiverHandedness?.lowercased() == "left" ? "Left" : "Right"
    }

    private static func appendLocalEvent(
        _ action: OfflineQueuedMatchAction,
        to state: inout MutableMatchState,
        match: MatchDetail,
        previousGameHistoryCount: Int
    ) {
        let gameResult = state.gameHistory.count > previousGameHistoryCount ? state.gameHistory.last : nil
        let scoringSide = action.scorer ?? action.playerSide
        let summary: String
        switch action.kind {
        case .scorePoint:
            summary = "\(scoringSide == "player2" ? match.player2Name : match.player1Name) scored (offline)"
        case .stroke:
            summary = "Stroke awarded to \(scoringSide == "player2" ? match.player2Name : match.player1Name) (offline)"
        case .letCall:
            summary = action.note ?? "Let called (offline)"
        case .serveSide:
            summary = "Serve changed to \(action.side ?? "Right") (offline)"
        case .receiverChoice:
            summary = "Receiver chose the \((action.side ?? "Right") == "Right" ? "Deuce" : "Ad") court (offline)"
        case .server:
            summary = "\(action.currentServer ?? "Player") selected to serve (offline)"
        case .timer:
            summary = "Match duration saved offline"
        case .endMatch:
            summary = "Match ended offline"
        case .matchSettings:
            summary = "Match settings changed offline"
        case .undo:
            return
        }

        state.events.append(
            MatchEvent(
                id: action.id,
                eventType: action.kind == .endMatch ? "match_ended" : action.kind.rawValue,
                payload: MatchEventPayload(
                    scorer: action.scorer,
                    playerSide: action.playerSide,
                    currentServerSide: state.currentServerSide,
                    serviceSide: state.serviceSide,
                    gameCompleted: gameResult != nil,
                    matchCompleted: state.matchComplete,
                    player1Score: state.player1Score,
                    player2Score: state.player2Score,
                    player1GamesWon: state.player1GamesWon,
                    player2GamesWon: state.player2GamesWon,
                    gameNumber: gameResult?.gameNumber ?? state.currentGameNumber,
                    currentGameNumber: state.currentGameNumber,
                    player1SetGames: state.player1SetGames,
                    player2SetGames: state.player2SetGames,
                    note: action.note,
                    side: action.side,
                    winnerName: state.winnerName,
                    winnerSide: state.matchComplete ? scoringSide : nil,
                    gameResult: gameResult,
                    scoreType: state.scoreType,
                    bestOf: state.bestOf,
                    player1ShirtColor: state.player1ShirtColor,
                    player2ShirtColor: state.player2ShirtColor,
                    currentServerParticipantID: state.currentServerParticipantID,
                    currentReceiver: state.currentReceiver,
                    currentReceiverSide: state.currentReceiverSide,
                    currentReceiverParticipantID: state.currentReceiverParticipantID,
                    serveOrder: state.serveOrder,
                    receiverDeuceOrder: state.receiverDeuceOrder,
                    isTieBreak: state.isTieBreak,
                    isMatchTiebreak: state.isMatchTiebreak,
                    tennisNoAdScoring: state.tennisNoAdScoring,
                    tennisFinalSetMatchTiebreak: state.tennisFinalSetMatchTiebreak,
                    noAdDecidingSide: state.noAdDecidingSide,
                    player1ScoreLabel: state.player1ScoreLabel,
                    player2ScoreLabel: state.player2ScoreLabel
                ),
                createdAt: ISO8601DateFormatter().string(from: action.createdAt),
                summary: summary
            )
        )
    }

}
