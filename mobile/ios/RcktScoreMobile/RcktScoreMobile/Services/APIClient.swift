import Foundation

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct DashboardResponse: Decodable {
    let activeMatches: [MatchSummary]

    enum CodingKeys: String, CodingKey {
        case activeMatches = "active_matches"
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
        let envelope: APIEnvelope<UserSession> = try await send(request)

        guard let user = envelope.data else {
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

    private func makeRequest<T: Encodable>(path: String, method: String, body: T? = nil) throws -> URLRequest {
        let endpoint = AppConfig.apiBaseURL.appendingPathComponent(path)
        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

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
}
