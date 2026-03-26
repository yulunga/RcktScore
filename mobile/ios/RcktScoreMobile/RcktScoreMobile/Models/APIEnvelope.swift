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
}
