import Foundation

struct OrganizationSettings: Decodable {
    let organization: OrganizationProfile
    let courts: [CourtSummary]
}

struct OrganizationProfile: Decodable {
    let id: Int
    let organizationName: String
    let organizationType: String
    let plan: String?

    enum CodingKeys: String, CodingKey {
        case id
        case organizationName = "organization_name"
        case organizationType = "org_type"
        case plan
    }
}

struct CourtSummary: Decodable, Identifiable, Hashable {
    let id: Int
    let courtName: String
    let courtAlias: String

    enum CodingKeys: String, CodingKey {
        case id
        case courtName = "court_name"
        case courtAlias = "court_alias"
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
