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
    let subscriptionProvider: String?
    let subscriptionStatus: String?
    let subscriptionExpiresAt: String?
    let subscriptionAutoRenewEnabled: Bool?
    let subscriptionLastRenewedAt: String?

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
        case subscriptionProvider = "subscription_provider"
        case subscriptionStatus = "subscription_status"
        case subscriptionExpiresAt = "subscription_expires_at"
        case subscriptionAutoRenewEnabled = "subscription_auto_renew_enabled"
        case subscriptionLastRenewedAt = "subscription_last_renewed_at"
    }

    init(
        id: Int,
        username: String,
        role: String,
        organizationID: Int,
        organizationName: String,
        organizationType: String?,
        plan: String?,
        enabledSports: [String]?,
        firstName: String?,
        surname: String?,
        fullName: String?,
        email: String?,
        country: String?,
        telephone: String?,
        subscriptionProvider: String? = nil,
        subscriptionStatus: String? = nil,
        subscriptionExpiresAt: String? = nil,
        subscriptionAutoRenewEnabled: Bool? = nil,
        subscriptionLastRenewedAt: String? = nil
    ) {
        self.id = id
        self.username = username
        self.role = role
        self.organizationID = organizationID
        self.organizationName = organizationName
        self.organizationType = organizationType
        self.plan = plan
        self.enabledSports = enabledSports
        self.firstName = firstName
        self.surname = surname
        self.fullName = fullName
        self.email = email
        self.country = country
        self.telephone = telephone
        self.subscriptionProvider = subscriptionProvider
        self.subscriptionStatus = subscriptionStatus
        self.subscriptionExpiresAt = subscriptionExpiresAt
        self.subscriptionAutoRenewEnabled = subscriptionAutoRenewEnabled
        self.subscriptionLastRenewedAt = subscriptionLastRenewedAt
    }
}

struct UserSession: Codable, Equatable {
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
    let subscriptionProvider: String?
    let subscriptionStatus: String?
    let subscriptionExpiresAt: String?
    let subscriptionAutoRenewEnabled: Bool?
    let subscriptionLastRenewedAt: String?
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
        case subscriptionProvider = "subscription_provider"
        case subscriptionStatus = "subscription_status"
        case subscriptionExpiresAt = "subscription_expires_at"
        case subscriptionAutoRenewEnabled = "subscription_auto_renew_enabled"
        case subscriptionLastRenewedAt = "subscription_last_renewed_at"
        case availableMemberships = "available_memberships"
    }

    init(
        id: Int,
        username: String,
        role: String,
        sessionToken: String?,
        sessionExpiresAt: String?,
        organizationID: Int,
        organizationName: String,
        organizationType: String?,
        plan: String?,
        enabledSports: [String]?,
        firstName: String?,
        surname: String?,
        fullName: String?,
        email: String?,
        country: String?,
        telephone: String?,
        subscriptionProvider: String? = nil,
        subscriptionStatus: String? = nil,
        subscriptionExpiresAt: String? = nil,
        subscriptionAutoRenewEnabled: Bool? = nil,
        subscriptionLastRenewedAt: String? = nil,
        availableMemberships: [UserMembership]?
    ) {
        self.id = id
        self.username = username
        self.role = role
        self.sessionToken = sessionToken
        self.sessionExpiresAt = sessionExpiresAt
        self.organizationID = organizationID
        self.organizationName = organizationName
        self.organizationType = organizationType
        self.plan = plan
        self.enabledSports = enabledSports
        self.firstName = firstName
        self.surname = surname
        self.fullName = fullName
        self.email = email
        self.country = country
        self.telephone = telephone
        self.subscriptionProvider = subscriptionProvider
        self.subscriptionStatus = subscriptionStatus
        self.subscriptionExpiresAt = subscriptionExpiresAt
        self.subscriptionAutoRenewEnabled = subscriptionAutoRenewEnabled
        self.subscriptionLastRenewedAt = subscriptionLastRenewedAt
        self.availableMemberships = availableMemberships
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
            return "Personal Plus"
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
        true
    }

    var normalizedClubRole: String {
        role.lowercased() == "user" ? "scorer" : role.lowercased()
    }

    var canManageMatches: Bool {
        isPersonalAccount || ["admin", "scorer"].contains(normalizedClubRole)
    }

    func switchingMembership(to membership: UserMembership, refreshedMemberships: [UserMembership]? = nil) -> UserSession {
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
            subscriptionProvider: membership.subscriptionProvider,
            subscriptionStatus: membership.subscriptionStatus,
            subscriptionExpiresAt: membership.subscriptionExpiresAt,
            subscriptionAutoRenewEnabled: membership.subscriptionAutoRenewEnabled,
            subscriptionLastRenewedAt: membership.subscriptionLastRenewedAt,
            availableMemberships: refreshedMemberships ?? availableMemberships
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
