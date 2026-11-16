import Foundation

nonisolated enum WristAction: String, Codable, Sendable {
    case pointOne, pointTwo, undo, receiveRight, receiveLeft
    case strokeOne, strokeTwo, letCall

    var scorer: String {
        self == .pointOne || self == .strokeOne ? "player1" : "player2"
    }
}

nonisolated struct WristRequest: Codable, Sendable {
    let action: WristAction?
    let matchID: String?
    let revision: UUID?

    static let refresh = Self(action: nil, matchID: nil, revision: nil)
}

nonisolated struct WristScore: Codable, Equatable, Sendable {
    struct Side: Codable, Equatable, Sendable {
        let name: String
        let points: String
        let games: Int
        let sets: Int?
        let serving: Bool
    }

    let matchID: String
    let revision: UUID
    let one: Side
    let two: Side
    let server: String?
    let status: String
    let actions: [WristAction]
}

nonisolated struct WristReply: Codable, Sendable {
    let score: WristScore?
    let message: String?
}
