import Foundation

struct MatchSummary: Decodable, Identifiable {
    let id: String
    let player1Name: String
    let player1Surname: String?
    let player2Name: String
    let player2Surname: String?
    let courtName: String?
    let status: String
    let bestOf: Int?
    let scoreType: Int?
    let updatedAt: String?
    let completedAt: String?
    let matchDurationSeconds: Int?
    let winnerName: String?
    let state: MatchState?

    enum CodingKeys: String, CodingKey {
        case id
        case legacyMatchID = "match_id"
        case player1Name = "player1_name"
        case player1Surname = "player1_surname"
        case player2Name = "player2_name"
        case player2Surname = "player2_surname"
        case courtName = "court_name"
        case status
        case bestOf = "best_of"
        case scoreType = "score_type"
        case updatedAt = "updated_at"
        case completedAt = "completed_at"
        case matchDurationSeconds = "match_duration_seconds"
        case winnerName = "winner_name"
        case state
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decode(String.self, forKey: .legacyMatchID)
        player1Name = try container.decode(String.self, forKey: .player1Name)
        player1Surname = try container.decodeIfPresent(String.self, forKey: .player1Surname)
        player2Name = try container.decode(String.self, forKey: .player2Name)
        player2Surname = try container.decodeIfPresent(String.self, forKey: .player2Surname)
        courtName = try container.decodeIfPresent(String.self, forKey: .courtName)
        status = try container.decode(String.self, forKey: .status)
        bestOf = try container.decodeIfPresent(Int.self, forKey: .bestOf)
        scoreType = try container.decodeIfPresent(Int.self, forKey: .scoreType)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        completedAt = try container.decodeIfPresent(String.self, forKey: .completedAt)
        matchDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .matchDurationSeconds)
        winnerName = try container.decodeIfPresent(String.self, forKey: .winnerName)
        state = try container.decodeIfPresent(MatchState.self, forKey: .state)
    }
}

struct MatchDetail: Codable, Identifiable {
    let id: String
    let courtName: String?
    let courtAlias: String?
    let courtDisplayCode: String?
    let sport: String?
    let player1Name: String
    let player1Surname: String?
    let player1Handedness: String?
    let player1ShirtColor: String?
    let player2Name: String
    let player2Surname: String?
    let player2Handedness: String?
    let player2ShirtColor: String?
    let refereeName: String?
    let scoreType: Int
    let bestOf: Int
    let handicapEnabled: Bool
    let player1Offset: Int
    let player2Offset: Int
    let player1Band: String?
    let player2Band: String?
    let status: String
    let autoScheduled: Bool?
    let autoScheduleReason: String?
    let createdAt: String
    let updatedAt: String
    let completedAt: String?
    let matchDurationSeconds: Int?
    let state: MatchState?

    enum CodingKeys: String, CodingKey {
        case id
        case courtName = "court_name"
        case courtAlias = "court_alias"
        case courtDisplayCode = "court_display_code"
        case sport
        case player1Name = "player1_name"
        case player1Surname = "player1_surname"
        case player1Handedness = "player1_handedness"
        case player1ShirtColor = "player1_shirt_color"
        case player2Name = "player2_name"
        case player2Surname = "player2_surname"
        case player2Handedness = "player2_handedness"
        case player2ShirtColor = "player2_shirt_color"
        case refereeName = "referee_name"
        case scoreType = "score_type"
        case bestOf = "best_of"
        case handicapEnabled = "handicap_enabled"
        case player1Offset = "player1_offset"
        case player2Offset = "player2_offset"
        case player1Band = "player1_band"
        case player2Band = "player2_band"
        case status
        case autoScheduled = "auto_scheduled"
        case autoScheduleReason = "auto_schedule_reason"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case completedAt = "completed_at"
        case matchDurationSeconds = "match_duration_seconds"
        case state
    }
}

