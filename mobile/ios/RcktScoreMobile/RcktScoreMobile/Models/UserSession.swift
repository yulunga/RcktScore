import Foundation

struct UserMembership: Codable, Identifiable, Hashable {
    let id: Int
    let username: String
    let role: String
    let organizationID: Int
    let organizationName: String
    let organizationType: String?
    let plan: String?
    let enabledSports: [String]?
    let firstName: String?
    let surname: String?
    let fullName: String?
    let email: String?
    let country: String?
    let telephone: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case role
        case organizationID = "organization_id"
        case organizationName = "organization_name"
        case organizationType = "organization_type"
        case plan
        case enabledSports = "enabled_sports"
        case firstName = "first_name"
        case surname
        case fullName = "full_name"
        case email
        case country
        case telephone
    }
}

struct UserSession: Codable {
    let id: Int
    let username: String
    let role: String
    let sessionToken: String?
    let sessionExpiresAt: String?
    let organizationID: Int
    let organizationName: String
    let organizationType: String?
    let plan: String?
    let enabledSports: [String]?
    let firstName: String?
    let surname: String?
    let fullName: String?
    let email: String?
    let country: String?
    let telephone: String?
    let availableMemberships: [UserMembership]?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case role
        case sessionToken = "session_token"
        case sessionExpiresAt = "session_expires_at"
        case organizationID = "organization_id"
        case organizationName = "organization_name"
        case organizationType = "organization_type"
        case plan
        case enabledSports = "enabled_sports"
        case firstName = "first_name"
        case surname
        case fullName = "full_name"
        case email
        case country
        case telephone
        case availableMemberships = "available_memberships"
    }
}

extension UserSession {
    var normalizedEnabledSports: [String] {
        guard let enabledSports else {
            return ["squash", "racketball", "tennis"]
        }

        return enabledSports
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

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

    func switchingMembership(to membership: UserMembership) -> UserSession {
        UserSession(
            id: membership.id,
            username: membership.username,
            role: membership.role,
            sessionToken: sessionToken,
            sessionExpiresAt: sessionExpiresAt,
            organizationID: membership.organizationID,
            organizationName: membership.organizationName,
            organizationType: membership.organizationType,
            plan: membership.plan,
            enabledSports: membership.enabledSports,
            firstName: membership.firstName,
            surname: membership.surname,
            fullName: membership.fullName,
            email: membership.email,
            country: membership.country,
            telephone: membership.telephone,
            availableMemberships: availableMemberships
        )
    }

    var isExpired: Bool {
        guard let sessionExpiresAt else {
            return true
        }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expiry = fractionalFormatter.date(from: sessionExpiresAt)
            ?? ISO8601DateFormatter().date(from: sessionExpiresAt)
        guard let expiry else { return true }
        return expiry <= Date()
    }
}
