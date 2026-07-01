import Foundation

struct OrganizationSettings: Decodable {
    let organization: OrganizationProfile
    let users: [OrganizationUser]
    let courts: [CourtSummary]
}

struct OrganizationProfile: Decodable {
    let id: Int
    let organizationName: String
    let organizationAddress: String
    let organizationPostcode: String
    let organizationContact: String
    let organizationTelephone: String
    let organizationEmail: String
    let organizationWebAddress: String
    let organizationType: String
    let plan: String?
    let isHidden: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case organizationName = "organization_name"
        case organizationAddress = "org_address"
        case organizationPostcode = "org_postcode"
        case organizationContact = "org_contact"
        case organizationTelephone = "org_telephone"
        case organizationEmail = "org_email"
        case organizationWebAddress = "org_webaddress"
        case organizationType = "org_type"
        case plan
        case isHidden = "is_hidden"
    }
}

struct OrganizationUser: Decodable, Identifiable, Hashable {
    let id: Int
    let username: String
    let role: String
    let status: String
    let firstName: String
    let surname: String
    let country: String
    let cityLocation: String
    let createdAt: String?
    let approvedAt: String?
    let invitationSentAt: String?
    let canEditPassword: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case role
        case status
        case firstName = "first_name"
        case surname
        case country
        case cityLocation = "city_location"
        case createdAt = "created_at"
        case approvedAt = "approved_at"
        case invitationSentAt = "invitation_sent_at"
        case canEditPassword = "can_edit_password"
    }
}

struct CourtSummary: Decodable, Identifiable, Hashable {
    let id: Int
    let courtName: String
    let courtAlias: String
    let displayCode: String?
    let displayCodeEnabled: Bool
    let createdAt: String?
    let displayCodeCreatedAt: String?
    let displayCodeLastUsedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case courtName = "court_name"
        case courtAlias = "court_alias"
        case displayCode = "display_code"
        case displayCodeEnabled = "display_code_enabled"
        case createdAt = "created_at"
        case displayCodeCreatedAt = "display_code_created_at"
        case displayCodeLastUsedAt = "display_code_last_used_at"
    }
}

struct MatchSetupLookups: Decodable {
    let players: [PlayerLookup]
    let referees: [String]
}

struct PlayerLookup: Decodable, Identifiable, Hashable {
    let firstName: String
    let surname: String
    let displayName: String

    var id: String { displayName.lowercased() }

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case surname
        case displayName = "display_name"
    }
}

struct CreateMatchRequest: Encodable {
    let tenantID: String
    let courtID: String?
    let courtName: String?
    let courtAlias: String?
    let player1Name: String
    let player1Surname: String
    let player1Country: String
    let player1Handedness: String
    let player1ShirtColor: String
    let player2Name: String
    let player2Surname: String
    let player2Country: String
    let player2Handedness: String
    let player2ShirtColor: String
    let refereeName: String
    let scoreType: Int
    let bestOf: Int
    let handicapEnabled: Bool
    let player1Band: String
    let player2Band: String
    let player1Offset: Int
    let player2Offset: Int
    let sport: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case tenantID = "tenant_id"
        case courtID = "court_id"
        case courtName = "court_name"
        case courtAlias = "court_alias"
        case player1Name = "player1_name"
        case player1Surname = "player1_surname"
        case player1Country = "player1_country"
        case player1Handedness = "player1_handedness"
        case player1ShirtColor = "player1_shirt_color"
        case player2Name = "player2_name"
        case player2Surname = "player2_surname"
        case player2Country = "player2_country"
        case player2Handedness = "player2_handedness"
        case player2ShirtColor = "player2_shirt_color"
        case refereeName = "referee_name"
        case scoreType = "score_type"
        case bestOf = "best_of"
        case handicapEnabled = "handicap_enabled"
        case player1Band = "player1_band"
        case player2Band = "player2_band"
        case player1Offset = "player1_offset"
        case player2Offset = "player2_offset"
        case sport
        case status
    }
}

struct UpdateOrganizationDetailsRequest: Encodable {
    let organizationName: String
    let organizationAddress: String
    let organizationPostcode: String
    let organizationContact: String
    let organizationTelephone: String
    let organizationEmail: String
    let organizationWebAddress: String

    enum CodingKeys: String, CodingKey {
        case organizationName = "organization_name"
        case organizationAddress = "org_address"
        case organizationPostcode = "org_postcode"
        case organizationContact = "org_contact"
        case organizationTelephone = "org_telephone"
        case organizationEmail = "org_email"
        case organizationWebAddress = "org_webaddress"
    }
}

struct UpdatePersonalProfileRequest: Encodable {
    let username: String
    let firstName: String
    let surname: String
    let country: String
    let cityLocation: String

    enum CodingKeys: String, CodingKey {
        case username
        case firstName = "first_name"
        case surname
        case country
        case cityLocation = "city_location"
    }
}

struct OrganizationUserRequest: Encodable {
    let organizationID: Int
    let firstName: String
    let surname: String
    let username: String
    let password: String?
    let role: String

    enum CodingKeys: String, CodingKey {
        case organizationID = "organization_id"
        case firstName = "first_name"
        case surname
        case username
        case password
        case role
    }
}

struct OrganizationUserUpdateRequest: Encodable {
    let organizationID: Int
    let firstName: String?
    let surname: String?
    let username: String?
    let password: String?
    let role: String?

    enum CodingKeys: String, CodingKey {
        case organizationID = "organization_id"
        case firstName = "first_name"
        case surname
        case username
        case password
        case role
    }
}

struct OrganizationEntityRequest: Encodable {
    let organizationID: Int

    enum CodingKeys: String, CodingKey {
        case organizationID = "organization_id"
    }
}

struct CourtRequest: Encodable {
    let organizationID: Int
    let courtName: String
    let courtAlias: String

    enum CodingKeys: String, CodingKey {
        case organizationID = "organization_id"
        case courtName = "court_name"
        case courtAlias = "court_alias"
    }
}

struct OrganizationDetailsDraft {
    var organizationName: String = ""
    var organizationAddress: String = ""
    var organizationPostcode: String = ""
    var organizationContact: String = ""
    var organizationTelephone: String = ""
    var organizationEmail: String = ""
    var organizationWebAddress: String = ""

    init() {}

    init(profile: OrganizationProfile) {
        organizationName = profile.organizationName
        organizationAddress = profile.organizationAddress
        organizationPostcode = profile.organizationPostcode
        organizationContact = profile.organizationContact
        organizationTelephone = profile.organizationTelephone
        organizationEmail = profile.organizationEmail
        organizationWebAddress = profile.organizationWebAddress
    }
}

struct OrganizationUserDraft {
    var firstName: String = ""
    var surname: String = ""
    var username: String = ""
    var password: String = ""
    var role: String = "user"

    init() {}

    init(user: OrganizationUser) {
        firstName = user.firstName
        surname = user.surname
        username = user.username
        role = user.role
    }
}

struct CourtDraft {
    var courtName: String = ""
    var courtAlias: String = ""

    init() {}

    init(court: CourtSummary) {
        courtName = court.courtName
        courtAlias = court.courtAlias
    }
}