struct MatchState: Codable {
    let player1Score: Int
    let player2Score: Int
    let player1GamesWon: Int
    let player2GamesWon: Int
    let player1SetGames: Int
    let player2SetGames: Int
    let currentGameNumber: Int
    let bestOf: Int
    let scoreType: Int
    let currentServer: String?
    let currentServerSide: String?
    let serviceSide: String?
    let player1ShirtColor: String?
    let player2ShirtColor: String?
    let scoreDisplayMode: String?
    let player1ScoreLabel: String?
    let player2ScoreLabel: String?
    let isTieBreak: Bool
    let teamFormat: String?
    let tennisTeams: [String: [TennisParticipant]]?
    let currentServerParticipantID: String?
    let currentReceiver: String?
    let currentReceiverSide: String?
    let currentReceiverParticipantID: String?
    let teamServiceOrder: [String: [String]]?
    let serveOrder: [String]?
    let receiverDeuceOrder: [String: String]?
    let tieBreakFirstServerSide: String?
    let tieBreakFirstServerParticipantID: String?
    let handicap: MatchHandicap?
    let matchDurationSeconds: Int
    let gameHistory: [GameHistoryEntry]
    let matchComplete: Bool
    let winnerName: String?
    let events: [MatchEvent]

    enum CodingKeys: String, CodingKey {
        case player1Score = "player1_score"
        case player2Score = "player2_score"
        case player1GamesWon = "player1_games_won"
        case player2GamesWon = "player2_games_won"
        case player1SetGames = "player1_set_games"
        case player2SetGames = "player2_set_games"
        case currentGameNumber = "current_game_number"
        case bestOf = "best_of"
        case scoreType = "score_type"
        case currentServer = "current_server"
        case currentServerSide = "current_server_side"
        case serviceSide = "service_side"
        case player1ShirtColor = "player1_shirt_color"
        case player2ShirtColor = "player2_shirt_color"
        case scoreDisplayMode = "score_display_mode"
        case player1ScoreLabel = "player1_score_label"
        case player2ScoreLabel = "player2_score_label"
        case isTieBreak = "is_tie_break"
        case teamFormat = "team_format"
        case tennisTeams = "tennis_teams"
        case currentServerParticipantID = "current_server_participant_id"
        case currentReceiver = "current_receiver"
        case currentReceiverSide = "current_receiver_side"
        case currentReceiverParticipantID = "current_receiver_participant_id"
        case teamServiceOrder = "team_service_order"
        case serveOrder = "serve_order"
        case receiverDeuceOrder = "receiver_deuce_order"
        case tieBreakFirstServerSide = "tiebreak_first_server_side"
        case tieBreakFirstServerParticipantID = "tiebreak_first_server_participant_id"
        case handicap
        case matchDurationSeconds = "match_duration_seconds"
        case gameHistory = "game_history"
        case matchComplete = "match_complete"
        case winnerName = "winner_name"
        case events
    }

