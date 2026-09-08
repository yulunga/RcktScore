import Foundation

struct MutableMatchState {
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
    var isMatchTiebreak: Bool
    var tennisNoAdScoring: Bool
    var tennisFinalSetMatchTiebreak: Bool
    var noAdDecidingSide: String?
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
        isMatchTiebreak = state.isMatchTiebreak
        tennisNoAdScoring = state.tennisNoAdScoring
        tennisFinalSetMatchTiebreak = state.tennisFinalSetMatchTiebreak
        noAdDecidingSide = state.noAdDecidingSide
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
            events: events,
            isMatchTiebreak: isMatchTiebreak,
            tennisNoAdScoring: tennisNoAdScoring,
            tennisFinalSetMatchTiebreak: tennisFinalSetMatchTiebreak,
            noAdDecidingSide: noAdDecidingSide
        )
    }
}

/// The device-side tennis rules engine used while actions are waiting to sync.
/// The backend remains authoritative; this reducer deliberately mirrors its
/// transitions so an offline scoreboard does not change when it reconnects.
enum TennisScoringReducer {
    static func applyPoint(to state: inout MutableMatchState, scoringSide: String, match: MatchDetail) {
        guard !state.matchComplete else { return }
        if state.tennisNoAdScoring,
           !state.isTieBreak,
           state.player1Score == 3,
           state.player2Score == 3,
           state.noAdDecidingSide == nil {
            return
        }

        let currentServerSide = state.currentServerSide ?? "player1"
        let currentServerID = state.currentServerParticipantID ?? currentGameServerID(state)
        var order = combinedServeOrder(state)

        if scoringSide == "player1" { state.player1Score += 1 } else { state.player2Score += 1 }
        state.serviceSide = serviceSide(player1: state.player1Score, player2: state.player2Score)

        if state.isTieBreak {
            let firstServerSide = state.tieBreakFirstServerSide ?? currentServerSide
            let firstServerID = state.tieBreakFirstServerParticipantID ?? currentServerID
            let target = state.isMatchTiebreak ? 10 : 7
            if isComplete(state.player1Score, state.player2Score, target: target, margin: 2) {
                let player1Games = state.isMatchTiebreak
                    ? (scoringSide == "player1" ? 1 : 0)
                    : state.player1SetGames + (scoringSide == "player1" ? 1 : 0)
                let player2Games = state.isMatchTiebreak
                    ? (scoringSide == "player2" ? 1 : 0)
                    : state.player2SetGames + (scoringSide == "player2" ? 1 : 0)
                completeSet(
                    state: &state,
                    scoringSide: scoringSide,
                    match: match,
                    player1Games: player1Games,
                    player2Games: player2Games,
                    nextServerID: nextParticipant(after: firstServerID, in: order),
                    nextServerSide: opponent(firstServerSide),
                    serveOrder: &order
                )
            } else {
                let nextID = tieBreakServer(in: order, pointsPlayed: state.player1Score + state.player2Score) ?? firstServerID
                setServer(
                    state: &state,
                    participantID: nextID,
                    fallbackSide: participantSide(nextID, state: state) ?? opponent(firstServerSide),
                    match: match
                )
                updateReceiver(state: &state, match: match)
            }
            updateLabels(state: &state)
            return
        }

        let requiredMargin = state.tennisNoAdScoring ? 1 : 2
        guard isComplete(state.player1Score, state.player2Score, target: 4, margin: requiredMargin) else {
            setServer(state: &state, participantID: currentServerID, fallbackSide: currentServerSide, match: match)
            if state.tennisNoAdScoring && state.player1Score == 3 && state.player2Score == 3 {
                state.noAdDecidingSide = nil
            }
            updateReceiver(state: &state, match: match)
            updateLabels(state: &state)
            return
        }

        state.noAdDecidingSide = nil
        if scoringSide == "player1" { state.player1SetGames += 1 } else { state.player2SetGames += 1 }
        if isComplete(state.player1SetGames, state.player2SetGames, target: state.scoreType, margin: 2) {
            let completedGames = state.player1SetGames + state.player2SetGames
            completeSet(
                state: &state,
                scoringSide: scoringSide,
                match: match,
                player1Games: state.player1SetGames,
                player2Games: state.player2SetGames,
                nextServerID: participant(at: completedGames, in: order),
                nextServerSide: opponent(currentServerSide),
                serveOrder: &order
            )
        } else if state.player1SetGames == tieBreakTrigger(state.scoreType)
                    && state.player2SetGames == tieBreakTrigger(state.scoreType) {
            state.player1Score = 0
            state.player2Score = 0
            state.isTieBreak = true
            state.isMatchTiebreak = false
            let firstID = participant(at: state.player1SetGames + state.player2SetGames, in: order)
            let firstSide = participantSide(firstID, state: state) ?? opponent(currentServerSide)
            state.tieBreakFirstServerParticipantID = firstID
            state.tieBreakFirstServerSide = firstSide
            state.serviceSide = "Right"
            rotate(&order, to: firstID)
            state.serveOrder = order
            setServer(state: &state, participantID: firstID, fallbackSide: firstSide, match: match)
            updateReceiver(state: &state, match: match)
        } else {
            state.player1Score = 0
            state.player2Score = 0
            state.serviceSide = "Right"
            let nextID = participant(at: state.player1SetGames + state.player2SetGames, in: order)
            setServer(state: &state, participantID: nextID, fallbackSide: opponent(currentServerSide), match: match)
            updateReceiver(state: &state, match: match)
        }
        updateLabels(state: &state)
    }

