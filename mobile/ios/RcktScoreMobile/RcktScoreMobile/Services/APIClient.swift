import Foundation

struct LoginRequest: Encodable {
    let username: String
    let password: String
    let clientType: String
    let forceLogoutOther: Bool

    enum CodingKeys: String, CodingKey {
        case username
        case password
        case clientType = "client_type"
        case forceLogoutOther = "force_logout_other"
    }
}

struct DashboardResponse: Decodable {
    let organization: DashboardOrganizationSummary?
    let activeMatches: [MatchSummary]
    let scheduledMatches: [MatchSummary]
    let recentMatches: [MatchSummary]
    let performance: PersonalPerformanceSummary?

    enum CodingKeys: String, CodingKey {
        case organization
        case activeMatches = "active_matches"
        case scheduledMatches = "scheduled_matches"
        case recentMatches = "recent_matches"
        case performance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        organization = try container.decodeIfPresent(DashboardOrganizationSummary.self, forKey: .organization)
        activeMatches = try container.decodeIfPresent([MatchSummary].self, forKey: .activeMatches) ?? []
        scheduledMatches = try container.decodeIfPresent([MatchSummary].self, forKey: .scheduledMatches) ?? []
        recentMatches = try container.decodeIfPresent([MatchSummary].self, forKey: .recentMatches) ?? []
        performance = try container.decodeIfPresent(PersonalPerformanceSummary.self, forKey: .performance)
    }
}

struct PersonalPerformanceSummary: Decodable {
    let classifiedMatchCount: Int
    let unclassifiedMatchCount: Int
    let matchesPlayed: Int
    let matchesWon: Int
    let matchesLost: Int
    let winPercentage: Double?
    let gamesWon: Int
    let gamesLost: Int
    let gameWinPercentage: Double?
    let pointsWon: Int
    let pointsLost: Int
    let pointWinPercentage: Double?
    let playingTimeSeconds: Int
    let closeGamesPlayed: Int
    let closeGamesWon: Int
    let closeGameWinPercentage: Double?
    let servicePointsWon: Int
    let servicePointsLost: Int
    let servicePointWinPercentage: Double?
    let currentWinStreak: Int
    let bestWinStreak: Int
    let scorelineWins: [PerformanceScoreline]
    let opponents: [PerformanceOpponent]
    let sports: [PerformanceSport]
    let monthlyImprovement: [PerformanceMonthlyImprovement]
    let weeklySummary: PerformancePeriodSummary
    let monthlySummary: PerformancePeriodSummary

    enum CodingKeys: String, CodingKey {
        case classifiedMatchCount = "classified_match_count"
        case unclassifiedMatchCount = "unclassified_match_count"
        case matchesPlayed = "matches_played"
        case matchesWon = "matches_won"
        case matchesLost = "matches_lost"
        case winPercentage = "win_percentage"
        case gamesWon = "games_won"
        case gamesLost = "games_lost"
        case gameWinPercentage = "game_win_percentage"
        case pointsWon = "points_won"
        case pointsLost = "points_lost"
        case pointWinPercentage = "point_win_percentage"
        case playingTimeSeconds = "playing_time_seconds"
        case closeGamesPlayed = "close_games_played"
        case closeGamesWon = "close_games_won"
        case closeGameWinPercentage = "close_game_win_percentage"
        case servicePointsWon = "service_points_won"
        case servicePointsLost = "service_points_lost"
        case servicePointWinPercentage = "service_point_win_percentage"
        case currentWinStreak = "current_win_streak"
        case bestWinStreak = "best_win_streak"
        case scorelineWins = "scoreline_wins"
        case opponents, sports
        case monthlyImprovement = "monthly_improvement"
        case weeklySummary = "weekly_summary"
        case monthlySummary = "monthly_summary"
    }
}

struct PerformanceScoreline: Decodable, Identifiable {
    let scoreline: String
    let count: Int
    var id: String { scoreline }
}

struct PerformanceOpponent: Decodable, Identifiable {
    let name: String
    let matchesPlayed: Int
    let won: Int
    let lost: Int
    let winPercentage: Double?
    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, won, lost
        case matchesPlayed = "matches_played"
        case winPercentage = "win_percentage"
    }
}

