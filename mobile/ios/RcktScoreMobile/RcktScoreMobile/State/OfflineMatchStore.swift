import Foundation

enum OfflineMatchActionKind: String, Codable {
    case scorePoint = "score_point"
    case stroke
    case letCall = "let"
    case serveSide = "serve_side"
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
                applyTennisPoint(to: &next, scoringSide: scoringSide, match: match)
            } else {
                applyRacketPoint(to: &next, scoringSide: scoringSide, match: match)
            }
        case .letCall:
            break
        case .serveSide:
            next.serviceSide = action.side ?? next.serviceSide
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

    private static func applyTennisPoint(to state: inout MutableMatchState, scoringSide: String, match: MatchDetail) {
        let currentServerSide = state.currentServerSide ?? "player1"
        let currentServerParticipantID = state.currentServerParticipantID
            ?? currentGameServerParticipantID(state)
        let serveOrder = combinedServeOrder(state)

        if scoringSide == "player1" { state.player1Score += 1 } else { state.player2Score += 1 }

        state.serviceSide = serviceSideForNextTennisPoint(
            player1Score: state.player1Score,
            player2Score: state.player2Score
        )

        if state.isTieBreak {
            let firstServerSide = state.tieBreakFirstServerSide ?? currentServerSide
            let firstServerParticipantID = state.tieBreakFirstServerParticipantID ?? currentServerParticipantID
            let high = max(state.player1Score, state.player2Score)
            let low = min(state.player1Score, state.player2Score)
            if high >= 7 && high - low >= 2 {
                completeTennisSet(
                    state: &state,
                    scoringSide: scoringSide,
                    match: match,
                    completedSetPlayer1Games: state.player1SetGames + (scoringSide == "player1" ? 1 : 0),
                    completedSetPlayer2Games: state.player2SetGames + (scoringSide == "player2" ? 1 : 0),
                    nextServerParticipantID: nextParticipant(after: firstServerParticipantID, in: serveOrder),
                    nextServerSide: opponent(firstServerSide)
                )
            } else {
                let nextParticipantID = nextTieBreakServerParticipant(
                    serveOrder: serveOrder,
                    totalPointsPlayed: state.player1Score + state.player2Score
                ) ?? firstServerParticipantID
                applyTennisServer(
                    to: &state,
                    participantID: nextParticipantID,
                    fallbackSide: nextTieBreakServerSide(
                        firstServerSide: firstServerSide,
                        player1Score: state.player1Score,
                        player2Score: state.player2Score
                    ),
                    match: match
                )
            }
            updateTennisReceiver(to: &state, match: match)
            updateTennisLabels(state: &state)
            return
        }

        let high = max(state.player1Score, state.player2Score)
        let low = min(state.player1Score, state.player2Score)
        guard high >= 4 && high - low >= 2 else {
            applyTennisServer(
                to: &state,
                participantID: currentServerParticipantID,
                fallbackSide: currentServerSide,
                match: match
            )
            updateTennisReceiver(to: &state, match: match)
            updateTennisLabels(state: &state)
            return
        }

        if scoringSide == "player1" { state.player1SetGames += 1 } else { state.player2SetGames += 1 }

        let target = state.scoreType
        let setHigh = max(state.player1SetGames, state.player2SetGames)
        let setLow = min(state.player1SetGames, state.player2SetGames)
        if setHigh >= target && setHigh - setLow >= 2 {
            let completedGames = state.player1SetGames + state.player2SetGames
            completeTennisSet(
                state: &state,
                scoringSide: scoringSide,
                match: match,
                completedSetPlayer1Games: state.player1SetGames,
                completedSetPlayer2Games: state.player2SetGames,
                nextServerParticipantID: participant(at: completedGames, in: serveOrder),
                nextServerSide: opponent(currentServerSide)
            )
        } else if state.player1SetGames == tieBreakTrigger(state.scoreType)
                    && state.player2SetGames == tieBreakTrigger(state.scoreType) {
            state.player1Score = 0
            state.player2Score = 0
            state.isTieBreak = true
            let totalGamesPlayed = state.player1SetGames + state.player2SetGames
            let tieBreakServerParticipantID = participant(at: totalGamesPlayed, in: serveOrder)
            let tieBreakServerSide = participantSide(tieBreakServerParticipantID, state: state)
                ?? opponent(currentServerSide)
            state.tieBreakFirstServerParticipantID = tieBreakServerParticipantID
            state.tieBreakFirstServerSide = tieBreakServerSide
            state.serviceSide = "Right"
            applyTennisServer(
                to: &state,
                participantID: tieBreakServerParticipantID,
                fallbackSide: tieBreakServerSide,
                match: match
            )
        } else {
            state.player1Score = 0
            state.player2Score = 0
            state.serviceSide = "Right"
            let totalGamesPlayed = state.player1SetGames + state.player2SetGames
            applyTennisServer(
                to: &state,
                participantID: participant(at: totalGamesPlayed, in: serveOrder),
                fallbackSide: opponent(currentServerSide),
                match: match
            )
        }
        updateTennisReceiver(to: &state, match: match)
        updateTennisLabels(state: &state)
    }

    private static func completeTennisSet(
        state: inout MutableMatchState,
        scoringSide: String,
        match: MatchDetail,
        completedSetPlayer1Games: Int,
        completedSetPlayer2Games: Int,
        nextServerParticipantID: String?,
        nextServerSide: String
    ) {
        let winnerName = scoringSide == "player1" ? match.player1Name : match.player2Name
        state.player1SetGames = completedSetPlayer1Games
        state.player2SetGames = completedSetPlayer2Games
        state.gameHistory.append(
            GameHistoryEntry(
                gameNumber: state.currentGameNumber,
                player1Score: completedSetPlayer1Games,
                player2Score: completedSetPlayer2Games,
                winnerName: winnerName
            )
        )
        if scoringSide == "player1" { state.player1GamesWon += 1 } else { state.player2GamesWon += 1 }
        if max(state.player1GamesWon, state.player2GamesWon) >= (state.bestOf / 2) + 1 {
            state.matchComplete = true
            state.winnerName = winnerName
        } else {
            state.currentGameNumber += 1
            state.player1SetGames = 0
            state.player2SetGames = 0
            state.player1Score = 0
            state.player2Score = 0
            state.isTieBreak = false
            state.tieBreakFirstServerSide = nil
            state.tieBreakFirstServerParticipantID = nil
            state.serviceSide = "Right"
            applyTennisServer(
                to: &state,
                participantID: nextServerParticipantID,
                fallbackSide: nextServerSide,
                match: match
            )
        }
        updateTennisLabels(state: &state)
    }

    private static func serviceSideForReceiver(match: MatchDetail, serverSide: String) -> String {
        let receiverHandedness = serverSide == "player1"
            ? match.player2Handedness
            : match.player1Handedness
        return receiverHandedness?.lowercased() == "left" ? "Left" : "Right"
    }

    private static func opponent(_ side: String) -> String {
        side == "player1" ? "player2" : "player1"
    }

    private static func tieBreakTrigger(_ scoreType: Int) -> Int {
        scoreType == 4 ? 3 : 6
    }

    private static func serviceSideForNextTennisPoint(player1Score: Int, player2Score: Int) -> String {
        (player1Score + player2Score).isMultiple(of: 2) ? "Right" : "Left"
    }

    private static func combinedServeOrder(_ state: MutableMatchState) -> [String] {
        if let serveOrder = state.serveOrder, !serveOrder.isEmpty {
            return serveOrder
        }

        let teamOne = state.teamServiceOrder?["player1"]
            ?? state.tennisTeams?["player1"]?.map(\.id)
            ?? []
        let teamTwo = state.teamServiceOrder?["player2"]
            ?? state.tennisTeams?["player2"]?.map(\.id)
            ?? []
        var combined: [String] = []
        for index in 0..<max(teamOne.count, teamTwo.count) {
            if index < teamOne.count { combined.append(teamOne[index]) }
            if index < teamTwo.count { combined.append(teamTwo[index]) }
        }
        return combined
    }

    private static func currentGameServerParticipantID(_ state: MutableMatchState) -> String? {
        let order = combinedServeOrder(state)
        guard !order.isEmpty else { return nil }
        return order[(state.player1SetGames + state.player2SetGames) % order.count]
    }

    private static func participant(at index: Int, in order: [String]) -> String? {
        guard !order.isEmpty else { return nil }
        return order[index % order.count]
    }

    private static func nextParticipant(after participantID: String?, in order: [String]) -> String? {
        guard !order.isEmpty else { return nil }
        guard let participantID, let index = order.firstIndex(of: participantID) else {
            return order.first
        }
        return order[(index + 1) % order.count]
    }

    private static func nextTieBreakServerParticipant(serveOrder: [String], totalPointsPlayed: Int) -> String? {
        guard !serveOrder.isEmpty else { return nil }
        if totalPointsPlayed <= 0 { return serveOrder[0] }
        if serveOrder.count == 1 { return serveOrder[0] }
        let blockIndex = (totalPointsPlayed - 1) / 2
        return serveOrder[(1 + blockIndex) % serveOrder.count]
    }

    private static func nextTieBreakServerSide(firstServerSide: String, player1Score: Int, player2Score: Int) -> String {
        let totalPointsPlayed = player1Score + player2Score
        if totalPointsPlayed <= 0 { return firstServerSide }
        if totalPointsPlayed == 1 { return opponent(firstServerSide) }
        let blockIndex = (totalPointsPlayed - 1) / 2
        return blockIndex.isMultiple(of: 2) ? opponent(firstServerSide) : firstServerSide
    }

    private static func participantSide(_ participantID: String?, state: MutableMatchState) -> String? {
        guard let participantID else { return nil }
        for (side, participants) in state.tennisTeams ?? [:] where participants.contains(where: { $0.id == participantID }) {
            return side
        }
        return nil
    }

    private static func participantName(_ participantID: String?, state: MutableMatchState) -> String? {
        guard let participantID else { return nil }
        return (state.tennisTeams ?? [:])
            .values
            .flatMap { $0 }
            .first(where: { $0.id == participantID })?
            .displayName
    }

    private static func receiverParticipantID(for side: String, serviceSide: String, state: MutableMatchState) -> String? {
        let participants = state.tennisTeams?[side] ?? []
        guard !participants.isEmpty else { return nil }
        let deuceReceiverID = state.receiverDeuceOrder?[side] ?? participants[0].id
        guard participants.count > 1, serviceSide.lowercased() != "right" else {
            return deuceReceiverID
        }
        return participants.first(where: { $0.id != deuceReceiverID })?.id ?? deuceReceiverID
    }

    private static func applyTennisServer(
        to state: inout MutableMatchState,
        participantID: String?,
        fallbackSide: String,
        match: MatchDetail
    ) {
        let serverSide = participantSide(participantID, state: state) ?? fallbackSide
        state.currentServerParticipantID = participantID
        state.currentServerSide = serverSide
        state.currentServer = participantName(participantID, state: state)
            ?? (serverSide == "player1" ? match.player1Name : match.player2Name)
    }

    private static func updateTennisReceiver(to state: inout MutableMatchState, match: MatchDetail) {
        let receiverSide = opponent(state.currentServerSide ?? "player1")
        let receiverID = receiverParticipantID(
            for: receiverSide,
            serviceSide: state.serviceSide ?? "Right",
            state: state
        )
        state.currentReceiverSide = receiverSide
        state.currentReceiverParticipantID = receiverID
        state.currentReceiver = participantName(receiverID, state: state)
            ?? (receiverSide == "player1" ? match.player1Name : match.player2Name)
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
                    player1ScoreLabel: state.player1ScoreLabel,
                    player2ScoreLabel: state.player2ScoreLabel
                ),
                createdAt: ISO8601DateFormatter().string(from: action.createdAt),
                summary: summary
            )
        )
    }

    private static func updateTennisLabels(state: inout MutableMatchState) {
        if state.isTieBreak {
            state.player1ScoreLabel = String(state.player1Score)
            state.player2ScoreLabel = String(state.player2Score)
        } else if state.player1Score >= 3 && state.player2Score >= 3 {
            if state.player1Score == state.player2Score {
                state.player1ScoreLabel = "40"
                state.player2ScoreLabel = "40"
            } else if state.player1Score > state.player2Score {
                state.player1ScoreLabel = "Ad"
                state.player2ScoreLabel = "40"
            } else {
                state.player1ScoreLabel = "40"
                state.player2ScoreLabel = "Ad"
            }
        } else {
            let labels = ["0", "15", "30", "40"]
            state.player1ScoreLabel = labels[min(state.player1Score, 3)]
            state.player2ScoreLabel = labels[min(state.player2Score, 3)]
        }
        state.scoreDisplayMode = "tennis"
    }
}

