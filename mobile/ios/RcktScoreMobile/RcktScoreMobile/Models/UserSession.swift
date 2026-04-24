import Foundation

struct UserSession: Codable {
    let id: Int
    let username: String
    let role: String
    let organizationID: Int
    let organizationName: String
    let organizationType: String?
    let plan: String?
    let firstName: String?
    let surname: String?
    let fullName: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case role
        case organizationID = "organization_id"
        case organizationName = "organization_name"
        case organizationType = "organization_type"
        case plan
        case firstName = "first_name"
        case surname
        case fullName = "full_name"
        case email
    }
}

extension UserSession {
    var isPersonalAccount: Bool {
        if organizationType?.lowercased() == "personal" {
            return true
        }

        return organizationID >= 50_000
    }

    var planDisplayName: String {
        switch (plan ?? "").lowercased() {
        case "personal_plus":
            return "Personal+"
        case "personal_free":
            return "Personal Free"
        case "club_pro":
            return "Club Pro"
        case "club_essentials":
            return "Club Essentials"
        default:
            return isPersonalAccount ? "Personal Free" : "Club Essentials"
        }
    }

    var canChooseShirtColors: Bool {
        !isPersonalAccount || (plan ?? "").lowercased() == "personal_plus"
    }
}