    init(
        player1Score: Int,
        player2Score: Int,
        player1GamesWon: Int,
        player2GamesWon: Int,
        player1SetGames: Int,
        player2SetGames: Int,
        currentGameNumber: Int,
        bestOf: Int,
        scoreType: Int,
        currentServer: String?,
        currentServerSide: String?,
        serviceSide: String?,
        player1ShirtColor: String?,
        player2ShirtColor: String?,
        scoreDisplayMode: String?,
        player1ScoreLabel: String?,
        player2ScoreLabel: String?,
        isTieBreak: Bool,
        teamFormat: String?,
        tennisTeams: [String: [TennisParticipant]]?,
        currentServerParticipantID: String?,
        currentReceiver: String?,
        currentReceiverSide: String?,
        currentReceiverParticipantID: String?,
        teamServiceOrder: [String: [String]]?,
        serveOrder: [String]?,
        receiverDeuceOrder: [String: String]?,
        tieBreakFirstServerSide: String?,
        tieBreakFirstServerParticipantID: String?,
        handicap: MatchHandicap?,
        matchDurationSeconds: Int,
        gameHistory: [GameHistoryEntry],
        matchComplete: Bool,
        winnerName: String?,
        events: [MatchEvent]
    ) {
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.player1GamesWon = player1GamesWon
        self.player2GamesWon = player2GamesWon
        self.player1SetGames = player1SetGames
        self.player2SetGames = player2SetGames
        self.currentGameNumber = currentGameNumber
        self.bestOf = bestOf
        self.scoreType = scoreType
        self.currentServer = currentServer
        self.currentServerSide = currentServerSide
        self.serviceSide = serviceSide
        self.player1ShirtColor = player1ShirtColor
        self.player2ShirtColor = player2ShirtColor
        self.scoreDisplayMode = scoreDisplayMode
        self.player1ScoreLabel = player1ScoreLabel
        self.player2ScoreLabel = player2ScoreLabel
        self.isTieBreak = isTieBreak
        self.teamFormat = teamFormat
        self.tennisTeams = tennisTeams
        self.currentServerParticipantID = currentServerParticipantID
        self.currentReceiver = currentReceiver
        self.currentReceiverSide = currentReceiverSide
        self.currentReceiverParticipantID = currentReceiverParticipantID
        self.teamServiceOrder = teamServiceOrder
        self.serveOrder = serveOrder
        self.receiverDeuceOrder = receiverDeuceOrder
        self.tieBreakFirstServerSide = tieBreakFirstServerSide
        self.tieBreakFirstServerParticipantID = tieBreakFirstServerParticipantID
        self.handicap = handicap
        self.matchDurationSeconds = matchDurationSeconds
        self.gameHistory = gameHistory
        self.matchComplete = matchComplete
        self.winnerName = winnerName
        self.events = events
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        player1Score = try container.decodeIfPresent(Int.self, forKey: .player1Score) ?? 0
        player2Score = try container.decodeIfPresent(Int.self, forKey: .player2Score) ?? 0
        player1GamesWon = try container.decodeIfPresent(Int.self, forKey: .player1GamesWon) ?? 0
        player2GamesWon = try container.decodeIfPresent(Int.self, forKey: .player2GamesWon) ?? 0
        player1SetGames = try container.decodeIfPresent(Int.self, forKey: .player1SetGames) ?? 0
        player2SetGames = try container.decodeIfPresent(Int.self, forKey: .player2SetGames) ?? 0
        currentGameNumber = try container.decodeIfPresent(Int.self, forKey: .currentGameNumber) ?? 1
        bestOf = try container.decodeIfPresent(Int.self, forKey: .bestOf) ?? 1
        scoreType = try container.decodeIfPresent(Int.self, forKey: .scoreType) ?? 15
        currentServer = try container.decodeIfPresent(String.self, forKey: .currentServer)
        currentServerSide = try container.decodeIfPresent(String.self, forKey: .currentServerSide)
        serviceSide = try container.decodeIfPresent(String.self, forKey: .serviceSide)
        player1ShirtColor = try container.decodeIfPresent(String.self, forKey: .player1ShirtColor)
        player2ShirtColor = try container.decodeIfPresent(String.self, forKey: .player2ShirtColor)
        scoreDisplayMode = try container.decodeIfPresent(String.self, forKey: .scoreDisplayMode)
        player1ScoreLabel = try container.decodeIfPresent(String.self, forKey: .player1ScoreLabel)
        player2ScoreLabel = try container.decodeIfPresent(String.self, forKey: .player2ScoreLabel)
        isTieBreak = try container.decodeIfPresent(Bool.self, forKey: .isTieBreak) ?? false
        teamFormat = try container.decodeIfPresent(String.self, forKey: .teamFormat)
        tennisTeams = try container.decodeIfPresent([String: [TennisParticipant]].self, forKey: .tennisTeams)
        currentServerParticipantID = try container.decodeIfPresent(String.self, forKey: .currentServerParticipantID)
        currentReceiver = try container.decodeIfPresent(String.self, forKey: .currentReceiver)
        currentReceiverSide = try container.decodeIfPresent(String.self, forKey: .currentReceiverSide)
        currentReceiverParticipantID = try container.decodeIfPresent(String.self, forKey: .currentReceiverParticipantID)
        teamServiceOrder = try container.decodeIfPresent([String: [String]].self, forKey: .teamServiceOrder)
        serveOrder = try container.decodeIfPresent([String].self, forKey: .serveOrder)
        receiverDeuceOrder = try container.decodeIfPresent([String: String].self, forKey: .receiverDeuceOrder)
        tieBreakFirstServerSide = try container.decodeIfPresent(String.self, forKey: .tieBreakFirstServerSide)
        tieBreakFirstServerParticipantID = try container.decodeIfPresent(String.self, forKey: .tieBreakFirstServerParticipantID)
        handicap = try container.decodeIfPresent(MatchHandicap.self, forKey: .handicap)
        matchDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .matchDurationSeconds) ?? 0
        gameHistory = try container.decodeIfPresent([GameHistoryEntry].self, forKey: .gameHistory) ?? []
        matchComplete = try container.decodeIfPresent(Bool.self, forKey: .matchComplete) ?? false
        winnerName = try container.decodeIfPresent(String.self, forKey: .winnerName)
        events = try container.decodeIfPresent([MatchEvent].self, forKey: .events) ?? []
    }
}

