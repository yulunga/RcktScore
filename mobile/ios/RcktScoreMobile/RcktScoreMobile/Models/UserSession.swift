import Foundation

struct UserSession: Codable {
    let id: Int
    let username: String
    let role: String
    let organizationID: Int
    let organizationName: String

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case role
        case organizationID = "organization_id"
        case organizationName = "organization_name"
    }
}