struct PerformanceSport: Decodable, Identifiable {
    let sport: String
    let matchesPlayed: Int
    let won: Int
    let lost: Int
    let winPercentage: Double?
    let playingTimeSeconds: Int
    var id: String { sport }

    enum CodingKeys: String, CodingKey {
        case sport, won, lost
        case matchesPlayed = "matches_played"
        case winPercentage = "win_percentage"
        case playingTimeSeconds = "playing_time_seconds"
    }
}

struct PerformanceMonthlyImprovement: Decodable, Identifiable {
    let sport: String
    let currentMonthMatches: Int
    let currentMonthWinPercentage: Double?
    let previousMonthMatches: Int
    let previousMonthWinPercentage: Double?
    let percentagePointChange: Double?
    var id: String { sport }

    enum CodingKeys: String, CodingKey {
        case sport
        case currentMonthMatches = "current_month_matches"
        case currentMonthWinPercentage = "current_month_win_percentage"
        case previousMonthMatches = "previous_month_matches"
        case previousMonthWinPercentage = "previous_month_win_percentage"
        case percentagePointChange = "percentage_point_change"
    }
}

struct PerformancePeriodSummary: Decodable {
    let matchesPlayed: Int
    let matchesWon: Int
    let matchesLost: Int
    let winPercentage: Double?
    let playingTimeSeconds: Int

    enum CodingKeys: String, CodingKey {
        case matchesPlayed = "matches_played"
        case matchesWon = "matches_won"
        case matchesLost = "matches_lost"
        case winPercentage = "win_percentage"
        case playingTimeSeconds = "playing_time_seconds"
    }
}

struct DashboardOrganizationSummary: Decodable {
    let id: Int
    let name: String?
    let type: String?
    let plan: String?
    let historyLimit: Int?
    let courtCount: Int?
    let userCount: Int?
    let roles: [String]
    let completedMatchCount: Int?
    let lockedHistoryCount: Int?
    let entitlements: PersonalPlanEntitlements?
    let availablePlanEntitlements: [String: PersonalPlanEntitlements]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case plan
        case historyLimit = "history_limit"
        case courtCount = "court_count"
        case userCount = "user_count"
        case roles
        case completedMatchCount = "completed_match_count"
        case lockedHistoryCount = "locked_history_count"
        case entitlements
        case availablePlanEntitlements = "available_plan_entitlements"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        plan = try container.decodeIfPresent(String.self, forKey: .plan)
        historyLimit = try container.decodeIfPresent(Int.self, forKey: .historyLimit)
        courtCount = try container.decodeIfPresent(Int.self, forKey: .courtCount)
        userCount = try container.decodeIfPresent(Int.self, forKey: .userCount)
        roles = try container.decodeIfPresent([String].self, forKey: .roles) ?? []
        completedMatchCount = try container.decodeIfPresent(Int.self, forKey: .completedMatchCount)
        lockedHistoryCount = try container.decodeIfPresent(Int.self, forKey: .lockedHistoryCount)
        entitlements = try container.decodeIfPresent(PersonalPlanEntitlements.self, forKey: .entitlements)
        availablePlanEntitlements = try container.decodeIfPresent([String: PersonalPlanEntitlements].self, forKey: .availablePlanEntitlements) ?? [:]
    }
}

struct LoginResponseData: Decodable {
    let session: UserSession
}

struct OrganizationSelectionPayload: Decodable {
    let username: String
    let memberships: [UserMembership]
    let sessionToken: String
    let sessionExpiresAt: String

    enum CodingKeys: String, CodingKey {
        case username
        case memberships
        case sessionToken = "session_token"
        case sessionExpiresAt = "session_expires_at"
    }
}

struct LoginEnvelopeData: Decodable {
    let session: UserSession?
    let organizationSelection: OrganizationSelectionPayload?
}

enum LoginResult {
    case session(UserSession)
    case organizationSelection(OrganizationSelectionPayload)
}

struct DashboardResponseData: Decodable {
    let dashboard: DashboardResponse
}

struct NotificationListResponseData: Decodable {
    let notifications: [AppNotification]
}

struct NotificationReadResponseData: Decodable {
    let read: Bool
}

struct NotificationReadRequest: Encodable {
    let organizationID: Int
    enum CodingKeys: String, CodingKey { case organizationID = "organization_id" }
}

