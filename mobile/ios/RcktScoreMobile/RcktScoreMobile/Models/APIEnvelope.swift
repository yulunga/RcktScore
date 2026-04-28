import Foundation

struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: APIErrorResponse?
    let meta: [String: String]?
}

struct APIErrorResponse: Decodable, Error {
    let code: String
    let message: String
    let details: String?

    init(code: String, message: String, details: String?) {
        self.code = code
        self.message = message
        self.details = details
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        message = try container.decode(String.self, forKey: .message)

        if let stringDetails = try? container.decode(String.self, forKey: .details) {
            details = stringDetails
        } else if let objectDetails = try? container.decode([String: String].self, forKey: .details),
                  let data = try? JSONSerialization.data(withJSONObject: objectDetails, options: []),
                  let json = String(data: data, encoding: .utf8) {
            details = json
        } else if let objectDetails = try? container.decode([String: Bool].self, forKey: .details),
                  let data = try? JSONSerialization.data(withJSONObject: objectDetails, options: []),
                  let json = String(data: data, encoding: .utf8) {
            details = json
        } else {
            details = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case details
    }
}
