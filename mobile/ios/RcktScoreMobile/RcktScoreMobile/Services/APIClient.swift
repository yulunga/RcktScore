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

struct DashboardResponseData: Decodable {
    let dashboard: DashboardResponse
}

struct OrganizationSettingsResponseData: Decodable {
    let organizationSettings: OrganizationSettings

    enum CodingKeys: String, CodingKey {
        case organizationSettings = "organizationSettings"
    }
}

struct MatchSetupLookupResponseData: Decodable {
    let lookups: MatchSetupLookups
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
    let currentServer: String?
    let currentServerSide: String?
    let serviceSide: String?
    let matchDurationSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case actionType = "action_type"
        case playerSide = "player_side"
        case note
        case side
        case currentServer = "current_server"
        case currentServerSide = "current_server_side"
        case serviceSide = "service_side"
        case matchDurationSeconds = "match_duration_seconds"
    }
}

struct MatchIDRequest: Encodable {
    let matchID: String

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
    }
}

struct PasswordResetRequest: Encodable {
    let email: String
}

struct RegisterInterestRequest: Encodable {
    let firstName: String
    let surname: String
    let email: String
    let useType: String
    let clubName: String
    let company: String
    let pageURL: String
    let userAgent: String

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case surname
        case email
        case useType = "use_type"
        case clubName = "club_name"
        case company
        case pageURL = "page_url"
        case userAgent = "user_agent"
    }
}

struct FeedbackRequest: Encodable {
    let name: String
    let email: String
    let category: String
    let message: String
    let username: String
    let organizationName: String
    let version: String
    let build: String
    let pageURL: String
    let userAgent: String

    enum CodingKeys: String, CodingKey {
        case name
        case email
        case category
        case message
        case username
        case organizationName = "organization_name"
        case version
        case build
        case pageURL = "page_url"
        case userAgent = "user_agent"
    }
}

private struct AcceptedResponseData: Decodable {
    let accepted: Bool?
}

struct EndMatchRequest: Encodable {
    let matchID: String
    let endedEarly: Bool
    let reason: String?
    let matchDurationSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case endedEarly = "ended_early"
        case reason
        case matchDurationSeconds = "match_duration_seconds"
    }
}