private struct MutableMatchState {
    var player1Score: Int
    var player2Score: Int
    var player1GamesWon: Int
    var player2GamesWon: Int
    var player1SetGames: Int
    var player2SetGames: Int
    var currentGameNumber: Int
    var bestOf: Int
    var scoreType: Int
    var currentServer: String?
    var currentServerSide: String?
    var serviceSide: String?
    var player1ShirtColor: String?
    var player2ShirtColor: String?
    var scoreDisplayMode: String?
    var player1ScoreLabel: String?
    var player2ScoreLabel: String?
    var isTieBreak: Bool
    var teamFormat: String?
    var tennisTeams: [String: [TennisParticipant]]?
    var currentServerParticipantID: String?
    var currentReceiver: String?
    var currentReceiverSide: String?
    var currentReceiverParticipantID: String?
    var teamServiceOrder: [String: [String]]?
    var serveOrder: [String]?
    var receiverDeuceOrder: [String: String]?
    var tieBreakFirstServerSide: String?
    var tieBreakFirstServerParticipantID: String?
    var handicap: MatchHandicap?
    var matchDurationSeconds: Int
    var gameHistory: [GameHistoryEntry]
    var matchComplete: Bool
    var winnerName: String?
    var events: [MatchEvent]

    init(_ state: MatchState) {
        player1Score = state.player1Score
        player2Score = state.player2Score
        player1GamesWon = state.player1GamesWon
        player2GamesWon = state.player2GamesWon
        player1SetGames = state.player1SetGames
        player2SetGames = state.player2SetGames
        currentGameNumber = state.currentGameNumber
        bestOf = state.bestOf
        scoreType = state.scoreType
        currentServer = state.currentServer
        currentServerSide = state.currentServerSide
        serviceSide = state.serviceSide
        player1ShirtColor = state.player1ShirtColor
        player2ShirtColor = state.player2ShirtColor
        scoreDisplayMode = state.scoreDisplayMode
        player1ScoreLabel = state.player1ScoreLabel
        player2ScoreLabel = state.player2ScoreLabel
        isTieBreak = state.isTieBreak
        teamFormat = state.teamFormat
        tennisTeams = state.tennisTeams
        currentServerParticipantID = state.currentServerParticipantID
        currentReceiver = state.currentReceiver
        currentReceiverSide = state.currentReceiverSide
        currentReceiverParticipantID = state.currentReceiverParticipantID
        teamServiceOrder = state.teamServiceOrder
        serveOrder = state.serveOrder
        receiverDeuceOrder = state.receiverDeuceOrder
        tieBreakFirstServerSide = state.tieBreakFirstServerSide
        tieBreakFirstServerParticipantID = state.tieBreakFirstServerParticipantID
        handicap = state.handicap
        matchDurationSeconds = state.matchDurationSeconds
        gameHistory = state.gameHistory
        matchComplete = state.matchComplete
        winnerName = state.winnerName
        events = state.events
    }

