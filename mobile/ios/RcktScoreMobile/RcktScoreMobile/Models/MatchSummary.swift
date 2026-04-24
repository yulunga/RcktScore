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

struct MatchDetail: Decodable, Identifiable {
    let id: String
    let courtName: String?
    let courtAlias: String?
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
    let status: String
    let autoScheduled: Bool?
    let autoScheduleReason: String?
    let updatedAt: String
    let completedAt: String?
    let matchDurationSeconds: Int?
    let state: MatchState?

    enum CodingKeys: String, CodingKey {
        case id
        case courtName = "court_name"
        case courtAlias = "court_alias"
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
        case status
        case autoScheduled = "auto_scheduled"
        case autoScheduleReason = "auto_schedule_reason"
        case updatedAt = "updated_at"
        case completedAt = "completed_at"
        case matchDurationSeconds = "match_duration_seconds"
        case state
    }
}

struct MatchState: Decodable {
    let player1Score: Int
    let player2Score: Int
    let player1GamesWon: Int
    let player2GamesWon: Int
    let currentGameNumber: Int
    let bestOf: Int
    let currentServer: String?
    let currentServerSide: String?
    let serviceSide: String?
    let player1ShirtColor: String?
    let player2ShirtColor: String?
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
        case currentGameNumber = "current_game_number"
        case bestOf = "best_of"
        case currentServer = "current_server"
        case currentServerSide = "current_server_side"
        case serviceSide = "service_side"
        case player1ShirtColor = "player1_shirt_color"
        case player2ShirtColor = "player2_shirt_color"
        case matchDurationSeconds = "match_duration_seconds"
        case gameHistory = "game_history"
        case matchComplete = "match_complete"
        case winnerName = "winner_name"
        case events
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        player1Score = try container.decodeIfPresent(Int.self, forKey: .player1Score) ?? 0
        player2Score = try container.decodeIfPresent(Int.self, forKey: .player2Score) ?? 0
        player1GamesWon = try container.decodeIfPresent(Int.self, forKey: .player1GamesWon) ?? 0
        player2GamesWon = try container.decodeIfPresent(Int.self, forKey: .player2GamesWon) ?? 0
        currentGameNumber = try container.decodeIfPresent(Int.self, forKey: .currentGameNumber) ?? 1
        bestOf = try container.decodeIfPresent(Int.self, forKey: .bestOf) ?? 1
        currentServer = try container.decodeIfPresent(String.self, forKey: .currentServer)
        currentServerSide = try container.decodeIfPresent(String.self, forKey: .currentServerSide)
        serviceSide = try container.decodeIfPresent(String.self, forKey: .serviceSide)
        player1ShirtColor = try container.decodeIfPresent(String.self, forKey: .player1ShirtColor)
        player2ShirtColor = try container.decodeIfPresent(String.self, forKey: .player2ShirtColor)
        matchDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .matchDurationSeconds) ?? 0
        gameHistory = try container.decodeIfPresent([GameHistoryEntry].self, forKey: .gameHistory) ?? []
        matchComplete = try container.decodeIfPresent(Bool.self, forKey: .matchComplete) ?? false
        winnerName = try container.decodeIfPresent(String.self, forKey: .winnerName)
        events = try container.decodeIfPresent([MatchEvent].self, forKey: .events) ?? []
    }
}

struct GameHistoryEntry: Decodable, Identifiable {
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

struct MatchEvent: Decodable, Identifiable {
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

struct MatchEventPayload: Decodable {
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
    let note: String?
    let side: String?
    let winnerName: String?
    let gameResult: GameHistoryEntry?

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
        case note
        case side
        case winnerName = "winner_name"
        case gameResult = "game_result"
    }
}