    static func applyReceiverChoice(to state: inout MutableMatchState, side: String, match: MatchDetail) {
        guard state.tennisNoAdScoring,
              !state.isTieBreak,
              state.player1Score == 3,
              state.player2Score == 3,
              side == "Right" || side == "Left" else { return }
        state.noAdDecidingSide = side
        state.serviceSide = side
        updateReceiver(state: &state, match: match)
    }

    private static func completeSet(
        state: inout MutableMatchState,
        scoringSide: String,
        match: MatchDetail,
        player1Games: Int,
        player2Games: Int,
        nextServerID: String?,
        nextServerSide: String,
        serveOrder: inout [String]
    ) {
        let winner = scoringSide == "player1" ? match.player1Name : match.player2Name
        state.player1SetGames = player1Games
        state.player2SetGames = player2Games
        state.gameHistory.append(
            GameHistoryEntry(
                gameNumber: state.currentGameNumber,
                player1Score: player1Games,
                player2Score: player2Games,
                winnerName: winner
            )
        )
        if scoringSide == "player1" { state.player1GamesWon += 1 } else { state.player2GamesWon += 1 }
        if max(state.player1GamesWon, state.player2GamesWon) >= (state.bestOf / 2) + 1 {
            state.matchComplete = true
            state.winnerName = winner
            return
        }

        state.currentGameNumber += 1
        state.player1SetGames = 0
        state.player2SetGames = 0
        state.player1Score = 0
        state.player2Score = 0
        state.noAdDecidingSide = nil
        state.isTieBreak = false
        state.isMatchTiebreak = false
        state.tieBreakFirstServerSide = nil
        state.tieBreakFirstServerParticipantID = nil
        state.serviceSide = "Right"
        rotate(&serveOrder, to: nextServerID)
        state.serveOrder = serveOrder
        setServer(state: &state, participantID: nextServerID, fallbackSide: nextServerSide, match: match)

        let setsToWin = (state.bestOf / 2) + 1
        if state.tennisFinalSetMatchTiebreak,
           state.bestOf > 1,
           state.player1GamesWon == setsToWin - 1,
           state.player2GamesWon == setsToWin - 1 {
            state.isTieBreak = true
            state.isMatchTiebreak = true
            state.tieBreakFirstServerSide = state.currentServerSide
            state.tieBreakFirstServerParticipantID = state.currentServerParticipantID
        }
        updateReceiver(state: &state, match: match)
    }

    private static func isComplete(_ player1: Int, _ player2: Int, target: Int, margin: Int) -> Bool {
        max(player1, player2) >= target && abs(player1 - player2) >= margin
    }

    private static func opponent(_ side: String) -> String { side == "player1" ? "player2" : "player1" }
    private static func tieBreakTrigger(_ scoreType: Int) -> Int { scoreType == 4 ? 3 : 6 }
    private static func serviceSide(player1: Int, player2: Int) -> String {
        (player1 + player2).isMultiple(of: 2) ? "Right" : "Left"
    }