struct TennisParticipant: Codable, Hashable {
    let id: String
    let firstName: String
    let surname: String?
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case surname
        case displayName = "display_name"
    }
}

struct MatchHandicap: Codable {
    let enabled: Bool
    let player1Band: String?
    let player2Band: String?
    let player1Offset: Int
    let player2Offset: Int

    enum CodingKeys: String, CodingKey {
        case enabled
        case player1Band = "player1_band"
        case player2Band = "player2_band"
        case player1Offset = "player1_offset"
        case player2Offset = "player2_offset"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        player1Band = try container.decodeIfPresent(String.self, forKey: .player1Band)
        player2Band = try container.decodeIfPresent(String.self, forKey: .player2Band)
        player1Offset = try container.decodeIfPresent(Int.self, forKey: .player1Offset) ?? 0
        player2Offset = try container.decodeIfPresent(Int.self, forKey: .player2Offset) ?? 0
    }
}

struct GameHistoryEntry: Codable, Identifiable {
    let gameNumber: Int
    let player1Score: Int
    let player2Score: Int
    let winnerName: String?

    var id: Int { gameNumber }

    enum CodingKeys: String, CodingKey {
        case gameNumber = "game_number"
        case player1Score = "player1_score"
        case player2Score = "player2_score"
        case winnerName = "winner_name"
    }
}

struct MatchEvent: Codable, Identifiable {
    let id: String
    let eventType: String
    let payload: MatchEventPayload?
    let createdAt: String?
    let summary: String?

    enum CodingKeys: String, CodingKey {
        case id
        case eventType = "event_type"
        case payload
        case createdAt = "created_at"
        case summary
    }
}

struct MatchEventPayload: Codable {
    let scorer: String?
    let playerSide: String?
    let currentServerSide: String?
    let serviceSide: String?
    let gameCompleted: Bool?
    let matchCompleted: Bool?
    let player1Score: Int?
    let player2Score: Int?
    let player1GamesWon: Int?
    let player2GamesWon: Int?
    let gameNumber: Int?
    let currentGameNumber: Int?
    let player1SetGames: Int?
    let player2SetGames: Int?
    let note: String?
    let side: String?
    let winnerName: String?
    let winnerSide: String?
    let gameResult: GameHistoryEntry?
    let scoreType: Int?
    let bestOf: Int?
    let player1ShirtColor: String?
    let player2ShirtColor: String?
    let currentServerParticipantID: String?
    let currentReceiver: String?
    let currentReceiverSide: String?
    let currentReceiverParticipantID: String?
    let serveOrder: [String]?
    let receiverDeuceOrder: [String: String]?
    let isTieBreak: Bool?
    let player1ScoreLabel: String?
    let player2ScoreLabel: String?