struct AppleSubscriptionContext: Decodable {
    let organizationID: Int
    let appAccountToken: UUID
    let currentPlan: String
    let purchasesEnabled: Bool
    let productIDs: AppleSubscriptionProductIDs

    enum CodingKeys: String, CodingKey {
        case organizationID = "organization_id"
        case appAccountToken = "app_account_token"
        case currentPlan = "current_plan"
        case purchasesEnabled = "purchases_enabled"
        case productIDs = "product_ids"
    }
}

struct AppleSubscriptionProductIDs: Decodable {
    let monthly: String
    let yearly: String
}

struct AppleSubscriptionContextResponseData: Decodable {
    let appleSubscriptionContext: AppleSubscriptionContext
}

struct ApplePurchaseVerificationRequest: Encodable {
    let organizationID: Int
    let signedTransaction: String
    let signedAppTransaction: String

    enum CodingKeys: String, CodingKey {
        case organizationID = "organization_id"
        case signedTransaction = "signed_transaction"
        case signedAppTransaction = "signed_app_transaction"
    }
}

struct VerifiedAppleSubscription: Decodable {
    let organizationID: Int
    let currentPlan: String
    let transactionID: String
    let originalTransactionID: String
    let productID: String
    let environment: String
    let status: String
    let expiresAt: String
    let idempotent: Bool

    enum CodingKeys: String, CodingKey {
        case organizationID = "organization_id"
        case currentPlan = "current_plan"
        case transactionID = "transaction_id"
        case originalTransactionID = "original_transaction_id"
        case productID = "product_id"
        case environment
        case status
        case expiresAt = "expires_at"
        case idempotent
    }
}

struct ApplePurchaseVerificationResponseData: Decodable {
    let appleSubscription: VerifiedAppleSubscription
}

struct AppNotification: Decodable, Identifiable {
    let id: String
    let title: String
    let message: String
    let audience: String
    let createdAt: String
    let readAt: String?
    let isRead: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, message, audience
        case createdAt = "created_at"
        case readAt = "read_at"
        case isRead = "is_read"
    }
}

struct OrganizationSettingsResponseData: Decodable {
    let organizationSettings: OrganizationSettings

    enum CodingKeys: String, CodingKey {
        case organizationSettings = "organizationSettings"
    }
}

struct OrganizationUserResponseData: Decodable {
    let user: OrganizationUser
}

struct DeletePersonalAccountRequest: Encodable {
    let confirmation: String
}

struct CourtResponseData: Decodable {
    let court: CourtSummary
    let organizationSettings: OrganizationSettings?

    enum CodingKeys: String, CodingKey {
        case court
        case organizationSettings
    }
}

struct MatchSetupLookupResponseData: Decodable {
    let lookups: MatchSetupLookups
}

struct MatchResponseData: Decodable {
    let match: MatchDetail
}

struct MatchDisplayAccessResponseData: Decodable {
    let displayAccess: MatchDisplayAccess
}

struct ScorePointRequest: Encodable {
    let matchID: String
    let scorer: String
    let clientActionID: String

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case scorer
        case clientActionID = "client_action_id"
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
    let currentServerParticipantID: String?
    let currentReceiver: String?
    let currentReceiverSide: String?
    let currentReceiverParticipantID: String?
    let serveOrder: [String]?
    let receiverDeuceOrder: [String: String]?
    let clientActionID: String

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
        case currentServerParticipantID = "current_server_participant_id"
        case currentReceiver = "current_receiver"
        case currentReceiverSide = "current_receiver_side"
        case currentReceiverParticipantID = "current_receiver_participant_id"
        case serveOrder = "serve_order"
        case receiverDeuceOrder = "receiver_deuce_order"
        case clientActionID = "client_action_id"
    }
}

struct MatchIDRequest: Encodable {
    let matchID: String
    let clientActionID: String?

    init(matchID: String, clientActionID: String? = nil) {
        self.matchID = matchID
        self.clientActionID = clientActionID
    }

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case clientActionID = "client_action_id"
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
    let requestedPlan: String?
    let clubAddress: String?
    let clubPostcode: String?
    let clubEmail: String?
    let clubWebsite: String?
    let clubTelephone: String?
    let company: String
    let pageURL: String
    let userAgent: String

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case surname
        case email
        case useType = "use_type"
        case clubName = "club_name"
        case requestedPlan = "requested_plan"
        case clubAddress = "club_address"
        case clubPostcode = "club_postcode"
        case clubEmail = "club_email"
        case clubWebsite = "club_website"
        case clubTelephone = "club_telephone"
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
    let loggedOut: Bool?