    private static func combinedServeOrder(_ state: MutableMatchState) -> [String] {
        if let order = state.serveOrder, !order.isEmpty { return order }
        let team1 = state.teamServiceOrder?["player1"] ?? state.tennisTeams?["player1"]?.map(\.id) ?? []
        let team2 = state.teamServiceOrder?["player2"] ?? state.tennisTeams?["player2"]?.map(\.id) ?? []
        var result: [String] = []
        for index in 0..<max(team1.count, team2.count) {
            if index < team1.count { result.append(team1[index]) }
            if index < team2.count { result.append(team2[index]) }
        }
        return result
    }

    private static func rotate(_ order: inout [String], to participantID: String?) {
        guard let participantID, let index = order.firstIndex(of: participantID) else { return }
        order = Array(order[index...]) + Array(order[..<index])
    }

    private static func currentGameServerID(_ state: MutableMatchState) -> String? {
        let order = combinedServeOrder(state)
        return participant(at: state.player1SetGames + state.player2SetGames, in: order)
    }

    private static func participant(at index: Int, in order: [String]) -> String? {
        order.isEmpty ? nil : order[index % order.count]
    }

    private static func nextParticipant(after participantID: String?, in order: [String]) -> String? {
        guard !order.isEmpty else { return nil }
        guard let participantID, let index = order.firstIndex(of: participantID) else { return order.first }
        return order[(index + 1) % order.count]
    }

    private static func tieBreakServer(in order: [String], pointsPlayed: Int) -> String? {
        guard !order.isEmpty else { return nil }
        if pointsPlayed <= 0 { return order[0] }
        if order.count == 1 { return order[0] }
        return order[(1 + (pointsPlayed - 1) / 2) % order.count]
    }

    private static func participantSide(_ id: String?, state: MutableMatchState) -> String? {
        guard let id else { return nil }
        return (state.tennisTeams ?? [:]).first(where: { $0.value.contains(where: { $0.id == id }) })?.key
    }

    private static func participantName(_ id: String?, state: MutableMatchState) -> String? {
        guard let id else { return nil }
        return (state.tennisTeams ?? [:]).values.flatMap { $0 }.first(where: { $0.id == id })?.displayName
    }

    private static func receiverID(for side: String, serviceSide: String, state: MutableMatchState) -> String? {
        let participants = state.tennisTeams?[side] ?? []
        guard let first = participants.first else { return nil }
        let deuceID = state.receiverDeuceOrder?[side] ?? first.id
        if participants.count == 1 || serviceSide.lowercased() == "right" { return deuceID }
        return participants.first(where: { $0.id != deuceID })?.id ?? deuceID
    }

    private static func setServer(
        state: inout MutableMatchState,
        participantID: String?,
        fallbackSide: String,
        match: MatchDetail
    ) {
        let side = participantSide(participantID, state: state) ?? fallbackSide
        state.currentServerParticipantID = participantID
        state.currentServerSide = side
        state.currentServer = participantName(participantID, state: state)
            ?? (side == "player1" ? match.player1Name : match.player2Name)
    }

    private static func updateReceiver(state: inout MutableMatchState, match: MatchDetail) {
        let side = opponent(state.currentServerSide ?? "player1")
        let id = receiverID(for: side, serviceSide: state.serviceSide ?? "Right", state: state)
        state.currentReceiverSide = side
        state.currentReceiverParticipantID = id
        state.currentReceiver = participantName(id, state: state)
            ?? (side == "player1" ? match.player1Name : match.player2Name)
    }

    private static func updateLabels(state: inout MutableMatchState) {
        if state.isTieBreak {
            state.player1ScoreLabel = String(state.player1Score)
            state.player2ScoreLabel = String(state.player2Score)
        } else if state.player1Score >= 3 && state.player2Score >= 3 {
            if state.player1Score == state.player2Score {
                state.player1ScoreLabel = "40"
                state.player2ScoreLabel = "40"
            } else if state.tennisNoAdScoring {
                state.player1ScoreLabel = state.player1Score > state.player2Score ? "Game" : "40"
                state.player2ScoreLabel = state.player2Score > state.player1Score ? "Game" : "40"
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