    enum CodingKeys: String, CodingKey {
        case scorer
        case playerSide = "player_side"
        case currentServerSide = "current_server_side"
        case serviceSide = "service_side"
        case gameCompleted = "game_completed"
        case matchCompleted = "match_completed"
        case player1Score = "player1_score"
        case player2Score = "player2_score"
        case player1GamesWon = "player1_games_won"
        case player2GamesWon = "player2_games_won"
        case gameNumber = "game_number"
        case currentGameNumber = "current_game_number"
        case player1SetGames = "player1_set_games"
        case player2SetGames = "player2_set_games"
        case note
        case side
        case winnerName = "winner_name"
        case winnerSide = "winner_side"
        case gameResult = "game_result"
        case scoreType = "score_type"
        case bestOf = "best_of"
        case player1ShirtColor = "player1_shirt_color"
        case player2ShirtColor = "player2_shirt_color"
        case currentServerParticipantID = "current_server_participant_id"
        case currentReceiver = "current_receiver"
        case currentReceiverSide = "current_receiver_side"
        case currentReceiverParticipantID = "current_receiver_participant_id"
        case serveOrder = "serve_order"
        case receiverDeuceOrder = "receiver_deuce_order"
        case isTieBreak = "is_tie_break"
        case player1ScoreLabel = "player1_score_label"
        case player2ScoreLabel = "player2_score_label"
    }

    init(
        scorer: String? = nil,
        playerSide: String? = nil,
        currentServerSide: String? = nil,
        serviceSide: String? = nil,
        gameCompleted: Bool? = nil,
        matchCompleted: Bool? = nil,
        player1Score: Int? = nil,
        player2Score: Int? = nil,
        player1GamesWon: Int? = nil,
        player2GamesWon: Int? = nil,
        gameNumber: Int? = nil,
        currentGameNumber: Int? = nil,
        player1SetGames: Int? = nil,
        player2SetGames: Int? = nil,
        note: String? = nil,
        side: String? = nil,
        winnerName: String? = nil,
        winnerSide: String? = nil,
        gameResult: GameHistoryEntry? = nil,
        scoreType: Int? = nil,
        bestOf: Int? = nil,
        player1ShirtColor: String? = nil,
        player2ShirtColor: String? = nil,
        currentServerParticipantID: String? = nil,
        currentReceiver: String? = nil,
        currentReceiverSide: String? = nil,
        currentReceiverParticipantID: String? = nil,
        serveOrder: [String]? = nil,
        receiverDeuceOrder: [String: String]? = nil,
        isTieBreak: Bool? = nil,
        player1ScoreLabel: String? = nil,
        player2ScoreLabel: String? = nil
    ) {
        self.scorer = scorer
        self.playerSide = playerSide
        self.currentServerSide = currentServerSide
        self.serviceSide = serviceSide
        self.gameCompleted = gameCompleted
        self.matchCompleted = matchCompleted
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.player1GamesWon = player1GamesWon
        self.player2GamesWon = player2GamesWon
        self.gameNumber = gameNumber
        self.currentGameNumber = currentGameNumber
        self.player1SetGames = player1SetGames
        self.player2SetGames = player2SetGames
        self.note = note
        self.side = side
        self.winnerName = winnerName
        self.winnerSide = winnerSide
        self.gameResult = gameResult
        self.scoreType = scoreType
        self.bestOf = bestOf
        self.player1ShirtColor = player1ShirtColor
        self.player2ShirtColor = player2ShirtColor
        self.currentServerParticipantID = currentServerParticipantID
        self.currentReceiver = currentReceiver
        self.currentReceiverSide = currentReceiverSide
        self.currentReceiverParticipantID = currentReceiverParticipantID
        self.serveOrder = serveOrder
        self.receiverDeuceOrder = receiverDeuceOrder
        self.isTieBreak = isTieBreak
        self.player1ScoreLabel = player1ScoreLabel
        self.player2ScoreLabel = player2ScoreLabel
    }
}

struct MatchDisplayAccess: Decodable {
    let matchID: String
    let tenantID: Int?
    let courtID: Int?
    let courtName: String
    let courtAlias: String
    let displayCode: String
    let displayCodeEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case tenantID = "tenant_id"
        case courtID = "court_id"
        case courtName = "court_name"
        case courtAlias = "court_alias"
        case displayCode = "display_code"
        case displayCodeEnabled = "display_code_enabled"
    }
}