    enum CodingKeys: String, CodingKey {
        case accepted
        case loggedOut = "logged_out"
    }
}

private struct DeletedAccountResponseData: Decodable {
    let deleted: Bool
}

struct EndMatchRequest: Encodable {
    let matchID: String
    let endedEarly: Bool
    let reason: String?
    let matchDurationSeconds: Int?
    let clientActionID: String

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case endedEarly = "ended_early"
        case reason
        case matchDurationSeconds = "match_duration_seconds"
        case clientActionID = "client_action_id"
    }
}

struct MatchSettingsRequest: Encodable {
    let matchID: String
    let actionType: String
    let scoreType: Int
    let bestOf: Int
    let player1ShirtColor: String?
    let player2ShirtColor: String?
    let clientActionID: String

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case actionType = "action_type"
        case scoreType = "score_type"
        case bestOf = "best_of"
        case player1ShirtColor = "player1_shirt_color"
        case player2ShirtColor = "player2_shirt_color"
        case clientActionID = "client_action_id"
    }
}

@MainActor
final class APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let apiBaseURL: URL
    private let defaultBuildID: String
    private var authToken: String?
    var onSessionInvalidated: ((String) -> Void)?
    private let sessionInvalidationCodes = Set(["SESSION_REQUIRED", "SESSION_INVALID", "SESSION_REPLACED", "SESSION_EXPIRED"])

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.apiBaseURL = AppConfig.apiBaseURL
        self.defaultBuildID = AppConfig.buildID
    }

    func setSessionToken(_ token: String?) {
        let trimmedToken = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        authToken = (trimmedToken?.isEmpty == false) ? trimmedToken : nil
    }

    func login(username: String, password: String, forceLogoutOther: Bool = false) async throws -> LoginResult {
        let payload = LoginRequest(
            username: username,
            password: password,
            clientType: "mobile_app",
            forceLogoutOther: forceLogoutOther
        )
        let request = try makeRequest(path: "/login", method: "POST", body: payload)
        let envelope: APIEnvelope<LoginEnvelopeData> = try await send(request)

        if let user = envelope.data?.session {
            return .session(user)
        }

        if let selection = envelope.data?.organizationSelection {
            return .organizationSelection(selection)
        }

        throw APIErrorResponse(code: "empty_response", message: "No user session returned.", details: nil)
    }

    func requestPasswordReset(email: String) async throws {
        let request = try makeRequest(
            path: "/password_reset/request",
            method: "POST",
            body: PasswordResetRequest(email: email)
        )
        let _: APIEnvelope<AcceptedResponseData> = try await send(request)
    }

    func logout(sessionTokenOverride: String? = nil) async {
        do {
            let request = try makeRequest(
                path: "/logout",
                method: "POST",
                authTokenOverride: sessionTokenOverride
            )
            let _: APIEnvelope<AcceptedResponseData> = try await send(request)
        } catch {
            // Best-effort logout; local session state is cleared by the caller.
        }
    }

    func registerInterest(
        firstName: String,
        surname: String,
        email: String,
        useType: String,
        clubName: String,
        requestedPlan: String? = nil,
        clubAddress: String? = nil,
        clubPostcode: String? = nil,
        clubEmail: String? = nil,
        clubWebsite: String? = nil,
        clubTelephone: String? = nil,
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
                requestedPlan: requestedPlan,
                clubAddress: clubAddress,
                clubPostcode: clubPostcode,
                clubEmail: clubEmail,
                clubWebsite: clubWebsite,
                clubTelephone: clubTelephone,
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

    func getDashboard(
        organizationID: Int,
        activeLimit: Int? = nil,
        recentLimit: Int? = nil
    ) async throws -> DashboardResponse {
        var queryItems: [URLQueryItem] = []
        if let activeLimit {
            queryItems.append(URLQueryItem(name: "active_limit", value: String(activeLimit)))
        }
        if let recentLimit {
            queryItems.append(URLQueryItem(name: "recent_limit", value: String(recentLimit)))
        }

        let request: URLRequest
        if queryItems.isEmpty {
            request = try makeRequest(path: "/dashboard/\(organizationID)", method: "GET")
        } else {
            request = try makeRequest(
                path: "/dashboard/\(organizationID)",
                method: "GET",
                queryItems: queryItems
            )
        }
        let envelope: APIEnvelope<DashboardResponseData> = try await send(request)

        guard let dashboard = envelope.data?.dashboard else {
            throw APIErrorResponse(code: "empty_response", message: "No dashboard payload returned.", details: nil)
        }

        return dashboard
    }

    func getAppleSubscriptionContext(organizationID: Int) async throws -> AppleSubscriptionContext {
        let request = try makeRequest(
            path: "/subscriptions/apple/context/\(organizationID)",
            method: "GET"
        )
        let envelope: APIEnvelope<AppleSubscriptionContextResponseData> = try await send(request)
        guard let context = envelope.data?.appleSubscriptionContext else {
            throw APIErrorResponse(
                code: "empty_response",
                message: "No Apple subscription context was returned.",
                details: nil
            )
        }
        return context
    }

    func verifyApplePurchase(
        organizationID: Int,
        signedTransaction: String,
        signedAppTransaction: String
    ) async throws -> VerifiedAppleSubscription {
        let request = try makeRequest(
            path: "/subscriptions/apple/verify",
            method: "POST",
            body: ApplePurchaseVerificationRequest(
                organizationID: organizationID,
                signedTransaction: signedTransaction,
                signedAppTransaction: signedAppTransaction
            )
        )
        let envelope: APIEnvelope<ApplePurchaseVerificationResponseData> = try await send(request)
        guard let subscription = envelope.data?.appleSubscription else {
            throw APIErrorResponse(
                code: "empty_response",
                message: "No verified Apple subscription was returned.",
                details: nil
            )
        }
        return subscription
    }

    func getNotifications(organizationID: Int) async throws -> [AppNotification] {
        let request = try makeRequest(path: "/notifications/\(organizationID)", method: "GET")
        let envelope: APIEnvelope<NotificationListResponseData> = try await send(request)
        return envelope.data?.notifications ?? []
    }

    func markNotificationRead(notificationID: String, organizationID: Int) async throws {
        let request = try makeRequest(
            path: "/notifications/\(notificationID)/read",
            method: "POST",
            body: NotificationReadRequest(organizationID: organizationID)
        )
        let envelope: APIEnvelope<NotificationReadResponseData> = try await send(request)
        guard envelope.data?.read == true else {
            throw APIErrorResponse(code: "notification_read_failed", message: "The notification was not marked as read.", details: nil)
        }
    }

    func getOrganizationSettings(organizationID: Int) async throws -> OrganizationSettings {
        let request = try makeRequest(path: "/organization_settings/\(organizationID)", method: "GET")
        let envelope: APIEnvelope<OrganizationSettingsResponseData> = try await send(request)

        guard let settings = envelope.data?.organizationSettings else {
            throw APIErrorResponse(code: "empty_response", message: "No organisation settings returned.", details: nil)
        }

        return settings
    }

    func updateOrganizationDetails(
        organizationID: Int,
        draft: OrganizationDetailsDraft
    ) async throws -> OrganizationSettings {
        let request = try makeRequest(
            path: "/organization_details/\(organizationID)",
            method: "PUT",
            body: UpdateOrganizationDetailsRequest(
                organizationName: draft.organizationName,
                organizationAddress: draft.organizationAddress,
                organizationPostcode: draft.organizationPostcode,
                organizationContact: draft.organizationContact,
                organizationTelephone: draft.organizationTelephone,
                organizationEmail: draft.organizationEmail,
                organizationWebAddress: draft.organizationWebAddress,
                enabledSports: nil
            )
        )
        return try await unwrapOrganizationSettingsResponse(request)
    }

    func updateOrganizationEnabledSports(
        organizationID: Int,
        enabledSports: [String]
    ) async throws -> OrganizationSettings {
        let request = try makeRequest(
            path: "/organization_details/\(organizationID)",
            method: "PUT",
            body: UpdateOrganizationDetailsRequest(
                organizationName: nil,
                organizationAddress: nil,
                organizationPostcode: nil,
                organizationContact: nil,
                organizationTelephone: nil,
                organizationEmail: nil,
                organizationWebAddress: nil,
                enabledSports: enabledSports
            )
        )
        return try await unwrapOrganizationSettingsResponse(request)
    }

    func updatePersonalProfile(
        organizationID: Int,
        firstName: String,
        surname: String,
        email: String,
        country: String,
        telephone: String,
        cityLocation: String
    ) async throws -> OrganizationSettings {
        let request = try makeRequest(
            path: "/personal_profile/\(organizationID)",
            method: "PUT",
            body: UpdatePersonalProfileRequest(
                firstName: firstName,
                surname: surname,
                email: email,
                country: country,
                telephone: telephone,
                cityLocation: cityLocation
            )
        )
        return try await unwrapOrganizationSettingsResponse(request)
    }

    func deletePersonalAccount(organizationID: Int) async throws {
        let request = try makeRequest(
            path: "/personal_account/\(organizationID)",
            method: "DELETE",
            body: DeletePersonalAccountRequest(confirmation: "DELETE MY ACCOUNT")
        )
        let response: APIEnvelope<DeletedAccountResponseData> = try await send(request)
        guard response.data?.deleted == true else {
            throw APIErrorResponse(
                code: "ACCOUNT_DELETION_FAILED",
                message: "The server did not confirm account deletion.",
                details: nil
            )
        }
    }

    func createOrganizationUser(
        organizationID: Int,
        draft: OrganizationUserDraft
    ) async throws {
        let password = draft.password.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = try makeRequest(
            path: "/organization_users",
            method: "POST",
            body: OrganizationUserRequest(
                organizationID: organizationID,
                firstName: draft.firstName,
                surname: draft.surname,
                username: draft.username,
                password: password.isEmpty ? nil : password,
                role: draft.role
            )
        )
        let _: APIEnvelope<OrganizationUserResponseData> = try await send(request)
    }

    func updateOrganizationUser(
        organizationID: Int,
        userID: Int,
        draft: OrganizationUserDraft,
        allowPasswordChange: Bool
    ) async throws {
        let password = draft.password.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = try makeRequest(
            path: "/organization_users/\(userID)",
            method: "PUT",
            body: OrganizationUserUpdateRequest(
                organizationID: organizationID,
                firstName: draft.firstName,
                surname: draft.surname,
                username: draft.username,
                password: allowPasswordChange && !password.isEmpty ? password : nil,
                role: draft.role
            )
        )
        let _: APIEnvelope<OrganizationUserResponseData> = try await send(request)
    }

    func deleteOrganizationUser(
        organizationID: Int,
        userID: Int
    ) async throws {
        let request = try makeRequest(
            path: "/organization_users/\(userID)",
            method: "DELETE",
            body: OrganizationEntityRequest(organizationID: organizationID)
        )
        let _: APIEnvelope<AcceptedResponseData> = try await send(request)
    }

    func createCourt(
        organizationID: Int,
        draft: CourtDraft
    ) async throws {
        let request = try makeRequest(
            path: "/organization_courts",
            method: "POST",
            body: CourtRequest(
                organizationID: organizationID,
                courtName: draft.courtName,
                courtAlias: draft.courtAlias
            )
        )
        let _: APIEnvelope<CourtResponseData> = try await send(request)
    }

    func updateCourt(
        organizationID: Int,
        courtID: Int,
        draft: CourtDraft
    ) async throws {
        let request = try makeRequest(
            path: "/organization_courts/\(courtID)",
            method: "PUT",
            body: CourtRequest(
                organizationID: organizationID,
                courtName: draft.courtName,
                courtAlias: draft.courtAlias
            )
        )
        let _: APIEnvelope<CourtResponseData> = try await send(request)
    }

    func deleteCourt(
        organizationID: Int,
        courtID: Int
    ) async throws {
        let request = try makeRequest(
            path: "/organization_courts/\(courtID)",
            method: "DELETE",
            body: OrganizationEntityRequest(organizationID: organizationID)
        )
        let _: APIEnvelope<AcceptedResponseData> = try await send(request)
    }

    func createCourtDisplayCode(
        organizationID: Int,
        courtID: Int
    ) async throws -> OrganizationSettings {
        let request = try makeRequest(
            path: "/organization_courts/\(courtID)/display-code",
            method: "POST",
            body: OrganizationEntityRequest(organizationID: organizationID)
        )
        return try await unwrapOrganizationSettingsResponse(request)
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

    func getMatchDisplayAccess(matchID: String) async throws -> MatchDisplayAccess {
        let request = try makeRequest(path: "/match_display_access/\(matchID)", method: "GET")
        let envelope: APIEnvelope<MatchDisplayAccessResponseData> = try await send(request)

        guard let displayAccess = envelope.data?.displayAccess else {
            throw APIErrorResponse(code: "empty_response", message: "No match display access returned.", details: nil)
        }

        return displayAccess
    }

    func scorePoint(matchID: String, scorer: String, clientActionID: String = UUID().uuidString) async throws -> MatchDetail {
        let request = try makeRequest(
            path: "/score_point",
            method: "POST",
            body: ScorePointRequest(matchID: matchID, scorer: scorer, clientActionID: clientActionID)
        )
        return try await unwrapMatchResponse(request)
    }

    func awardStroke(matchID: String, playerSide: String, clientActionID: String = UUID().uuidString) async throws -> MatchDetail {
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
                matchDurationSeconds: nil,
                currentServerParticipantID: nil,
                currentReceiver: nil,
                currentReceiverSide: nil,
                currentReceiverParticipantID: nil,
                serveOrder: nil,
                receiverDeuceOrder: nil,
                clientActionID: clientActionID
            )
        )
        return try await unwrapMatchResponse(request)
    }

    func callLet(matchID: String, playerSide: String? = nil, note: String = "General let", clientActionID: String = UUID().uuidString) async throws -> MatchDetail {
        let request = try makeRequest(
            path: "/event_action",
            method: "POST",
            body: EventActionRequest(
                matchID: matchID,
                actionType: "let",
                playerSide: playerSide,
                note: note,
                side: nil,
                currentServer: nil,
                currentServerSide: nil,
                serviceSide: nil,
                matchDurationSeconds: nil,
                currentServerParticipantID: nil,
                currentReceiver: nil,
                currentReceiverSide: nil,
                currentReceiverParticipantID: nil,
                serveOrder: nil,
                receiverDeuceOrder: nil,
                clientActionID: clientActionID
            )
        )
        return try await unwrapMatchResponse(request)
    }

    func setServeSide(matchID: String, side: String, clientActionID: String = UUID().uuidString) async throws -> MatchDetail {
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
                matchDurationSeconds: nil,
                currentServerParticipantID: nil,
                currentReceiver: nil,
                currentReceiverSide: nil,
                currentReceiverParticipantID: nil,
                serveOrder: nil,
                receiverDeuceOrder: nil,
                clientActionID: clientActionID
            )
        )
        return try await unwrapMatchResponse(request)
    }

    func chooseNoAdReceiverSide(matchID: String, side: String, clientActionID: String = UUID().uuidString) async throws -> MatchDetail {
        let request = try makeRequest(
            path: "/event_action",
            method: "POST",
            body: EventActionRequest(
                matchID: matchID,
                actionType: "receiver_choice",
                playerSide: nil,
                note: nil,
                side: side,
                currentServer: nil,
                currentServerSide: nil,
                serviceSide: nil,
                matchDurationSeconds: nil,
                currentServerParticipantID: nil,
                currentReceiver: nil,
                currentReceiverSide: nil,
                currentReceiverParticipantID: nil,
                serveOrder: nil,
                receiverDeuceOrder: nil,
                clientActionID: clientActionID
            )
        )
        return try await unwrapMatchResponse(request)
    }

    func selectFirstServer(
        matchID: String,
        currentServer: String,
        currentServerSide: String,
        serviceSide: String,
        currentServerParticipantID: String? = nil,
        currentReceiver: String? = nil,
        currentReceiverSide: String? = nil,
        currentReceiverParticipantID: String? = nil,
        serveOrder: [String]? = nil,
        receiverDeuceOrder: [String: String]? = nil,
        clientActionID: String = UUID().uuidString
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
                matchDurationSeconds: nil,
                currentServerParticipantID: currentServerParticipantID,
                currentReceiver: currentReceiver,
                currentReceiverSide: currentReceiverSide,
                currentReceiverParticipantID: currentReceiverParticipantID,
                serveOrder: serveOrder,
                receiverDeuceOrder: receiverDeuceOrder,
                clientActionID: clientActionID
            )
        )
        return try await unwrapMatchResponse(request)
    }

    func recordMatchDuration(matchID: String, durationSeconds: Int, clientActionID: String = UUID().uuidString) async throws -> MatchDetail {
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
                matchDurationSeconds: durationSeconds,
                currentServerParticipantID: nil,
                currentReceiver: nil,
                currentReceiverSide: nil,
                currentReceiverParticipantID: nil,
                serveOrder: nil,
                receiverDeuceOrder: nil,
                clientActionID: clientActionID
            )
        )
        return try await unwrapMatchResponse(request)
    }

    func undoAction(matchID: String, clientActionID: String = UUID().uuidString) async throws -> MatchDetail {
        let request = try makeRequest(path: "/undo_action", method: "POST", body: MatchIDRequest(matchID: matchID, clientActionID: clientActionID))
        return try await unwrapMatchResponse(request)
    }

    func endMatchEarly(
        matchID: String,
        reason: String = "Ended by operator",
        matchDurationSeconds: Int? = nil,
        clientActionID: String = UUID().uuidString
    ) async throws -> MatchDetail {
        let request = try makeRequest(
            path: "/end_match",
            method: "POST",
            body: EndMatchRequest(
                matchID: matchID,
                endedEarly: true,
                reason: reason,
                matchDurationSeconds: matchDurationSeconds,
                clientActionID: clientActionID
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

    func updateMatchSettings(
        matchID: String,
        scoreType: Int,
        bestOf: Int,
        player1ShirtColor: String?,
        player2ShirtColor: String?,
        clientActionID: String = UUID().uuidString
    ) async throws -> MatchDetail {
        let request = try makeRequest(
            path: "/event_action",
            method: "POST",
            body: MatchSettingsRequest(
                matchID: matchID,
                actionType: "match_settings",
                scoreType: scoreType,
                bestOf: bestOf,
                player1ShirtColor: player1ShirtColor,
                player2ShirtColor: player2ShirtColor,
                clientActionID: clientActionID
            )
        )
        return try await unwrapMatchResponse(request)
    }

    private func makeRequest(path: String, method: String, authTokenOverride: String? = nil) throws -> URLRequest {
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let endpoint = apiBaseURL.appendingPathComponent(normalizedPath)
        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let resolvedAuthToken = authTokenOverride ?? authToken
        if let resolvedAuthToken, !resolvedAuthToken.isEmpty {
            request.setValue("Bearer \(resolvedAuthToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func makeRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        authTokenOverride: String? = nil
    ) throws -> URLRequest {
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
        let resolvedAuthToken = authTokenOverride ?? authToken
        if let resolvedAuthToken, !resolvedAuthToken.isEmpty {
            request.setValue("Bearer \(resolvedAuthToken)", forHTTPHeaderField: "Authorization")
        }
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

        let error = envelope.error ?? APIErrorResponse(
            code: "request_failed",
            message: "Request failed.",
            details: "HTTP \(http.statusCode)"
        )
        handleSessionInvalidationIfNeeded(statusCode: http.statusCode, error: error)
        throw error
    }

    private func handleSessionInvalidationIfNeeded(statusCode: Int, error: APIErrorResponse) {
        guard statusCode == 401, sessionInvalidationCodes.contains(error.code) else {
            return
        }

        authToken = nil
        onSessionInvalidated?(error.code)
    }

    private func unwrapMatchResponse(_ request: URLRequest) async throws -> MatchDetail {
        let envelope: APIEnvelope<MatchResponseData> = try await send(request)

        guard let match = envelope.data?.match else {
            throw APIErrorResponse(code: "empty_response", message: "No match payload returned.", details: nil)
        }

        return match
    }

    private func unwrapOrganizationSettingsResponse(_ request: URLRequest) async throws -> OrganizationSettings {
        let envelope: APIEnvelope<OrganizationSettingsResponseData> = try await send(request)

        guard let settings = envelope.data?.organizationSettings else {
            throw APIErrorResponse(code: "empty_response", message: "No organisation settings returned.", details: nil)
        }

        return settings
    }
}