    var value: MatchState {
        MatchState(
            player1Score: player1Score,
            player2Score: player2Score,
            player1GamesWon: player1GamesWon,
            player2GamesWon: player2GamesWon,
            player1SetGames: player1SetGames,
            player2SetGames: player2SetGames,
            currentGameNumber: currentGameNumber,
            bestOf: bestOf,
            scoreType: scoreType,
            currentServer: currentServer,
            currentServerSide: currentServerSide,
            serviceSide: serviceSide,
            player1ShirtColor: player1ShirtColor,
            player2ShirtColor: player2ShirtColor,
            scoreDisplayMode: scoreDisplayMode,
            player1ScoreLabel: player1ScoreLabel,
            player2ScoreLabel: player2ScoreLabel,
            isTieBreak: isTieBreak,
            teamFormat: teamFormat,
            tennisTeams: tennisTeams,
            currentServerParticipantID: currentServerParticipantID,
            currentReceiver: currentReceiver,
            currentReceiverSide: currentReceiverSide,
            currentReceiverParticipantID: currentReceiverParticipantID,
            teamServiceOrder: teamServiceOrder,
            serveOrder: serveOrder,
            receiverDeuceOrder: receiverDeuceOrder,
            tieBreakFirstServerSide: tieBreakFirstServerSide,
            tieBreakFirstServerParticipantID: tieBreakFirstServerParticipantID,
            handicap: handicap,
            matchDurationSeconds: matchDurationSeconds,
            gameHistory: gameHistory,
            matchComplete: matchComplete,
            winnerName: winnerName,
            events: events
        )
    }
}