final class APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let apiBaseURL: URL
    private let defaultBuildID: String

    @MainActor
    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.apiBaseURL = AppConfig.apiBaseURL
        self.defaultBuildID = AppConfig.buildID
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

    func requestPasswordReset(email: String) async throws {
        let request = try makeRequest(
            path: "/password_reset/request",
            method: "POST",
            body: PasswordResetRequest(email: email)
        )
        let _: APIEnvelope<AcceptedResponseData> = try await send(request)
    }

    func registerInterest(
        firstName: String,
        surname: String,
        email: String,
        useType: String,
        clubName: String,
        company: String = "",
        pageURL: String = "ios-app://login",
        userAgent: String = "RcktScore iOS App"
    ) async throws {
        let request = try makeRequest(
            path: "/register_interest",
            method: "POST",
            body: RegisterInterestRequest(
                firstName: firstName,
                surname: surname,
                email: email,
                useType: useType,
                clubName: clubName,
                company: company,
                pageURL: pageURL,
                userAgent: userAgent
            )
        )
        let _: APIEnvelope<AcceptedResponseData> = try await send(request)
    }

    func submitFeedback(
        name: String,
        email: String,
        category: String,
        message: String,
        username: String = "",
        organizationName: String = "",
        version: String = "iOS App",
        build: String? = nil,
        pageURL: String = "ios-app://login",
        userAgent: String = "RcktScore iOS App"
    ) async throws {
        let resolvedBuild = build ?? defaultBuildID
        let request = try makeRequest(
            path: "/feedback",
            method: "POST",
            body: FeedbackRequest(
                name: name,
                email: email,
                category: category,
                message: message,
                username: username,
                organizationName: organizationName,
                version: version,
                build: resolvedBuild,
                pageURL: pageURL,
                userAgent: userAgent
            )
        )
        let _: APIEnvelope<AcceptedResponseData> = try await send(request)
    }

    func getDashboard(organizationID: Int) async throws -> DashboardResponse {
        let request = try makeRequest(path: "/dashboard/\(organizationID)", method: "GET")
        let envelope: APIEnvelope<DashboardResponseData> = try await send(request)

        guard let dashboard = envelope.data?.dashboard else {
            throw APIErrorResponse(code: "empty_response", message: "No dashboard payload returned.", details: nil)
        }

        return dashboard
    }

    func getOrganizationSettings(organizationID: Int) async throws -> OrganizationSettings {
        let request = try makeRequest(path: "/organization_settings/\(organizationID)", method: "GET")
        let envelope: APIEnvelope<OrganizationSettingsResponseData> = try await send(request)

        guard let settings = envelope.data?.organizationSettings else {
            throw APIErrorResponse(code: "empty_response", message: "No organisation settings returned.", details: nil)
        }

        return settings
    }

    func searchMatchSetupLookup(organizationID: Int, query: String) async throws -> MatchSetupLookups {
        let request = try makeRequest(
            path: "/match_setup_lookup/\(organizationID)",
            method: "GET",
            queryItems: [URLQueryItem(name: "q", value: query)]
        )
        let envelope: APIEnvelope<MatchSetupLookupResponseData> = try await send(request)

        guard let lookups = envelope.data?.lookups else {
            throw APIErrorResponse(code: "empty_response", message: "No match setup lookups returned.", details: nil)
        }

        return lookups
    }

    func createMatch(_ payload: CreateMatchRequest) async throws -> MatchDetail {
        let request = try makeRequest(path: "/start_match", method: "POST", body: payload)
        return try await unwrapMatchResponse(request)
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
            body: EventActionRequest(
                matchID: matchID,
                actionType: "stroke",
                playerSide: playerSide,
                note: nil,
                side: nil,
                currentServer: nil,
                currentServerSide: nil,
                serviceSide: nil,
                matchDurationSeconds: nil
            )
        )
        return try await unwrapMatchResponse(request)
    }

    func callLet(matchID: String) async throws -> MatchDetail {
        let request = try makeRequest(
            path: "/event_action",
            method: "POST",
            body: EventActionRequest(
                matchID: matchID,
                actionType: "let",
                playerSide: nil,
                note: "General let",
                side: nil,
                currentServer: nil,
                currentServerSide: nil,
                serviceSide: nil,
                matchDurationSeconds: nil
            )
        )
        return try await unwrapMatchResponse(request)
    }

    func setServeSide(matchID: String, side: String) async throws -> MatchDetail {
        let request = try makeRequest(
            path: "/event_action",
            method: "POST",
            body: EventActionRequest(
                matchID: matchID,
                actionType: "serve_side",
                playerSide: nil,
                note: nil,
                side: side,
                currentServer: nil,
                currentServerSide: nil,
                serviceSide: nil,
                matchDurationSeconds: nil
            )
        )
        return try await unwrapMatchResponse(request)
    }

    func selectFirstServer(
        matchID: String,
        currentServer: String,
        currentServerSide: String,
        serviceSide: String
    ) async throws -> MatchDetail {
        let request = try makeRequest(
            path: "/event_action",
            method: "POST",
            body: EventActionRequest(
                matchID: matchID,
                actionType: "server",
                playerSide: nil,
                note: nil,
                side: nil,
                currentServer: currentServer,
                currentServerSide: currentServerSide,
                serviceSide: serviceSide,
                matchDurationSeconds: nil
            )
        )
        return try await unwrapMatchResponse(request)
    }

    func recordMatchDuration(matchID: String, durationSeconds: Int) async throws -> MatchDetail {
        let request = try makeRequest(
            path: "/event_action",
            method: "POST",
            body: EventActionRequest(
                matchID: matchID,
                actionType: "timer",
                playerSide: nil,
                note: "Match duration recorded",
                side: nil,
                currentServer: nil,
                currentServerSide: nil,
                serviceSide: nil,
                matchDurationSeconds: durationSeconds
            )
        )
        return try await unwrapMatchResponse(request)
    }

    func undoAction(matchID: String) async throws -> MatchDetail {
        let request = try makeRequest(path: "/undo_action", method: "POST", body: MatchIDRequest(matchID: matchID))
        return try await unwrapMatchResponse(request)
    }

    func endMatchEarly(
        matchID: String,
        reason: String = "Ended by operator",
        matchDurationSeconds: Int? = nil
    ) async throws -> MatchDetail {
        let request = try makeRequest(
            path: "/end_match",
            method: "POST",
            body: EndMatchRequest(
                matchID: matchID,
                endedEarly: true,
                reason: reason,
                matchDurationSeconds: matchDurationSeconds
            )
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
        let endpoint = apiBaseURL.appendingPathComponent(normalizedPath)
        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func makeRequest(path: String, method: String, queryItems: [URLQueryItem]) throws -> URLRequest {
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let endpoint = apiBaseURL.appendingPathComponent(normalizedPath)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw APIErrorResponse(code: "invalid_url", message: "Unable to build request URL.", details: nil)
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw APIErrorResponse(code: "invalid_url", message: "Unable to build request URL.", details: nil)
        }

        var request = URLRequest(url: url)
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
