import Foundation

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct DashboardResponse: Decodable {
    let activeMatches: [MatchSummary]
    let scheduledMatches: [MatchSummary]
    let recentMatches: [MatchSummary]

    enum CodingKeys: String, CodingKey {
        case activeMatches = "active_matches"
        case scheduledMatches = "scheduled_matches"
        case recentMatches = "recent_matches"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activeMatches = try container.decodeIfPresent([MatchSummary].self, forKey: .activeMatches) ?? []
        scheduledMatches = try container.decodeIfPresent([MatchSummary].self, forKey: .scheduledMatches) ?? []
        recentMatches = try container.decodeIfPresent([MatchSummary].self, forKey: .recentMatches) ?? []
    }
}

struct LoginResponseData: Decodable {
    let session: UserSession
}

struct MatchResponseData: Decodable {
    let match: MatchDetail
}

struct ScorePointRequest: Encodable {
    let matchID: String
    let scorer: String

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case scorer
    }
}

struct EventActionRequest: Encodable {
    let matchID: String
    let actionType: String
    let playerSide: String?
    let note: String?
    let side: String?

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case actionType = "action_type"
        case playerSide = "player_side"
        case note
        case side
    }
}

struct MatchIDRequest: Encodable {
    let matchID: String

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
    }
}

struct EndMatchRequest: Encodable {
    let matchID: String
    let endedEarly: Bool
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case endedEarly = "ended_early"
        case reason
    }
}

final class APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    func login(username: String, password: String) async throws -> UserSession {
        let payload = LoginRequest(username: username, password: password)
        let request = try makeRequest(path: "/login", method: "POST", body: payload)
        let envelope: APIEnvelope<LoginResponseData> = try await send(request)

        guard let user = envelope.data?.session else {
            throw APIErrorResponse(code: "empty_response", message: "No user session returned.", details: nil)
        }

        return user
    }

    func getDashboard(organizationID: Int) async throws -> DashboardResponse {
        let request = try makeRequest(path: "/dashboard/\(organizationID)", method: "GET")
        let envelope: APIEnvelope<DashboardResponse> = try await send(request)

        guard let dashboard = envelope.data else {
            throw APIErrorResponse(code: "empty_response", message: "No dashboard payload returned.", details: nil)
        }

        return dashboard
    }

    func getMatch(matchID: String) async throws -> MatchDetail {
        let request = try makeRequest(path: "/get_score/\(matchID)", method: "GET")
        let envelope: APIEnvelope<MatchResponseData> = try await send(request)

        guard let match = envelope.data?.match else {
            throw APIErrorResponse(code: "empty_response", message: "No match payload returned.", details: nil)
        }

        return match
    }

    func scorePoint(matchID: String, scorer: String) async throws -> MatchDetail {
        let request = try makeRequest(
            path: "/score_point",
            method: "POST",
            body: ScorePointRequest(matchID: matchID, scorer: scorer)
        )
        return try await unwrapMatchResponse(request)
    }

    func awardStroke(matchID: String, playerSide: String) async throws -> MatchDetail {
        let request = try makeRequest(
            path: "/event_action",
            method: "POST",
            body: EventActionRequest(matchID: matchID, actionType: "stroke", playerSide: playerSide, note: nil, side: nil)
        )
        return try await unwrapMatchResponse(request)
    }

    func callLet(matchID: String) async throws -> MatchDetail {
        let request = try makeRequest(
            path: "/event_action",
            method: "POST",
            body: EventActionRequest(matchID: matchID, actionType: "let", playerSide: nil, note: "General let", side: nil)
        )
        return try await unwrapMatchResponse(request)
    }

    func setServeSide(matchID: String, side: String) async throws -> MatchDetail {
        let request = try makeRequest(
            path: "/event_action",
            method: "POST",
            body: EventActionRequest(matchID: matchID, actionType: "serve_side", playerSide: nil, note: nil, side: side)
        )
        return try await unwrapMatchResponse(request)
    }

    func undoAction(matchID: String) async throws -> MatchDetail {
        let request = try makeRequest(path: "/undo_action", method: "POST", body: MatchIDRequest(matchID: matchID))
        return try await unwrapMatchResponse(request)
    }

    func endMatchEarly(matchID: String, reason: String = "Ended by operator") async throws -> MatchDetail {
        let request = try makeRequest(
            path: "/end_match",
            method: "POST",
            body: EndMatchRequest(matchID: matchID, endedEarly: true, reason: reason)
        )
        return try await unwrapMatchResponse(request)
    }

    func startScheduledMatch(matchID: String) async throws -> MatchDetail {
        let request = try makeRequest(
            path: "/start_scheduled_match",
            method: "POST",
            body: MatchIDRequest(matchID: matchID)
        )
        return try await unwrapMatchResponse(request)
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let endpoint = AppConfig.apiBaseURL.appendingPathComponent(normalizedPath)
        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func makeRequest<T: Encodable>(path: String, method: String, body: T) throws -> URLRequest {
        var request = try makeRequest(path: path, method: method)
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> APIEnvelope<T> {
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIErrorResponse(code: "network_error", message: "Invalid network response.", details: nil)
        }

        let envelope = try decoder.decode(APIEnvelope<T>.self, from: data)

        if (200..<300).contains(http.statusCode), envelope.success {
            return envelope
        }

        throw envelope.error ?? APIErrorResponse(code: "request_failed", message: "Request failed.", details: "HTTP \(http.statusCode)")
    }

    private func unwrapMatchResponse(_ request: URLRequest) async throws -> MatchDetail {
        let envelope: APIEnvelope<MatchResponseData> = try await send(request)

        guard let match = envelope.data?.match else {
            throw APIErrorResponse(code: "empty_response", message: "No match payload returned.", details: nil)
        }

        return match
    }
}
