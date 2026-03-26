import Foundation

struct MatchSummary: Decodable, Identifiable {
    let id: String
    let player1Name: String
    let player2Name: String
    let courtName: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id = "match_id"
        case player1Name = "player1_name"
        case player2Name = "player2_name"
        case courtName = "court_name"
        case status
    }
}
