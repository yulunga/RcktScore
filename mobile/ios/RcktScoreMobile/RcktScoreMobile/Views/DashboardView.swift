import Foundation
import PhotosUI
import StoreKit
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var activeMatches: [MatchSummary] = []
    @State private var scheduledMatches: [MatchSummary] = []
    @State private var recentMatches: [MatchSummary] = []
    @State private var viewedMatches: [MatchSummary] = []
    @State private var performanceSummary: PersonalPerformanceSummary?
    @State private var personalAppAnalytics: AppAnalyticsSummary?
    @State private var personalPlayerAnalytics: BasicPlayerAnalyticsSummary?
    @State private var clubAppAnalytics: AppAnalyticsSummary?
    @State private var clubAnalytics: ClubAnalyticsSummary?
    @State private var analyticsExportURL: URL?
    @State private var isExportingAnalytics = false
    @State private var analyticsExportError: String?
    @State private var organizationSummary: DashboardOrganizationSummary?
    @State private var organizationSettings: OrganizationSettings?
    @State private var isLoading = false
    @State private var isLoadingSettings = false
    @State private var errorMessage: String?
    @State private var settingsErrorMessage: String?
    @State private var settingsSuccessMessage: String?
    @State private var startingScheduledMatchID: String?
    @State private var navigationTarget: MatchRoute?
    @State private var activeSheet: DashboardSheet?
    @State private var dashboardNotice: String?
    @State private var transientNotice: String?
    @State private var transientNoticeTask: Task<Void, Never>?
    @State private var showsAccountContextMenu = false
    @State private var associationClubRoute: AssociationClubRoute?
    @State private var selectedTab: DashboardTab = .home
    @State private var selectedSettingsSection: SettingsSection = .subscription
    @State private var settingsNavigationItem: SettingsMenuItem?
    @State private var clubEnquiryPlan: ClubSubscriptionPlan?
    @State private var clubEnquiryDraft = ClubSubscriptionEnquiryDraft()
    @State private var isSubmittingClubEnquiry = false
    @State private var clubEnquiryErrorMessage: String?
    @State private var clubEnquirySuccessMessage: String?
    @State private var organizationDetailsDraft = OrganizationDetailsDraft()
    @State private var newOrganizationUserDraft = OrganizationUserDraft()
    @State private var organizationUserDrafts: [Int: OrganizationUserDraft] = [:]
    @State private var newCourtDraft = CourtDraft()
    @State private var courtDrafts: [Int: CourtDraft] = [:]
    @State private var personalProfileDraft = PersonalProfileDraft()
    @State private var isEditingPersonalProfile = false
    @State private var enabledSportsDraft: [String] = []
    @State private var timedBreakDefaultsDraft: [String: Bool] = [:]
    @State private var savingSettingsKey: String?
    @State private var historySearch = ""
    @State private var feedbackName = ""
    @State private var feedbackEmail = ""
    @State private var feedbackCategory = "feedback"
    @State private var feedbackMessage = ""
    @State private var isSubmittingFeedback = false
    @State private var feedbackErrorMessage: String?
    @State private var feedbackSuccessMessage: String?
    @State private var resetEmail = ""
    @State private var isRequestingPasswordReset = false
    @State private var resetErrorMessage: String?
    @State private var resetMessage: String?
    @State private var selectedProfilePhotoItem: PhotosPickerItem?
    @State private var selectedProfilePhotoData: Data?
    @State private var profileImageURL: URL?
    @State private var profileImageBusy = false
    @State private var isUpdatingBiometricUnlock = false
    @State private var accountDeletionPrompt: AccountDeletionPrompt?
    @State private var isDeletingAccount = false
    @State private var showsNotifications = false
    @State private var notifications: [AppNotification] = []
    @State private var notificationErrorMessage: String?
    @State private var selectedMatchesCategory: MatchesCategory = .current
    @State private var matchWatchCode = ""
    @State private var selectedAnalyticsCategory: AnalyticsCategory = .personal
    @State private var analyticsPeriodDays = 30
    @State private var showsManageSubscriptions = false
    @State private var isPersonalPlusOptionsExpanded = false
    @State private var personalPlusCollapseTask: Task<Void, Never>?

    private var session: UserSession? { container.sessionStore.session }
    private var isOnline: Bool { container.networkMonitor.isOnline }
    private var isPersonalAccount: Bool { session?.isPersonalAccount ?? false }
    private var currentPlanCode: String {
        (organizationSummary?.plan ?? organizationSettings?.organization.plan ?? session?.plan ?? "")
            .lowercased()
    }
    private var isPersonalPlus: Bool { currentPlanCode == "personal_plus" }
    private var personalMembership: UserMembership? {
        availableMemberships.first { membership in
            membership.organizationType?.lowercased() == "personal" || membership.organizationID >= 50_000
        }
    }
    private var personalAnalyticsIsPlus: Bool {
        if let personalMembership {
            return personalMembership.plan?.lowercased() == "personal_plus"
        }
        return isPersonalAccount && isPersonalPlus
    }
    private var personalProfileOrganizationID: Int? {
        personalMembership?.organizationID ?? (isPersonalAccount ? session?.organizationID : nil)
    }
    private var personalIdentityUsername: String {
        let candidates = [
            personalMembership?.email,
            personalMembership?.username,
            session?.email,
            session?.username
        ]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? "HitnScore user"
    }
    private var personalIdentityInitials: String {
        let fullName = personalMembership?.fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let names = fullName.isEmpty
            ? [personalMembership?.firstName, personalMembership?.surname]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            : fullName.split(separator: " ").map(String.init)
        let initials = names.prefix(2).compactMap { $0.first.map { String($0).uppercased() } }.joined()
        return initials.isEmpty ? currentUserInitials : initials
    }
    private var personalIdentityPlanName: String {
        let plan = personalMembership?.plan ?? (isPersonalAccount ? session?.plan : nil)
        return plan?.lowercased() == "personal_plus" ? "Personal Plus" : "Personal"
    }
    private var isAdmin: Bool { session?.role.lowercased() == "admin" }
    private var canManageMatches: Bool { session?.canManageMatches ?? false }
    private var hasUnreadNotifications: Bool { notifications.contains { !$0.isRead } }
    private var headerPlanLine: String {
        if !currentPlanCode.isEmpty {
            return planDisplayName(for: currentPlanCode)
        }
        return session?.planDisplayName ?? (isPersonalAccount ? "Personal Free" : "Club Essentials")
    }
    private var currentUserDisplayName: String {
        let name = session?.fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty {
            return name
        }

        let firstName = session?.firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let surname = session?.surname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let composedName = [firstName, surname]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !composedName.isEmpty {
            return composedName
        }

        return session?.username ?? "Player"
    }
    private var currentUserInitials: String {
        let components = currentUserDisplayName
            .split(separator: " ")
            .map(String.init)
        let initials = components.prefix(2).compactMap { $0.first.map { String($0).uppercased() } }.joined()
        return initials.isEmpty ? "HS" : initials
    }
    private var currentUserFirstName: String {
        let firstName = session?.firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !firstName.isEmpty {
            return firstName
        }

        return currentUserDisplayName.split(separator: " ").first.map(String.init) ?? ""
    }
    private var currentUserSurname: String {
        let surname = session?.surname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !surname.isEmpty {
            return surname
        }

        let components = currentUserDisplayName.split(separator: " ").map(String.init)
        return components.count > 1 ? components.dropFirst().joined(separator: " ") : ""
    }
    private var homeActiveMatches: [MatchSummary] { Array(activeMatches.prefix(3)) }
    private var homeScheduledMatches: [MatchSummary] { Array(scheduledMatches.prefix(3)) }
    private var homeRecentMatches: [MatchSummary] {
        let visibleMatches = Array(recentMatches.lazy.filter { !$0.locked }.prefix(3))
        guard let lockedPreview = recentMatches.first(where: \.locked) else {
            return visibleMatches
        }
        return visibleMatches + [lockedPreview]
    }
    private var offlineActiveMatch: MatchDetail? {
        container.offlineMatchStore.cachedActiveMatch(session: session)
    }
    private var filteredRecentMatches: [MatchSummary] {
        let query = historySearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return recentMatches
        }

        return recentMatches.filter { match in
            let fields = [
                match.player1Name,
                match.player1Surname ?? "",
                match.player2Name,
                match.player2Surname ?? "",
                historyWinnerLine(for: match),
                historyScoreLine(for: match),
                formattedMatchDate(for: match)
            ]
            .joined(separator: " ")
            .lowercased()

            return fields.contains(query)
        }
    }
    private var settingsPlanLine: String {
        organizationSummary?.plan.flatMap { planDisplayName(for: $0) } ?? headerPlanLine
    }
    private var settingsOrganizationName: String {
        organizationSummary?.name
            ?? session?.organizationName
            ?? "Organisation"
    }
    private var helpFooterText: String {
        isPersonalAccount
            ? "We will send your message to the Hit n Score support inbox."
            : "Your message will include your club context so support can help faster."
    }
    private var appDisplayName: String {
        let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        return bundleName ?? appName ?? "Hit n Score"
    }
    private var appVersionNumber: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "Unknown"
    }
    private var appBuildNumber: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "Unknown"
    }
    private var organizationSettingsUsers: [OrganizationUser] {
        organizationSettings?.users ?? []
    }
    private var organizationSettingsCourts: [CourtSummary] {
        organizationSettings?.courts ?? []
    }
    private var currentSettingsUser: OrganizationUser? {
        let currentUsername = session?.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return organizationSettingsUsers.first { user in
            user.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == currentUsername
        }
    }
    private var availableMemberships: [UserMembership] {
        session?.availableMemberships ?? []
    }
    private var orderedMemberships: [UserMembership] {
        resolvedMemberships.sorted { lhs, rhs in
            let lhsPersonal = isPersonalMembership(lhs)
            let rhsPersonal = isPersonalMembership(rhs)
            if lhsPersonal != rhsPersonal {
                return lhsPersonal
            }
            return lhs.organizationName.localizedCaseInsensitiveCompare(rhs.organizationName) == .orderedAscending
        }
    }
    private var clubMemberships: [UserMembership] {
        orderedMemberships.filter { !isPersonalMembership($0) }
    }
    private var resolvedMemberships: [UserMembership] {
        if !availableMemberships.isEmpty {
            return availableMemberships
        }
        guard let current = session else { return [] }
        return [UserMembership(
            id: current.id,
            username: current.username,
            role: current.role,
            organizationID: current.organizationID,
            organizationName: current.organizationName,
            organizationType: current.organizationType,
            plan: current.plan,
            enabledSports: current.enabledSports,
            firstName: current.firstName,
            surname: current.surname,
            fullName: current.fullName,
            email: current.email,
            country: current.country,
            telephone: current.telephone
        )]
    }
    private var availableSportOptions: [MatchSport] {
        MatchSport.allCases
    }
    private var enabledSportIDs: Set<String> {
        Set(enabledSportsDraft.map { $0.lowercased() })
    }
    private var usesCompactBottomNavigation: Bool {
        dynamicTypeSize.isAccessibilitySize
    }
    private var availableDashboardTabs: [DashboardTab] {
        [.home, .matches, .performance, .settings, .help]
    }
    private var bottomNavigationIconSize: CGFloat {
        usesCompactBottomNavigation ? 18 : 22
    }
    private var bottomNavigationFont: Font {
        usesCompactBottomNavigation ? .system(size: 10, weight: .medium) : .caption
    }
    private var personalSettingsItems: [SettingsMenuItem] {
        var items: [SettingsMenuItem] = [.about, .profile, .subscription]
        if availableMemberships.count > 1 {
            items.append(.association)
        }
        items.append(.gameSettings)
        items.append(.helpFeedback)
        return items
    }
    private var clubSettingsPrimaryItems: [SettingsMenuItem] {
        personalSettingsItems
    }
    private var settingsMenuSections: [SettingsMenuSectionDescriptor] {
        if isPersonalAccount {
            return [
                SettingsMenuSectionDescriptor(title: "Account", items: personalSettingsItems)
            ]
        }

        var sections = [SettingsMenuSectionDescriptor(title: "Account", items: clubSettingsPrimaryItems)]
        if isAdmin {
            sections.append(SettingsMenuSectionDescriptor(title: "Club", items: [.organisation, .users, .courts, .racketSports]))
        }
        return sections
    }
    private var settingsAvailableItems: [SettingsMenuItem] {
        settingsMenuSections.flatMap(\.items)
    }
    private var selectedProfileImage: Image? {
        guard let selectedProfilePhotoData,
              let uiImage = UIImage(data: selectedProfilePhotoData) else {
            return nil
        }

        return Image(uiImage: uiImage)
    }
    private var countrySuggestions: [String] {
        let query = personalProfileDraft.country.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return [] }
        return Self.countryNames
            .filter { $0.localizedCaseInsensitiveContains(query) && $0.caseInsensitiveCompare(query) != .orderedSame }
            .prefix(6)
            .map { $0 }
    }
    private static let countryNames: [String] = Locale.Region.isoRegions
        .compactMap { Locale.current.localizedString(forRegionCode: $0.identifier) }
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: selectedTab == .settings ? 12 : 22) {
                    headerSection

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(Color.dashboardCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.dashboardBorder, lineWidth: 1)
                            )
                    }

                    tabContent
                }
                .padding(.horizontal, 18)
                .padding(.top, 0)
                .padding(.bottom, 20)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color.dashboardBackgroundStart,
                        Color.dashboardBackgroundEnd
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .safeAreaInset(edge: .bottom) {
                bottomNavigationBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $navigationTarget) { route in
                switch route.presentation {
                case .live(let openSettingsOnLoad):
                    MatchScoringView(matchID: route.id, openSettingsOnLoad: openSettingsOnLoad)
                case .historic:
                    HistoricMatchView(matchID: route.id)
                }
            }
            .navigationDestination(item: $settingsNavigationItem) { item in
                settingsDetailPage(for: item)
            }
            .navigationDestination(item: $associationClubRoute) { route in
                associationClubManagementPage(for: route.membership)
            }
            .navigationDestination(item: $clubEnquiryPlan) { plan in
                clubSubscriptionEnquiryPage(for: plan)
            }
            .navigationDestination(isPresented: $showsNotifications) {
                notificationCenterPage
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .newMatch:
                    NavigationStack {
                        StartNewMatchFlowView(
                            activeMatches: activeMatches,
                            onContextChanged: { membership in switchAssociation(to: membership) }
                        ) { result in
                            handleStartNewMatchResult(result)
                        }
                        .environmentObject(container)
                    }
                    .presentationDetents([.large])
                case .watchMatch(let code):
                    NavigationStack {
                        RemoteMatchWatchView(code: code) {
                            Task { await loadDashboard() }
                        }
                        .environmentObject(container)
                    }
                    .presentationDetents([.large])
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) { EmptyView() }
            }
            .task {
                seedHelpDefaults()
                await loadDashboard()
                await loadNotifications()
                await loadCentralProfileImage()
            }
            .task(id: selectedProfilePhotoItem) {
                await loadSelectedProfilePhoto()
            }
            .task(id: selectedTab) {
                seedHelpDefaults()
                if selectedTab == .settings {
                    normalizeSelectedSettingsMenuItem()
                    await loadOrganizationSettingsIfNeeded()
                }
            }
            .onChange(of: isOnline) { _, isOnline in
                if isOnline {
                    Task {
                        await loadDashboard()
                        await loadNotifications()
                    }
                } else if errorMessage == "Unable to fetch dashboard data." {
                    errorMessage = nil
                }
            }
            .onChange(of: dashboardNotice) { _, notice in
                guard let notice else { return }
                presentTransientNotice(notice)
                dashboardNotice = nil
            }
            .onChange(of: settingsSuccessMessage) { _, notice in
                guard let notice else { return }
                presentTransientNotice(notice)
                settingsSuccessMessage = nil
            }
            .onChange(of: feedbackSuccessMessage) { _, notice in
                guard let notice else { return }
                presentTransientNotice(notice)
                feedbackSuccessMessage = nil
            }
            .onChange(of: resetMessage) { _, notice in
                guard let notice else { return }
                presentTransientNotice(notice)
                resetMessage = nil
            }
            .refreshable { await loadDashboard() }
            .alert(item: $accountDeletionPrompt) { prompt in
                accountDeletionAlert(for: prompt)
            }
            .overlay(alignment: .bottom) {
                if let transientNotice {
                    Text(transientNotice)
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(Color.black.opacity(colorScheme == .dark ? 0.88 : 0.78))
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .accessibilityIdentifier("dashboard.transientNotice")
                }
            }
            .animation(.easeInOut(duration: 0.2), value: transientNotice)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 4) {
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 58)

                Spacer(minLength: 8)

                Button {
                    guard isOnline else { return }
                    showsNotifications = true
                } label: {
                    Image(systemName: isOnline ? (hasUnreadNotifications ? "bell.fill" : "bell") : "wifi.slash")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(
                            isOnline
                                ? (hasUnreadNotifications ? Color.yellow : Color.dashboardBrand)
                                : Color.orange
                        )
                        .frame(width: 34, height: 38)
                        .shadow(
                            color: isOnline && hasUnreadNotifications ? Color.yellow.opacity(0.9) : .clear,
                            radius: 8
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isOnline ? "Messages" : "Offline")
                .accessibilityIdentifier(isOnline ? "dashboard.notificationButton" : "dashboard.offlineIndicator")
                .disabled(!isOnline)

                accountContextSwitcher(label: nil, compact: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 0)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            homeContent
        case .matches:
            matchesContent
        case .history:
            historyContent
        case .performance:
            performanceContent
        case .settings:
            settingsContent
        case .help:
            helpContent
        }
    }

    private var homeContent: some View {
        VStack(spacing: 18) {
            dashboardSection(
                title: "Active Matches",
                systemImage: "dot.radiowaves.left.and.right"
            ) {
                activeMatchesContent(matches: homeActiveMatches)
            }

            if !isPersonalAccount {
                dashboardSection(
                    title: "Scheduled Matches",
                    systemImage: "calendar.badge.clock"
                ) {
                    scheduledMatchesContent(matches: homeScheduledMatches)
                }
            }

            dashboardSection(
                title: "Recent Matches",
                systemImage: "clock"
            ) {
                recentMatchesContent(matches: homeRecentMatches)
            }
        }
    }

    private var matchesContent: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: isPersonalAccount ? "person.fill" : "building.2.fill")
                Text(isPersonalAccount ? "Personal matches" : "\(session?.organizationName ?? "Club") matches")
                    .lineLimit(1)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.dashboardBrand)
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Match category", selection: $selectedMatchesCategory) {
                ForEach(MatchesCategory.allCases) { category in
                    Text(category.title).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .padding(6)
            .background(Color.dashboardCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityIdentifier("matches.categoryPicker")

            if selectedMatchesCategory == .history {
                historyContent
            } else if selectedMatchesCategory == .scheduled {
                if isPersonalAccount && !isPersonalPlus {
                    scheduleUpgradeCard
                } else {
                    dashboardSection(title: "Scheduled Matches", systemImage: "calendar.badge.clock") {
                        scheduledMatchesContent(matches: scheduledMatches)
                    }
                }
            } else {
                if isPersonalPlus {
                    matchWatchSection
                }
                dashboardSection(
                    title: "Current Matches",
                    subtitle: isPersonalAccount ? "Your matches currently in progress." : "All active matches recorded under this club account."
                ) {
                    activeMatchesContent(matches: activeMatches)
                }
            }
        }
    }

    private var matchWatchSection: some View {
        dashboardSection(
            title: "Watch a Match",
            systemImage: "dot.radiowaves.left.and.right",
            subtitle: "Enter the code shared by the scorer to follow a match remotely."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("ABCD2345", text: $matchWatchCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: matchWatchCode) { _, newValue in
                        let normalized = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(8))
                        if normalized != newValue {
                            matchWatchCode = normalized
                        }
                    }
                    .accessibilityLabel("Match viewing code")

                Button("Watch Match") {
                    let normalized = matchWatchCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    guard normalized.count == 8 else {
                        errorMessage = "Enter the 8-character match viewing code."
                        return
                    }
                    activeSheet = .watchMatch(normalized)
                }
                .buttonStyle(.borderedProminent)
                .disabled(matchWatchCode.count != 8 || !isOnline)

                if !viewedMatches.isEmpty {
                    Divider()
                    Text("Viewed Matches")
                        .font(.subheadline.weight(.bold))
                    ForEach(viewedMatches) { match in
                        Button {
                            guard let code = match.viewerCode, !code.isEmpty else { return }
                            activeSheet = .watchMatch(code)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(matchDisplayName(for: match))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(match.status.lowercased() == "completed" ? "Finished" : "Live")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Color.dashboardBrand)
                            }
                            .padding(12)
                            .background(Color.dashboardInnerCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var scheduleUpgradeCard: some View {
        dashboardSection(title: "Scheduled Matches", systemImage: "calendar.badge.clock") {
            VStack(spacing: 12) {
                Text("Scheduling is available with Personal Plus")
                    .font(.headline.weight(.bold))
                Text("Upgrade to prepare matches in advance and start them when you are ready.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("View Personal Plus") {
                    selectedTab = .settings
                    selectedSettingsSection = .subscription
                    settingsNavigationItem = .subscription
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var historyContent: some View {
        VStack(spacing: 18) {
            dashboardSection(
                title: "Recent Matches",
                systemImage: "clock",
                subtitle: "Search completed matches by player name, surname, or date."
            ) {
                if isOnline {
                    VStack(spacing: 14) {
                        dashboardTextField(
                            title: "Search history",
                            placeholder: "Search player or date",
                            text: $historySearch
                        )

                        recentMatchesContent(
                            matches: filteredRecentMatches,
                            emptyMessage: historySearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "No recent matches"
                                : "No completed matches match that search."
                        )
                    }
                } else {
                    offlineHistoricMatchesState
                }
            }
        }
    }

    private var performanceContent: some View {
        VStack(spacing: 18) {
            if !isPersonalAccount {
                Picker("Analytics category", selection: $selectedAnalyticsCategory) {
                    Text("Personal").tag(AnalyticsCategory.personal)
                    Text("Club").tag(AnalyticsCategory.club)
                }
                .pickerStyle(.segmented)
                .padding(6)
                .background(Color.dashboardCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            dashboardSection(
                title: selectedAnalyticsCategory == .club ? "Club Analytics" : "Personal Analytics",
                systemImage: "chart.xyaxis.line",
                subtitle: selectedAnalyticsCategory == .club
                    ? "Aggregate club use, match setup, demand and court reporting."
                    : "Your app usage and, with Personal Plus, game and player performance."
            ) {
                HStack {
                    Text("Reporting period")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Picker("Reporting period", selection: $analyticsPeriodDays) {
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                        Text("12 months").tag(365)
                        Text("All time").tag(0)
                    }
                    .pickerStyle(.menu)
                }

                analyticsExportControls

                if let analyticsExportError {
                    Text(analyticsExportError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if selectedAnalyticsCategory == .club && !isPersonalAccount {
                    clubAnalyticsContent
                } else {
                    basicAnalyticsContent

                    if personalAnalyticsIsPlus {
                        if isLoading && performanceSummary == nil {
                            HStack {
                                ProgressView()
                                Spacer()
                            }
                        } else if let performance = performanceSummary {
                            VStack(spacing: 16) {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    performanceStatCard(title: "Matches won", value: "\(performance.matchesWon)", detail: "\(performancePercentage(performance.winPercentage)) win rate")
                                    performanceStatCard(title: "Playing time", value: performanceDuration(performance.playingTimeSeconds), detail: "\(performance.matchesPlayed) matches")
                                    performanceStatCard(title: "Games won", value: "\(performance.gamesWon)", detail: "\(performancePercentage(performance.gameWinPercentage)) win rate")
                                    performanceStatCard(title: "Points won", value: "\(performance.pointsWon)", detail: "\(performancePercentage(performance.pointWinPercentage)) win rate")
                                    performanceStatCard(title: "Close games / sets", value: "\(performance.closeGamesWon)/\(performance.closeGamesPlayed)", detail: performancePercentage(performance.closeGameWinPercentage))
                                    performanceStatCard(title: "Points won on serve", value: "\(performance.servicePointsWon)", detail: "\(performancePercentage(performance.servicePointWinPercentage)) of serve points")
                                    performanceStatCard(title: "Current streak", value: "\(performance.currentWinStreak)", detail: "Best: \(performance.bestWinStreak)")
                                    performanceStatCard(title: "Points lost on serve", value: "\(performance.servicePointsLost)", detail: "From recorded actions")
                                }

                                performanceGroup(title: "Progress summaries") {
                                    performancePeriodRow(title: "This week", summary: performance.weeklySummary)
                                    Divider()
                                    performancePeriodRow(title: "This month", summary: performance.monthlySummary)
                                }

                                if !performance.monthlyImprovement.isEmpty {
                                    performanceGroup(title: "Monthly improvement") {
                                        ForEach(performance.monthlyImprovement) { item in
                                            performanceRow(
                                                title: item.sport,
                                                value: item.percentagePointChange.map { String(format: "%+.1f pts", $0) } ?? "Not enough data",
                                                detail: "\(item.currentMonthMatches) this month"
                                            )
                                        }
                                    }
                                }

                                if !performance.sports.isEmpty {
                                    performanceGroup(title: "By sport") {
                                        ForEach(performance.sports) { sport in
                                            performanceRow(
                                                title: sport.sport,
                                                value: "\(sport.won)-\(sport.lost)",
                                                detail: "\(performancePercentage(sport.winPercentage)) · \(performanceDuration(sport.playingTimeSeconds))"
                                            )
                                        }
                                    }
                                }

                                if !performance.opponents.isEmpty {
                                    performanceGroup(title: "Opponents") {
                                        ForEach(performance.opponents) { opponent in
                                            performanceRow(
                                                title: opponent.name,
                                                value: "\(opponent.won)-\(opponent.lost)",
                                                detail: "\(performancePercentage(opponent.winPercentage)) win rate"
                                            )
                                        }
                                    }
                                }

                                if !performance.scorelineWins.isEmpty {
                                    performanceGroup(title: "Winning scorelines") {
                                        ForEach(performance.scorelineWins) { scoreline in
                                            performanceRow(title: scoreline.scoreline, value: "\(scoreline.count)", detail: scoreline.count == 1 ? "win" : "wins")
                                        }
                                    }
                                }

                                if performance.unclassifiedMatchCount > 0 {
                                    Text("\(performance.unclassifiedMatchCount) match\(performance.unclassifiedMatchCount == 1 ? "" : "es") could not be assigned to your profile because the recorded player name differs from your registered name.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        } else {
                            emptyState("No completed matches are available for player reporting yet.")
                        }
                    } else {
                        upgradePerformanceCard
                    }
                }
            }
        }
        .onChange(of: analyticsPeriodDays) { _, _ in
            analyticsExportURL = nil
            Task { await loadDashboard() }
        }
    }
    private var basicAnalyticsContent: some View {
        let analytics = personalAppAnalytics
        let setup = analytics?.setupCompletion

        return VStack(spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                performanceStatCard(title: "Matches scored", value: "\(analytics?.matchesScored ?? 0)", detail: "\(analytics?.completedMatches ?? 0) completed")
                performanceStatCard(title: "Completion rate", value: performancePercentage(analytics?.completedMatchRate), detail: "Recorded matches")
                performanceStatCard(title: "Average duration", value: analytics?.averageMatchDurationSeconds.map { performanceDuration($0) } ?? "—", detail: "Completed matches")
                performanceStatCard(title: "Active days", value: "\(analytics?.activeDays ?? 0)", detail: "\(analytics?.returningUsageWeeks ?? 0) active weeks")
                performanceStatCard(title: "Setups started", value: "\(setup?.started ?? 0)", detail: "\(setup?.completed ?? 0) completed")
                performanceStatCard(title: "Setup abandonment", value: performancePercentage(setup?.abandonmentRate), detail: "\(setup?.abandoned ?? 0) abandoned")
            }

            if let sports = analytics?.matchesBySport.filter({ $0.count > 0 }), !sports.isEmpty {
                performanceGroup(title: "Scoring by sport") {
                    ForEach(sports) { sport in
                        performanceRow(
                            title: sportDisplayName(sport.sport),
                            value: "\(sport.count)",
                            detail: "matches scored"
                        )
                        if sport.id != sports.last?.id { Divider() }
                    }
                }
            }

            if !personalAnalyticsIsPlus {
                Text("Personal includes basic app-usage and setup analytics. Upgrade for player, game, serve, opponent, progress and export reporting.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var clubAnalyticsContent: some View {
        if let analytics = clubAnalytics {
            let setup = clubAppAnalytics?.setupCompletion
            VStack(spacing: 16) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    performanceStatCard(title: "Club matches", value: "\(analytics.clubMatchesScored)", detail: "All recorded club matches")
                    performanceStatCard(title: "Active setup users", value: "\(analytics.memberActivity.activeUsers)", detail: "\(analytics.memberActivity.userCount) approved club users")
                    performanceStatCard(title: "Setup adoption", value: performancePercentage(analytics.memberActivity.adoptionRate), detail: "Users who opened match setup")
                    performanceStatCard(title: "Setups started", value: "\(setup?.started ?? 0)", detail: "\(setup?.completed ?? 0) completed")
                    performanceStatCard(title: "Setup abandonment", value: performancePercentage(setup?.abandonmentRate), detail: "\(setup?.abandoned ?? 0) abandoned")
                    performanceStatCard(title: "Peak-time concentration", value: performancePercentage(analytics.peakTimeConcentration), detail: analytics.peakHours.map { String(format: "%02d:00", $0) }.joined(separator: ", "))
                    performanceStatCard(title: "Off-peak matches", value: "\(analytics.offPeakMatches)", detail: "Outside the three busiest hours")
                    performanceStatCard(title: "Simultaneous courts", value: "\(analytics.simultaneousCourtActivity)", detail: "Highest overlapping activity")
                }

                if !analytics.courtUsage.isEmpty {
                    performanceGroup(title: "Court usage") {
                        ForEach(analytics.courtUsage) { court in
                            performanceRow(
                                title: court.court,
                                value: "\(court.matches)",
                                detail: String(format: "%.1f court hours", Double(court.durationSeconds) / 3600)
                            )
                            if court.id != analytics.courtUsage.last?.id { Divider() }
                        }
                    }
                }

                Text(analytics.premiumDigest)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if isLoading {
            ProgressView()
        } else {
            emptyState("No club analytics are available yet.")
        }
    }

    @ViewBuilder
    private var analyticsExportControls: some View {
        let canExport = selectedAnalyticsCategory == .club || personalAnalyticsIsPlus
        if canExport {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button {
                        Task { await prepareAnalyticsExport() }
                    } label: {
                        if isExportingAnalytics {
                            ProgressView()
                        } else {
                            Label("Prepare CSV report", systemImage: "arrow.down.doc")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isExportingAnalytics)

                    if let analyticsExportURL {
                        ShareLink(item: analyticsExportURL) {
                            Label("Share CSV", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if selectedAnalyticsCategory == .club {
                    Text("Club reports contain aggregate club, court and match-use data only. They do not include player names, member names, usernames or email addresses.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var upgradePerformanceCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.dashboardBrand)
            Text("Performance is included with Personal Plus")
                .font(.headline.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Upgrade to see trends, opponent records, serving results, streaks and weekly or monthly progress.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("View Personal Plus") {
                selectedTab = .settings
                selectedSettingsSection = .subscription
                settingsNavigationItem = .subscription
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func performanceStatCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.heavy))
                .foregroundStyle(Color.dashboardBrand)
                .minimumScaleFactor(0.75)
            Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func performanceGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline.weight(.bold))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func performancePeriodRow(title: String, summary: PerformancePeriodSummary) -> some View {
        performanceRow(
            title: title,
            value: "\(summary.matchesWon)-\(summary.matchesLost)",
            detail: "\(summary.matchesPlayed) matches · \(performanceDuration(summary.playingTimeSeconds)) · \(performancePercentage(summary.winPercentage))"
        )
    }

    private func performanceRow(title: String, value: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.dashboardBrand)
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func performancePercentage(_ value: Double?) -> String {
        value.map { String(format: "%.1f%%", $0) } ?? "—"
    }

    private func performanceDuration(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let hours = minutes / 60
        let remainder = minutes % 60
        return hours > 0 ? "\(hours)h \(remainder)m" : "\(minutes)m"
    }

    private var settingsContent: some View {
        VStack(spacing: 6) {
            if isLoadingSettings && organizationSettings == nil {
                HStack {
                    ProgressView()
                    Spacer()
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.dashboardCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.dashboardBorder, lineWidth: 1)
                )
            } else {
                VStack(spacing: 12) {
                    if let settingsErrorMessage {
                        dashboardInlineError(settingsErrorMessage)
                    }

                    if isPersonalAccount {
                        personalSettingsContent
                    } else {
                        clubSettingsContent
                    }
                }
            }
        }
    }

    private var personalSettingsContent: some View {
        VStack(spacing: 6) {
            personalSettingsHeader
            settingsMenuSectionsList
        }
    }

    private var clubSettingsContent: some View {
        VStack(spacing: 6) {
            personalSettingsHeader

            if !isAdmin {
                Text("You are in view-only mode. Only organisation admins can save changes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            settingsMenuSectionsList
        }
    }

    private var personalSettingsHeader: some View {
        VStack(spacing: 8) {
            PhotosPicker(selection: $selectedProfilePhotoItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    profileAvatarView(size: 92)

                    Circle()
                        .fill(Color.dashboardBrand)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "pencil")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(profileImageBusy)

            if profileImageBusy {
                ProgressView("Compressing and uploading…")
                    .font(.caption)
            } else if profileImageURL != nil || selectedProfilePhotoData != nil {
                Button("Remove photo", role: .destructive) {
                    Task { await removeCentralProfileImage() }
                }
                .font(.caption.weight(.semibold))
            }

            Text(personalIdentityUsername)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text(personalIdentityPlanName)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.dashboardBrand)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.dashboardBrand.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            colorScheme == .dark
                ? Color.dashboardInnerCardBackground.opacity(0.05)
                : Color.dashboardInnerCardBackground
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var settingsMenuSectionsList: some View {
        VStack(spacing: 14) {
            ForEach(settingsMenuSections) { section in
                settingsMenuSection(section)
            }

            Text("Signed in as \(personalIdentityUsername)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)

            signOutMenuSection
        }
    }

    private func settingsMenuSection(_ section: SettingsMenuSectionDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = section.title {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
            }

            VStack(spacing: 0) {
                ForEach(Array(section.items.enumerated()), id: \.element) { index, item in
                    settingsMenuRow(item, isLast: index == section.items.count - 1)
                }
            }
            .background(Color.dashboardInnerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.dashboardBorder, lineWidth: 1)
            )
        }
    }

    private func settingsMenuRow(_ item: SettingsMenuItem, isLast: Bool) -> some View {
        let isUnavailable = item == .reporting
        return Button {
            guard !isUnavailable else { return }
            selectedSettingsSection = item.section
            settingsNavigationItem = item
        } label: {
            HStack(spacing: 12) {
                Text(item.title)
                    .font(.body)
                    .foregroundStyle(isUnavailable ? Color.secondary : Color.primary)

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.dashboardBrand)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle()
                        .fill(Color.dashboardBorder.opacity(0.9))
                        .frame(height: 1)
                        .padding(.leading, 16)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isUnavailable)
        .opacity(isUnavailable ? 0.45 : 1)
        .accessibilityIdentifier("settings.menu.\(item.rawValue)")
    }

    private var signOutMenuSection: some View {
        VStack(spacing: 0) {
            Button {
                container.logout()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.dashboardCompletedStatus)
                        .frame(width: 24)

                    Text("Sign Out")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dashboardCompletedStatus)

                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.signOutButton")
        }
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.dashboardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func settingsDetailContent(for section: SettingsSection) -> some View {
        switch section {
        case .subscription:
            subscriptionSettingsCard
        case .profile:
            profileSettingsCard
        case .association:
            associationSettingsCard
        case .racketSports:
            if isPersonalAccount {
                readOnlySportAccessCard
            } else {
                VStack(spacing: 12) {
                    sportSetupCard
                    gameSettingsCard
                }
            }
        case .gameSettings:
            gameSettingsCard
        case .about:
            aboutSettingsCard
        case .helpFeedback:
            VStack(spacing: 12) {
                feedbackForm
                privacyComplianceLinkCard
            }
        case .reporting:
            reportingPlaceholderCard
        case .organisation:
            organizationOverviewCard
        case .orgSettings:
            VStack(spacing: 12) {
                organizationProfileCard
                organizationLocationCard
            }
        case .users:
            organizationUsersCard
        case .courts:
            organizationCourtsCard
        }
    }

    private func settingsDetailPage(for item: SettingsMenuItem) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                if let settingsErrorMessage {
                    dashboardInlineError(settingsErrorMessage)
                }

                settingsDetailContent(for: item.section)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.dashboardBackgroundStart,
                    Color.dashboardBackgroundEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    settingsNavigationItem = nil
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.dashboardBrand.opacity(0.12))
                    .foregroundStyle(Color.dashboardBrand)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func associationClubManagementPage(for membership: UserMembership) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Manage club")
                        .font(.title3.weight(.bold))
                    Text(membership.role.lowercased() == "admin"
                         ? "Profile, people, courts and match defaults for \(membership.organizationName)."
                         : "View the club profile and courts for \(membership.organizationName).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    clubManagementLink(title: "Profile", icon: "building.2", item: .orgSettings)
                    if membership.role.lowercased() == "admin" {
                        clubManagementLink(title: "Users", icon: "person.2.fill", item: .users)
                    }
                    clubManagementLink(title: "Courts", icon: "sportscourt.fill", item: .courts)
                    if membership.role.lowercased() == "admin" {
                        clubManagementLink(title: "Club Settings", icon: "slider.horizontal.3", item: .racketSports)
                    }
                }

                if isLoadingSettings && organizationSettings == nil {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading club details…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.dashboardInnerCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else {
                    organizationOverviewCard
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [Color.dashboardBackgroundStart, Color.dashboardBackgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle(membership.organizationName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: membership.organizationID) {
            await loadOrganizationSettingsIfNeeded(force: true)
        }
    }

    private func clubManagementLink(title: String, icon: String, item: SettingsMenuItem) -> some View {
        NavigationLink {
            associationClubDetailPage(title: title, item: item)
        } label: {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(Color.dashboardBrand)
                    .frame(width: 44, height: 44)
                    .background(Color.dashboardBrand.opacity(0.12))
                    .clipShape(Circle())

                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 104)
            .padding(.horizontal, 10)
            .background(Color.dashboardInnerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.dashboardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.clubManagement.\(item.rawValue)")
    }

    private func associationClubDetailPage(title: String, item: SettingsMenuItem) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                if let settingsErrorMessage {
                    dashboardInlineError(settingsErrorMessage)
                }
                settingsDetailContent(for: item.section)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [Color.dashboardBackgroundStart, Color.dashboardBackgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var subscriptionSettingsCard: some View {
        let freeHistoryLimit = organizationSummary?.availablePlanEntitlements["personal_free"]?.historyLimit
            ?? organizationSettings?.organization.availablePlanEntitlements["personal_free"]?.historyLimit
            ?? 3
        let plusHistoryLimit = organizationSummary?.availablePlanEntitlements["personal_plus"]?.historyLimit
            ?? organizationSettings?.organization.availablePlanEntitlements["personal_plus"]?.historyLimit
            ?? 100
        let personalPlan = (personalMembership?.plan ?? (isPersonalAccount ? session?.plan : nil) ?? "personal_free").lowercased()
        let personalIsPlus = personalPlan == "personal_plus"
        let planCards: [(title: String, subtitle: String, isCurrent: Bool, enquiryPlan: ClubSubscriptionPlan?)] = [
            ("Personal", "Core scoring with your latest \(freeHistoryLimit) completed matches.", !personalIsPlus, nil),
            ("Personal Plus", "\(plusHistoryLimit) completed matches plus performance, opponent, serving, streak and progress insights.", personalIsPlus, nil)
        ]

        return VStack(alignment: .leading, spacing: 12) {
            Text("Subscription")
                .font(.headline.weight(.semibold))

            ForEach(planCards, id: \.title) { card in
                if card.title == "Personal Plus" {
                    personalPlusSubscriptionOptionCard(
                        subtitle: card.subtitle,
                        isCurrent: card.isCurrent
                    )

                    if isPersonalPlusOptionsExpanded {
                        personalPlusPurchaseControls
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                )
                            )
                    }
                } else {
                    subscriptionOptionCard(
                        title: card.title,
                        subtitle: card.subtitle,
                        isCurrent: card.isCurrent,
                        enquiryPlan: card.enquiryPlan
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .task {
            await container.purchaseService.loadProducts(force: true)
            await container.purchaseService.refreshCurrentEntitlements()
        }
        .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
        .onChange(of: showsManageSubscriptions) { _, isPresented in
            guard !isPresented else { return }
            Task {
                await container.purchaseService.refreshCurrentEntitlements()
                // Apple cancellation normally changes renewal intent first and
                // leaves access active until the paid period expires. Reload
                // the server-authoritative plan whenever the management sheet
                // closes so an expiry or revocation is reflected immediately.
                await loadDashboard()
            }
        }
        .onDisappear {
            personalPlusCollapseTask?.cancel()
            personalPlusCollapseTask = nil
        }
    }

    @ViewBuilder
    private var personalPlusPurchaseControls: some View {
        let purchaseService = container.purchaseService

        VStack(alignment: .leading, spacing: 12) {
            if purchaseService.isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading App Store prices…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !purchaseService.isLoading,
               !purchaseService.canRunLocalPurchases,
               !isPersonalPlus {
                dashboardInlineError(
                    "Personal Plus purchasing is disabled by the Hit n Score server. "
                    + "Refresh after the Sandbox purchasing deployment is complete."
                )

                Button("Refresh Purchase Status") {
                    Task {
                        await purchaseService.loadProducts(force: true)
                        openPersonalPlusOptions()
                    }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
            }

            if purchaseService.canRunLocalPurchases && !isPersonalPlus {
                Text("Choose Personal Plus")
                    .font(.subheadline.weight(.bold))

                ForEach(purchaseService.products, id: \.id) { product in
                    Button {
                        Task {
                            await purchaseService.purchase(product)
                            if purchaseService.errorMessage == nil {
                                await loadDashboard()
                            }
                            openPersonalPlusOptions()
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(purchaseService.planName(for: product))
                                    .font(.subheadline.weight(.bold))
                                Text(purchaseService.planDetail(for: product))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            if purchaseService.purchasingProductID == product.id {
                                ProgressView()
                            } else {
                                Text(product.displayPrice)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.dashboardBrand)
                            }
                        }
                        .padding(14)
                        .background(Color.dashboardInputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.dashboardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(purchaseService.purchasingProductID != nil)
                    .accessibilityIdentifier("settings.subscription.\(purchaseService.planName(for: product).lowercased()).purchaseButton")
                }

                Text(
                    purchaseService.purchasesEnabled
                        ? "Apple verifies payment and Hit n Score verifies the signed transaction before Personal Plus is activated."
                        : "Local StoreKit testing only — server purchasing is currently disabled and test purchases do not change your account plan."
                )
                    .font(.caption)
                    .foregroundStyle(
                        purchaseService.purchasesEnabled ? Color.secondary : Color.orange
                    )
            }

            if let statusMessage = purchaseService.statusMessage {
                dashboardInlineSuccess(statusMessage)
            }

            if let purchaseError = purchaseService.errorMessage {
                dashboardInlineError(purchaseError)
            }

            HStack(spacing: 10) {
                if purchaseService.canRunLocalPurchases {
                    Button {
                        Task {
                            await purchaseService.restorePurchases()
                            if purchaseService.errorMessage == nil {
                                await loadDashboard()
                            }
                        }
                    } label: {
                        Text("Restore Purchases")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(purchaseService.purchasingProductID != nil)
                }

                if purchaseService.canRunLocalPurchases || isPersonalPlus || !purchaseService.activeProductIDs.isEmpty {
                    Button {
                        showsManageSubscriptions = true
                    } label: {
                        Text("Manage Subscription")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func clubSubscriptionEnquiryPage(for plan: ClubSubscriptionPlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let clubEnquirySuccessMessage {
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(.green)

                        Text("Thank you for your enquiry")
                            .font(.title2.weight(.bold))

                        Text(clubEnquirySuccessMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button("Return to Subscriptions") {
                            clubEnquiryPlan = nil
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color.dashboardBrand)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.dashboardInnerCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(plan.displayName)
                            .font(.title2.weight(.bold))

                        Text("Tell us about the club you would like to register. Your signed-in account details will be included automatically, and our team will contact you about the next steps.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        settingsValueRow(title: "Contact", value: currentUserDisplayName)
                        settingsValueRow(title: "Username", value: session?.email ?? session?.username ?? "")

                        dashboardTextField(
                            title: "Club Name",
                            placeholder: "Club name",
                            text: $clubEnquiryDraft.clubName,
                            accessibilityIdentifier: "settings.clubEnquiry.clubNameField"
                        )
                        dashboardTextField(
                            title: "Club Address",
                            placeholder: "Address",
                            text: $clubEnquiryDraft.clubAddress,
                            accessibilityIdentifier: "settings.clubEnquiry.addressField"
                        )
                        dashboardTextField(
                            title: "Postcode",
                            placeholder: "Postcode",
                            text: $clubEnquiryDraft.clubPostcode,
                            accessibilityIdentifier: "settings.clubEnquiry.postcodeField"
                        )
                        dashboardTextField(
                            title: "Club Email Address",
                            placeholder: "club@example.com",
                            text: $clubEnquiryDraft.clubEmail,
                            keyboardType: .emailAddress,
                            accessibilityIdentifier: "settings.clubEnquiry.emailField"
                        )
                        dashboardTextField(
                            title: "Website",
                            placeholder: "https://www.example.com",
                            text: $clubEnquiryDraft.clubWebsite,
                            keyboardType: .URL,
                            accessibilityIdentifier: "settings.clubEnquiry.websiteField"
                        )
                        dashboardTextField(
                            title: "Club Telephone",
                            placeholder: "Telephone number",
                            text: $clubEnquiryDraft.clubTelephone,
                            keyboardType: .phonePad,
                            accessibilityIdentifier: "settings.clubEnquiry.telephoneField"
                        )

                        if let clubEnquiryErrorMessage {
                            dashboardInlineError(clubEnquiryErrorMessage)
                        }

                        Button(isSubmittingClubEnquiry ? "Sending..." : "Send Club Enquiry") {
                            submitClubSubscriptionEnquiry(plan)
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.dashboardBrand)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .buttonStyle(.plain)
                        .disabled(isSubmittingClubEnquiry || !isOnline)
                        .opacity(isSubmittingClubEnquiry || !isOnline ? 0.7 : 1)
                        .accessibilityIdentifier("settings.clubEnquiry.submitButton")

                        if !isOnline {
                            dashboardInlineError("An internet connection is required to send a club enquiry.")
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.dashboardInnerCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            .padding(18)
        }
        .background(
            LinearGradient(
                colors: [Color.dashboardBackgroundStart, Color.dashboardBackgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Club Enquiry")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var profileSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile")
                .font(.headline.weight(.semibold))

            Text("Update the account details used for sign-in and player identity. Changing the email address updates your username and signs you back out so you can validate the new login.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                dashboardTextField(title: "First Name", placeholder: "First name", text: $personalProfileDraft.firstName, accessibilityIdentifier: "settings.profile.firstNameField")
                dashboardTextField(title: "Surname", placeholder: "Surname", text: $personalProfileDraft.surname, accessibilityIdentifier: "settings.profile.surnameField")
                dashboardTextField(title: "Email", placeholder: "you@example.com", text: $personalProfileDraft.email, keyboardType: .emailAddress, accessibilityIdentifier: "settings.profile.emailField")
                dashboardTextField(title: "Telephone", placeholder: "Telephone", text: $personalProfileDraft.telephone, keyboardType: .phonePad, accessibilityIdentifier: "settings.profile.telephoneField")
                dashboardTextField(title: "Country of Origin", placeholder: "Country", text: $personalProfileDraft.country, accessibilityIdentifier: "settings.profile.countryField")

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Birth Month (optional)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Picker("Birth Month", selection: $personalProfileDraft.birthMonth) {
                            Text("Not set").tag(Int?.none)
                            ForEach(1...12, id: \.self) { month in
                                Text(DateFormatter().monthSymbols[month - 1]).tag(Int?.some(month))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, 10)
                        .background(Color.dashboardInputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Birth Year (optional)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Picker("Birth Year", selection: $personalProfileDraft.birthYear) {
                            Text("Not set").tag(Int?.none)
                            ForEach(Array((1900...Calendar.current.component(.year, from: Date())).reversed()), id: \.self) { year in
                                Text(String(year)).tag(Int?.some(year))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, 10)
                        .background(Color.dashboardInputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .disabled(!isEditingPersonalProfile)
            .opacity(isEditingPersonalProfile ? 1 : 0.78)

            if isEditingPersonalProfile && !countrySuggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(countrySuggestions, id: \.self) { country in
                        Button {
                            personalProfileDraft.country = country
                        } label: {
                            HStack {
                                Text(country)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        if country != countrySuggestions.last { Divider() }
                    }
                }
                .background(Color.dashboardInputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.dashboardBorder, lineWidth: 1))
            }

            Button(currentSettingsButtonTitle(for: "profile-save", defaultTitle: isEditingPersonalProfile ? "Save" : "Edit")) {
                if isEditingPersonalProfile {
                    savePersonalProfile()
                } else {
                    isEditingPersonalProfile = true
                }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.dashboardBrand)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)
            .disabled(savingSettingsKey != nil)
            .opacity(savingSettingsKey != nil ? 0.7 : 1)
            .accessibilityIdentifier("settings.profile.saveButton")

            if container.sessionStore.canUseBiometricUnlock {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(container.sessionStore.biometricDisplayName) Login")
                        .font(.subheadline.weight(.semibold))

                    Toggle(
                        isOn: Binding(
                            get: { container.sessionStore.biometricUnlockEnabled },
                            set: { isEnabled in
                                updateBiometricUnlockPreference(isEnabled)
                            }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use \(container.sessionStore.biometricDisplayName)")
                                .font(.subheadline.weight(.semibold))
                            Text("Unlock the saved app session on this device with \(container.sessionStore.biometricDisplayName).")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: Color.dashboardBrand))
                    .disabled(isUpdatingBiometricUnlock)
                    .accessibilityIdentifier("settings.profile.biometricToggle")

                    if isUpdatingBiometricUnlock {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(.top, 8)
            }

            Button(isRequestingPasswordReset ? "Sending..." : "Password Reset") {
                resetEmail = personalProfileDraft.email.isEmpty ? (session?.email ?? resetEmail) : personalProfileDraft.email
                requestPasswordReset()
            }
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.dashboardBrand.opacity(0.9))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .buttonStyle(.plain)
            .disabled(isRequestingPasswordReset || personalProfileDraft.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity((isRequestingPasswordReset || personalProfileDraft.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.7 : 1)
            .accessibilityIdentifier("settings.profile.passwordResetButton")

            if isPersonalAccount {
                Button {
                    accountDeletionPrompt = .first
                } label: {
                    HStack {
                        if isDeletingAccount {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "trash")
                        }
                        Text(isDeletingAccount ? "Deleting Account…" : "Delete Account")
                            .font(.subheadline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isDeletingAccount || !isOnline)
                .opacity(isDeletingAccount || !isOnline ? 0.65 : 1)
                .accessibilityIdentifier("settings.profile.deleteAccountButton")

                if !isOnline {
                    Text("Connect to the internet to delete your account permanently.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let resetErrorMessage {
                dashboardInlineError(resetErrorMessage)
            }

            if let biometricMessage = container.sessionStore.biometricErrorMessage {
                dashboardInlineError(biometricMessage)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var associationSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if clubMemberships.isEmpty {
                Label("No club associations", systemImage: "building.2")
                    .font(.headline.weight(.semibold))

                Text("No clubs are linked to this account yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Your clubs")
                    .font(.headline.weight(.semibold))

                Text("Open a club to view its profile and, where your role allows, manage users, courts and club settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(clubMemberships) { membership in
                    associationMembershipRow(membership)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var readOnlySportAccessCard: some View {
        return VStack(alignment: .leading, spacing: 12) {
            Text("Racket Sports")
                .font(.headline.weight(.semibold))

            Text("These sports are available on your account.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(availableSportOptions.filter { enabledSportIDs.contains($0.rawValue) }) { sport in
                    settingsSportBadgeRow(for: sport)
                }
            }

            Text("Sport access for personal accounts is managed by your plan or by the admin portal.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var gameSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Game Settings")
                .font(.headline.weight(.semibold))

            Text("Personal Racket Sports")
                .font(.subheadline.weight(.bold))

            Text("Choose which available sports you want to see when scoring through your Personal account.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(availableSportOptions) { sport in
                sportAccessRow(for: sport)
            }

            Button(currentSettingsButtonTitle(for: "sports-save", defaultTitle: "Save Personal Sport Access")) {
                saveOrganizationEnabledSports()
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.dashboardBrand)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .buttonStyle(.plain)
            .disabled(savingSettingsKey != nil)
            .opacity(savingSettingsKey != nil ? 0.7 : 1)
            .accessibilityIdentifier("settings.gameSettings.savePersonalSports")

            Divider()
                .padding(.vertical, 4)

            Text("Choose which sports preselect their timed warm-up and break option when you create a match. When a default is off, you can still switch the timer on for an individual match.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(availableSportOptions.filter { $0.isImplementedToday && enabledSportIDs.contains($0.rawValue) }) { sport in
                Toggle(isOn: timedBreakDefaultBinding(for: sport)) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(sport.displayName)
                            .font(.subheadline.weight(.semibold))
                        Text("Timer default \((timedBreakDefaultsDraft[sport.rawValue] ?? false) ? "on" : "off")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Color.dashboardBrand)
                .disabled(savingSettingsKey != nil)
                .accessibilityIdentifier("settings.gameSettings.\(sport.rawValue).timerDefault")
            }

            Button(currentSettingsButtonTitle(for: "timer-defaults-save", defaultTitle: "Save Timer Defaults")) {
                saveTimedBreakDefaults()
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.dashboardBrand)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .buttonStyle(.plain)
            .disabled(savingSettingsKey != nil)
            .opacity(savingSettingsKey != nil ? 0.7 : 1)
            .accessibilityIdentifier("settings.gameSettings.saveTimerDefaults")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .task(id: personalProfileOrganizationID) {
            guard let organizationID = personalProfileOrganizationID else { return }
            do {
                let settings = try await container.apiClient.getOrganizationSettings(organizationID: organizationID)
                await MainActor.run {
                    enabledSportsDraft = settings.organization.enabledSports
                    timedBreakDefaultsDraft = settings.organization.timedBreakDefaults
                }
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to load Personal game settings."
                }
            }
        }
    }

    private func timedBreakDefaultBinding(for sport: MatchSport) -> Binding<Bool> {
        Binding(
            get: { timedBreakDefaultsDraft[sport.rawValue] ?? false },
            set: { timedBreakDefaultsDraft[sport.rawValue] = $0 }
        )
    }

    private var aboutSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline.weight(.semibold))

            settingsValueRow(title: "App", value: appDisplayName)
            settingsValueRow(title: "Version", value: appVersionNumber)
            settingsValueRow(title: "Build", value: appBuildNumber)
            settingsValueRow(title: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "rcktScore.RcktScoreMobile")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var reportingPlaceholderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reporting")
                .font(.headline.weight(.semibold))

            Text("Reporting views are being prepared for this plan tier. This section will surface downloadable summaries and period views as that work lands.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var organizationOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Organisation")
                .font(.headline.weight(.semibold))

            settingsValueRow(title: "Name", value: settingsOrganizationName)
            settingsValueRow(title: "Plan", value: settingsPlanLine)
            settingsValueRow(title: "Role", value: session?.role.replacingOccurrences(of: "_", with: " ").capitalized ?? "User")
            settingsValueRow(title: "Contact", value: organizationDetailsDraft.organizationContact)
            settingsValueRow(title: "Email", value: organizationDetailsDraft.organizationEmail)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var organizationProfileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Organisation Profile")
                .font(.headline.weight(.semibold))

            dashboardTextField(
                title: "Club Name",
                placeholder: "Club name",
                text: $organizationDetailsDraft.organizationName,
                accessibilityIdentifier: "settings.organization.nameField"
            )
            .disabled(!isAdmin)

            dashboardTextField(
                title: "Primary Contact",
                placeholder: "Primary contact",
                text: $organizationDetailsDraft.organizationContact,
                accessibilityIdentifier: "settings.organization.contactField"
            )
            .disabled(!isAdmin)

            dashboardTextField(
                title: "Telephone",
                placeholder: "Telephone",
                text: $organizationDetailsDraft.organizationTelephone,
                keyboardType: .phonePad,
                accessibilityIdentifier: "settings.organization.telephoneField"
            )
            .disabled(!isAdmin)

            dashboardTextField(
                title: "Email",
                placeholder: "club@example.com",
                text: $organizationDetailsDraft.organizationEmail,
                keyboardType: .emailAddress,
                accessibilityIdentifier: "settings.organization.emailField"
            )
            .disabled(!isAdmin)

            dashboardTextField(
                title: "Website",
                placeholder: "https://example.com",
                text: $organizationDetailsDraft.organizationWebAddress,
                keyboardType: .URL,
                accessibilityIdentifier: "settings.organization.websiteField"
            )
            .disabled(!isAdmin)

            Button(currentSettingsButtonTitle(for: "organization-save", defaultTitle: "Save Organisation")) {
                saveOrganizationDetails()
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.dashboardBrand)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .buttonStyle(.plain)
            .disabled(!isAdmin || savingSettingsKey != nil)
            .opacity((!isAdmin || savingSettingsKey != nil) ? 0.7 : 1)
            .accessibilityIdentifier("settings.organization.saveButton")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var organizationLocationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Location")
                .font(.headline.weight(.semibold))

            dashboardTextField(
                title: "Address",
                placeholder: "Address",
                text: $organizationDetailsDraft.organizationAddress,
                accessibilityIdentifier: "settings.location.addressField"
            )
            .disabled(!isAdmin)

            dashboardTextField(
                title: "Postcode",
                placeholder: "Postcode",
                text: $organizationDetailsDraft.organizationPostcode,
                accessibilityIdentifier: "settings.location.postcodeField"
            )
            .disabled(!isAdmin)

            Text("This is the club address shown with the organisation profile.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(currentSettingsButtonTitle(for: "organization-save", defaultTitle: "Save Location")) {
                saveOrganizationDetails()
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.dashboardBrand)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .buttonStyle(.plain)
            .disabled(!isAdmin || savingSettingsKey != nil)
            .opacity((!isAdmin || savingSettingsKey != nil) ? 0.7 : 1)
            .accessibilityIdentifier("settings.location.saveButton")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var organizationUsersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Organisation Users")
                .font(.headline.weight(.semibold))

            VStack(spacing: 12) {
                dashboardTextField(
                    title: "First Name",
                    placeholder: "First name",
                    text: $newOrganizationUserDraft.firstName,
                    accessibilityIdentifier: "settings.users.new.firstNameField"
                )
                .disabled(!isAdmin)

                dashboardTextField(
                    title: "Surname",
                    placeholder: "Surname",
                    text: $newOrganizationUserDraft.surname,
                    accessibilityIdentifier: "settings.users.new.surnameField"
                )
                .disabled(!isAdmin)

                dashboardTextField(
                    title: "Email Address",
                    placeholder: "user@club.com",
                    text: $newOrganizationUserDraft.username,
                    keyboardType: .emailAddress,
                    accessibilityIdentifier: "settings.users.new.emailField"
                )
                .disabled(!isAdmin)

                Text("HitnScore creates or retains this person's Personal account, adds this club as an association, and emails any required secure invitation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                settingsRolePicker(selection: $newOrganizationUserDraft.role, accessibilityIdentifier: "settings.users.new.rolePicker")
                    .disabled(!isAdmin)

                Button(currentSettingsButtonTitle(for: "user-create", defaultTitle: "Add User")) {
                    createOrganizationUser()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.dashboardBrand)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(!isAdmin || savingSettingsKey != nil)
                .opacity((!isAdmin || savingSettingsKey != nil) ? 0.7 : 1)
                .accessibilityIdentifier("settings.users.new.addButton")
            }

            if organizationSettingsUsers.isEmpty {
                emptyState("No organisation users yet.")
            } else {
                ForEach(organizationSettingsUsers) { user in
                    organizationUserRow(user)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var organizationCourtsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Courts")
                .font(.headline.weight(.semibold))

            VStack(spacing: 12) {
                dashboardTextField(
                    title: "Court Name",
                    placeholder: "Court 1",
                    text: $newCourtDraft.courtName,
                    accessibilityIdentifier: "settings.courts.new.nameField"
                )
                .disabled(!isAdmin)

                dashboardTextField(
                    title: "Court Alias",
                    placeholder: "Show court name",
                    text: $newCourtDraft.courtAlias,
                    accessibilityIdentifier: "settings.courts.new.aliasField"
                )
                .disabled(!isAdmin)

                Button(currentSettingsButtonTitle(for: "court-create", defaultTitle: "Add Court")) {
                    createCourt()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.dashboardBrand)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(!isAdmin || savingSettingsKey != nil)
                .opacity((!isAdmin || savingSettingsKey != nil) ? 0.7 : 1)
                .accessibilityIdentifier("settings.courts.new.addButton")
            }

            if organizationSettingsCourts.isEmpty {
                emptyState("No courts available yet.")
            } else {
                ForEach(organizationSettingsCourts) { court in
                    organizationCourtRow(court)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var sportSetupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Racket Sports")
                .font(.headline.weight(.semibold))

            Text("Choose which racket sports users of \(settingsOrganizationName) can see when they start a match.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(availableSportOptions) { sport in
                sportAccessRow(for: sport)
            }

            Text("Future sports are shown for reference and cannot be enabled until their scoring flow is available in the iOS app.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(currentSettingsButtonTitle(for: "sports-save", defaultTitle: "Save Sport Access")) {
                saveOrganizationEnabledSports()
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.dashboardBrand)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .buttonStyle(.plain)
            .disabled(!isAdmin || savingSettingsKey != nil)
            .opacity((!isAdmin || savingSettingsKey != nil) ? 0.7 : 1)
            .accessibilityIdentifier("settings.sports.saveButton")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func sportAccessRow(for sport: MatchSport) -> some View {
        Toggle(isOn: sportEnabledBinding(for: sport)) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.dashboardBrand.opacity(0.12))
                        .frame(width: 40, height: 40)

                    racketSportGlyph(for: sport, isAvailable: sport.isImplementedToday)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(sport.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(sport.isImplementedToday ? "Live in the current app" : "Coming soon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 10)

                Text(sport.isImplementedToday ? "Ready" : "Future")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(sport.isImplementedToday ? Color.dashboardBrand : Color.dashboardAccentPink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        (sport.isImplementedToday ? Color.dashboardBrand : Color.dashboardAccentPink)
                            .opacity(0.12)
                    )
                    .clipShape(Capsule())
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: Color.dashboardBrand))
        .disabled((!isPersonalAccount && !isAdmin) || !sport.isImplementedToday || savingSettingsKey != nil)
        .opacity(sport.isImplementedToday ? 1 : 0.72)
        .accessibilityIdentifier("settings.sports.toggle.\(sport.rawValue)")
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.dashboardInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.dashboardBorder, lineWidth: 1)
        )
    }

    private func organizationUserRow(_ user: OrganizationUser) -> some View {
        let binding = Binding<OrganizationUserDraft>(
            get: { organizationUserDrafts[user.id] ?? OrganizationUserDraft(user: user) },
            set: { organizationUserDrafts[user.id] = $0 }
        )

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(userDisplayName(user))
                        .font(.subheadline.weight(.semibold))
                    Text(user.username)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    settingsBadge(title: user.role.capitalized)
                    Text(user.status.capitalized)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            dashboardTextField(title: "First Name", placeholder: "First name", text: binding.firstName, accessibilityIdentifier: "settings.users.\(user.id).firstNameField")
                .disabled(!isAdmin)
            dashboardTextField(title: "Surname", placeholder: "Surname", text: binding.surname, accessibilityIdentifier: "settings.users.\(user.id).surnameField")
                .disabled(!isAdmin)
            dashboardTextField(title: "Email", placeholder: "Email", text: binding.username, keyboardType: .emailAddress, accessibilityIdentifier: "settings.users.\(user.id).emailField")
                .disabled(!isAdmin)

            Button(currentSettingsButtonTitle(for: "user-password-\(user.id)", defaultTitle: "Send Password Reset")) {
                sendOrganizationUserPasswordReset(user)
            }
            .buttonStyle(.bordered)
            .disabled(!isAdmin || savingSettingsKey != nil)

            settingsRolePicker(selection: binding.role, accessibilityIdentifier: "settings.users.\(user.id).rolePicker")
                .disabled(!isAdmin)

            HStack(spacing: 10) {
                Button(currentSettingsButtonTitle(for: "user-save-\(user.id)", defaultTitle: "Save")) {
                    updateOrganizationUser(user)
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.dashboardBrand)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(!isAdmin || savingSettingsKey != nil)
                .opacity((!isAdmin || savingSettingsKey != nil) ? 0.7 : 1)
                .accessibilityIdentifier("settings.users.\(user.id).saveButton")

                Button(currentSettingsButtonTitle(for: "user-delete-\(user.id)", defaultTitle: "Delete")) {
                    deleteOrganizationUser(user)
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.12))
                .foregroundStyle(.red)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(!isAdmin || savingSettingsKey != nil)
                .opacity((!isAdmin || savingSettingsKey != nil) ? 0.7 : 1)
                .accessibilityIdentifier("settings.users.\(user.id).deleteButton")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.dashboardBorder, lineWidth: 1)
        )
    }

    private func organizationCourtRow(_ court: CourtSummary) -> some View {
        let binding = Binding<CourtDraft>(
            get: { courtDrafts[court.id] ?? CourtDraft(court: court) },
            set: { courtDrafts[court.id] = $0 }
        )

        return VStack(alignment: .leading, spacing: 12) {
            if let displayCode = court.displayCode, !displayCode.isEmpty {
                HStack {
                    Text("Display Code")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(displayCode)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.dashboardBrand)
                }
            }

            dashboardTextField(title: "Court Name", placeholder: "Court", text: binding.courtName, accessibilityIdentifier: "settings.courts.\(court.id).nameField")
                .disabled(!isAdmin)
            dashboardTextField(title: "Court Alias", placeholder: "Alias", text: binding.courtAlias, accessibilityIdentifier: "settings.courts.\(court.id).aliasField")
                .disabled(!isAdmin)

            HStack(spacing: 10) {
                Button(currentSettingsButtonTitle(for: "court-save-\(court.id)", defaultTitle: "Save")) {
                    updateCourt(court)
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.dashboardBrand)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(!isAdmin || savingSettingsKey != nil)
                .opacity((!isAdmin || savingSettingsKey != nil) ? 0.7 : 1)
                .accessibilityIdentifier("settings.courts.\(court.id).saveButton")

                Button(currentSettingsButtonTitle(for: "court-code-\(court.id)", defaultTitle: "New Display Code")) {
                    regenerateCourtDisplayCode(court)
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.dashboardInputBackground)
                .foregroundStyle(Color.dashboardBrand)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.dashboardBorder, lineWidth: 1))
                .buttonStyle(.plain)
                .disabled(!isAdmin || savingSettingsKey != nil)
                .opacity((!isAdmin || savingSettingsKey != nil) ? 0.7 : 1)
                .accessibilityIdentifier("settings.courts.\(court.id).displayCodeButton")

                Button(currentSettingsButtonTitle(for: "court-delete-\(court.id)", defaultTitle: "Delete")) {
                    deleteCourt(court)
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.12))
                .foregroundStyle(.red)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(!isAdmin || savingSettingsKey != nil)
                .opacity((!isAdmin || savingSettingsKey != nil) ? 0.7 : 1)
                .accessibilityIdentifier("settings.courts.\(court.id).deleteButton")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.dashboardBorder, lineWidth: 1)
        )
    }

    private func settingsRolePicker(selection: Binding<String>, accessibilityIdentifier: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Role")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Role", selection: selection) {
                Text("Admin").tag("admin")
                Text("Scorer").tag("scorer")
                Text("Read only").tag("read_only")
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(accessibilityIdentifier ?? "settings.rolePicker")
        }
    }

    private func settingsValueRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)

            Text(value.isEmpty ? "Not set" : value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var helpContent: some View {
        VStack(spacing: 18) {
            dashboardSection(
                title: "Need Help?",
                subtitle: "Send feedback or get help without leaving the app."
            ) {
                VStack(spacing: 14) {
                    feedbackForm
                    privacyComplianceLinkCard
                }
            }
        }
    }

    private var notificationCenterPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let notificationErrorMessage {
                    dashboardInlineError(notificationErrorMessage)
                }

                if notifications.isEmpty {
                    emptyState("You have no notifications.")
                } else {
                    ForEach(notifications) { notification in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: notification.isRead ? "envelope.open" : "envelope.badge")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(notification.isRead ? Color.secondary : Color.dashboardBrand)
                                .frame(width: 44, height: 44)
                                .background(Color.dashboardBrand.opacity(0.12))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 7) {
                                Text(notification.title).font(.headline.weight(.bold))
                                Text(notification.message).font(.subheadline).foregroundStyle(.secondary)
                                if notification.isRead {
                                    Text("Read").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                } else {
                                    Button("Mark as read") {
                                        Task { await markNotificationRead(notification) }
                                    }
                                    .font(.caption.weight(.bold))
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(16)
                        .background(Color.dashboardInnerCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.dashboardBorder, lineWidth: 1))
                    }
                }
            }
            .padding(18)
        }
        .background(
            LinearGradient(
                colors: [Color.dashboardBackgroundStart, Color.dashboardBackgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadNotifications() }
    }

    private var privacyComplianceLinkCard: some View {
        NavigationLink {
            privacyCompliancePage
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.dashboardBrand)
                    .frame(width: 36, height: 36)
                    .background(Color.dashboardBrand.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Privacy & Data")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("How Hit n Score collects, uses and protects your information.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.dashboardInnerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.dashboardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("help.privacyButton")
    }

    private var privacyCompliancePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title2.weight(.bold))
                Text("Last updated: September 2026")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                privacySection(
                    title: "Who we are",
                    text: "Hit n Score is operated by ucingo, which acts as the data controller for personal information processed through the service. Privacy questions can be sent to privacy@hitnscore.com."
                )
                privacySection(
                    title: "Information we collect",
                    text: "We collect account and profile information such as your name, email address, telephone number, country and club or organisation membership. We also process the match, player, court, scoring and timing information you create, together with essential login, session, device and support information needed to operate and secure the service."
                )
                privacySection(
                    title: "How information is used",
                    text: "Information is used to create and manage accounts, provide match setup and scoring, synchronise offline actions, display match history, administer clubs, respond to support requests, prevent misuse and maintain the reliability and security of Hit n Score. We do not sell personal information or use it for cross-app advertising or tracking."
                )
                privacySection(
                    title: "Legal basis",
                    text: "We process information where it is necessary to provide the service you requested, where we have a legitimate interest in operating and securing the service, where you have given consent, or where processing is required by law."
                )
                privacySection(
                    title: "Storage and service providers",
                    text: "The service uses contracted infrastructure and communication providers, including AWS for application services and Supabase-hosted PostgreSQL for primary data storage. Those providers process information only as needed to deliver the service. Information may be processed outside your country with appropriate contractual and legal safeguards."
                )
                privacySection(
                    title: "Information stored on this device",
                    text: "An unexpired login session may be stored in the iOS Keychain when biometric login is enabled. One active match and its queued scoring actions may be stored temporarily on the device for offline use. A selected profile photograph is cropped, compressed and stored in HitnScore's private cloud storage so it can be shared across your clients. Face ID and Touch ID templates are managed by Apple and are never received or stored by Hit n Score."
                )
                privacySection(
                    title: "Retention and deletion",
                    text: "Account data is retained while the account is active and only as long as reasonably necessary for service, security, legal and operational purposes. Personal-account owners can request deletion from Profile settings. Access is disabled immediately and the account is marked delete pending; the Personal workspace, its matches and scoring records are cleared after 12 months, except for limited information that must be retained by law or in time-limited backups."
                )
                privacySection(
                    title: "Your rights",
                    text: "Depending on your location, you may have rights to access, correct, erase, restrict or object to processing of your information and to request data portability. Contact privacy@hitnscore.com to exercise these rights or raise a privacy concern."
                )
                privacySection(
                    title: "Security and children",
                    text: "We use HTTPS, password hashing, access controls, expiring sessions and device-protected Keychain storage to safeguard information. No system can guarantee absolute security. Hit n Score is not directed to children under 13; clubs and guardians are responsible for ensuring any junior use is appropriately authorised and supervised."
                )
                privacySection(
                    title: "Changes and contact",
                    text: "We may update this policy when the service or legal requirements change. The current version and its update date will remain available in the app. General enquiries can be sent to hello@hitnscore.com and privacy enquiries to privacy@hitnscore.com."
                )

                if let policyURL = URL(string: "https://app.hitnscore.com/help?section=privacy") {
                    Link("View the online Privacy Policy", destination: policyURL)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dashboardBrand)
                }
            }
            .padding(18)
        }
        .background(
            LinearGradient(
                colors: [Color.dashboardBackgroundStart, Color.dashboardBackgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Privacy & Data")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func privacySection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.headline.weight(.semibold))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func accountDeletionAlert(for prompt: AccountDeletionPrompt) -> Alert {
        switch prompt {
        case .first:
            return Alert(
                title: Text("Delete your account?"),
                message: Text("This immediately disables your account and signs out every device. Your Personal matches and scoring history are retained in delete-pending state for 12 months, then permanently cleared. Club-owned match records remain with their clubs."),
                primaryButton: .destructive(Text("Continue")) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        accountDeletionPrompt = .final
                    }
                },
                secondaryButton: .cancel()
            )
        case .final:
            return Alert(
                title: Text("Are you really sure?"),
                message: Text("Your account will no longer be accessible. The scheduled clearing date will be 12 months from today."),
                primaryButton: .destructive(Text("Request Deletion")) {
                    deletePersonalAccount()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func deletePersonalAccount() {
        guard let organizationID = session?.organizationID,
              isPersonalAccount,
              isOnline,
              !isDeletingAccount else {
            return
        }

        isDeletingAccount = true
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        Task {
            do {
                try await container.apiClient.deletePersonalAccount(organizationID: organizationID)
                container.offlineMatchStore.clear()
                container.sessionStore.clear()
            } catch {
                settingsErrorMessage = (error as? APIErrorResponse)?.message
                    ?? "Unable to delete your account right now."
                isDeletingAccount = false
            }
        }
    }

    private var bottomNavigationBar: some View {
        HStack(spacing: 0) {
            ForEach(availableDashboardTabs) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: usesCompactBottomNavigation ? 3 : 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: bottomNavigationIconSize, weight: selectedTab == tab ? .semibold : .regular))

                        Text(tab.title)
                            .font(bottomNavigationFont.weight(selectedTab == tab ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .dynamicTypeSize(.xSmall ... .large)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedTab == tab ? Color.dashboardBrand : Color.dashboardTabMuted)
                    .padding(.top, usesCompactBottomNavigation ? 8 : 10)
                    .padding(.bottom, usesCompactBottomNavigation ? 6 : 8)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dashboard.tab.\(tab.rawValue)")

                if tab == .home && canManageMatches {
                    Button {
                        activeSheet = .newMatch
                    } label: {
                        VStack(spacing: usesCompactBottomNavigation ? 3 : 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.dashboardBrand)
                                    .frame(width: bottomNavigationIconSize, height: bottomNavigationIconSize)

                                Image(systemName: "play.fill")
                                    .font(.system(size: usesCompactBottomNavigation ? 9 : 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .offset(x: 1)
                            }

                            Text("Play")
                                .font(bottomNavigationFont.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                                .dynamicTypeSize(.xSmall ... .large)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color.dashboardTabMuted)
                        .padding(.top, usesCompactBottomNavigation ? 8 : 10)
                        .padding(.bottom, usesCompactBottomNavigation ? 6 : 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start New Match")
                    .accessibilityIdentifier("dashboard.startNewMatchButton")
                }
            }
        }
        .padding(.horizontal, usesCompactBottomNavigation ? 8 : 12)
        .background(
            ZStack(alignment: .top) {
                Color.dashboardTabBarBackground
                Rectangle()
                    .fill(Color.dashboardBorder)
                    .frame(height: 1)
            }
            .ignoresSafeArea()
        )
    }

    @ViewBuilder
    private func activeMatchesContent(matches: [MatchSummary]) -> some View {
        if !isOnline, let offlineActiveMatch {
            Button {
                navigationTarget = MatchRoute(id: offlineActiveMatch.id)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Continue Offline")
                            .font(.headline)
                            .foregroundStyle(Color.dashboardInk)
                        Text("\(offlineActiveMatch.player1Name) vs \(offlineActiveMatch.player2Name)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if container.offlineMatchStore.pendingActionCount > 0 {
                            Text("\(container.offlineMatchStore.pendingActionCount) change(s) waiting to sync")
                                .font(.caption)
                                .foregroundStyle(Color.orange)
                        }
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(Color.dashboardCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.dashboardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dashboard.continueOfflineMatch")
        } else if isLoading && matches.isEmpty {
            HStack {
                ProgressView()
                Spacer()
            }
        } else if matches.isEmpty {
            emptyState("No active matches")
        } else {
            VStack(spacing: 12) {
                ForEach(matches) { match in
                    Button {
                        navigationTarget = MatchRoute(id: match.id)
                    } label: {
                        activeMatchCard(match)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func scheduledMatchesContent(matches: [MatchSummary]) -> some View {
        if isLoading && matches.isEmpty {
            HStack {
                ProgressView()
                Spacer()
            }
        } else if matches.isEmpty {
            emptyState("No scheduled matches")
        } else {
            VStack(spacing: 12) {
                ForEach(matches) { match in
                    scheduledMatchCard(match) {
                        Task { await startScheduledMatch(match.id) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recentMatchesContent(matches: [MatchSummary], emptyMessage: String = "No recent matches") -> some View {
        if !isOnline {
            offlineHistoricMatchesState
        } else if isLoading && matches.isEmpty {
            HStack {
                ProgressView()
                Spacer()
            }
        } else if matches.isEmpty {
            emptyState(emptyMessage)
        } else {
            VStack(spacing: 12) {
                ForEach(matches) { match in
                    if match.locked {
                        lockedHistoryCard
                    } else {
                        Button {
                            navigationTarget = MatchRoute(id: match.id, presentation: .historic)
                        } label: {
                            recentMatchCard(match)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var lockedHistoryCard: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Previous match").font(.headline)
                Text("Player name · Opponent")
                Text("Completed match details").font(.caption)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dashboardInnerCardBackground)
            .blur(radius: 6)

            VStack(spacing: 7) {
                Image(systemName: "lock.fill").foregroundStyle(Color.dashboardBrand)
                Text("Unlock your full match history").font(.subheadline.weight(.bold))
                Button("View Personal Plus") {
                    selectedTab = .settings
                    selectedSettingsSection = .subscription
                    settingsNavigationItem = .subscription
                }
                .font(.caption.weight(.bold))
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.dashboardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func dashboardSection<Content: View>(
        title: String,
        systemImage: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.dashboardAccentPink)
                    }

                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                }

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.dashboardBorder, lineWidth: 1)
        )
        .shadow(
            color: colorScheme == .dark ? .clear : Color.black.opacity(0.04),
            radius: 12,
            x: 0,
            y: 8
        )
    }

    private func matchesSubsection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.dashboardBrand)
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            content()
        }
    }

    @ViewBuilder
    private func emptyState(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
    }

    private var offlineHistoricMatchesState: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.dashboardBrand)

            Text("Offline")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Historic matches are only available when the app is online.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private func activeMatchCard(_ match: MatchSummary) -> some View {
        let player1 = splitPlayerName(match.player1Name, surname: match.player1Surname)
        let player2 = splitPlayerName(match.player2Name, surname: match.player2Surname)
        let liveScore = currentScoreLine(for: match)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                if let courtName = match.courtName, !courtName.isEmpty {
                    Text(courtName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.dashboardActiveStatus)
                        .frame(width: 9, height: 9)
                    Text("In Progress")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.dashboardActiveStatus)
                }
            }

            HStack(alignment: .center, spacing: 12) {
                playerColumn(firstName: player1.firstName, surname: player1.surname, alignment: .leading)

                Spacer(minLength: 6)

                VStack(spacing: 4) {
                    Text(liveScore)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.dashboardBrand)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Text("Best of \(match.bestOf ?? match.state?.bestOf ?? 3)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 6)

                playerColumn(firstName: player2.firstName, surname: player2.surname, alignment: .trailing)

                Button {
                    navigationTarget = MatchRoute(id: match.id)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.dashboardBrand)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.92))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.dashboardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func scheduledMatchCard(_ match: MatchSummary, action: @escaping () -> Void) -> some View {
        let player1 = splitPlayerName(match.player1Name, surname: match.player1Surname)
        let player2 = splitPlayerName(match.player2Name, surname: match.player2Surname)
        let player1DisplayName = [player1.firstName, player1.surname]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let player2DisplayName = [player2.firstName, player2.surname]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let courtName = match.courtName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let formatDescription = "Best of \(match.bestOf ?? 3)"

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(courtName.isEmpty ? formatDescription : "\(courtName) • \(formatDescription)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(player1DisplayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("vs")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(player2DisplayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            if canManageMatches {
                HStack(spacing: 8) {
                Button {
                    navigationTarget = MatchRoute(id: match.id, presentation: .live(openSettingsOnLoad: true))
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.dashboardBrand)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.92))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.dashboardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit scheduled match")

                Button {
                    action()
                } label: {
                    Group {
                        if startingScheduledMatchID == match.id {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.subheadline.weight(.bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.dashboardBrand)
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(startingScheduledMatchID == match.id ? "Starting scheduled match" : "Start scheduled match")
                .disabled(startingScheduledMatchID != nil)
                .opacity(startingScheduledMatchID != nil ? 0.7 : 1)
                }
            } else {
                Text("Read only")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func recentMatchCard(_ match: MatchSummary) -> some View {
        let player1 = splitPlayerName(match.player1Name, surname: match.player1Surname)
        let player2 = splitPlayerName(match.player2Name, surname: match.player2Surname)
        let winnerSide = historyWinnerSide(for: match)
        let dateParts = recentMatchDateParts(for: match)
        let player1Games = match.state?.player1GamesWon ?? 0
        let player2Games = match.state?.player2GamesWon ?? 0

        return HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(dateParts.day)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(dateParts.month)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.dashboardBrand)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(width: 64)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [
                        Color.yellow.opacity(0.88),
                        Color.orange.opacity(0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            Text(sportDisplayName(match.sport).uppercased())
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .rotationEffect(.degrees(-90))
                .frame(width: 30)
                .frame(maxHeight: .infinity)
                .background(recentMatchSportColor(match.sport))

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text([player1.firstName, player1.surname].filter { !$0.isEmpty }.joined(separator: " "))
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(winnerSide == 1 ? Color.dashboardAccentPink : Color.dashboardBrand)
                        .lineLimit(1)

                    Text("vs")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text([player2.firstName, player2.surname].filter { !$0.isEmpty }.joined(separator: " "))
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(winnerSide == 2 ? Color.dashboardAccentPink : Color.dashboardBrand)
                        .lineLimit(1)

                    Text((match.state?.gameHistory ?? []).map { "\($0.player1Score)-\($0.player2Score)" }.joined(separator: " | "))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 4)

                VStack(spacing: 0) {
                    Text("\(player1Games)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(winnerSide == 1 ? Color.dashboardAccentPink : Color.dashboardBrand)
                    Text("\(player2Games)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(winnerSide == 2 ? Color.dashboardAccentPink : Color.dashboardBrand)
                }

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.dashboardBrand)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.92))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.dashboardBorder, lineWidth: 1))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func recentMatchSportColor(_ sport: String?) -> Color {
        switch (sport ?? "squash").lowercased() {
        case "racketball": return Color(red: 34 / 255, green: 111 / 255, blue: 205 / 255)
        case "tennis": return Color(red: 83 / 255, green: 158 / 255, blue: 74 / 255)
        case "padel": return Color(red: 196 / 255, green: 137 / 255, blue: 15 / 255)
        default: return Color(red: 24 / 255, green: 47 / 255, blue: 70 / 255)
        }
    }

    private func playerColumn(firstName: String, surname: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(firstName)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            if !surname.isEmpty {
                Text(surname)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    private func personalPlusSubscriptionOptionCard(
        subtitle: String,
        isCurrent: Bool
    ) -> some View {
        Button {
            if isPersonalPlusOptionsExpanded {
                closePersonalPlusOptions()
            } else {
                openPersonalPlusOptions()
            }
        } label: {
            subscriptionOptionCardContent(
                title: "Personal Plus",
                subtitle: subtitle,
                status: isCurrent ? "Current" : "Upgrade Option",
                isCurrent: isCurrent,
                trailingSystemImage: isPersonalPlusOptionsExpanded ? "chevron.up" : "chevron.down"
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.subscription.personalPlus.expandButton")
        .accessibilityValue(isPersonalPlusOptionsExpanded ? "Expanded" : "Collapsed")
    }

    private func openPersonalPlusOptions() {
        personalPlusCollapseTask?.cancel()
        withAnimation(.easeInOut(duration: 0.8)) {
            isPersonalPlusOptionsExpanded = true
        }

        personalPlusCollapseTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled else { return }

            if container.purchaseService.purchasingProductID != nil {
                openPersonalPlusOptions()
                return
            }

            withAnimation(.easeInOut(duration: 0.8)) {
                isPersonalPlusOptionsExpanded = false
            }
            personalPlusCollapseTask = nil
        }
    }

    private func closePersonalPlusOptions() {
        personalPlusCollapseTask?.cancel()
        personalPlusCollapseTask = nil
        withAnimation(.easeInOut(duration: 0.8)) {
            isPersonalPlusOptionsExpanded = false
        }
    }

    @ViewBuilder
    private func subscriptionOptionCard(
        title: String,
        subtitle: String,
        isCurrent: Bool,
        enquiryPlan: ClubSubscriptionPlan?
    ) -> some View {
        if let enquiryPlan, !isCurrent {
            Button {
                openClubSubscriptionEnquiry(enquiryPlan)
            } label: {
                subscriptionOptionCardContent(
                    title: title,
                    subtitle: subtitle,
                    status: "Enquire",
                    isCurrent: false
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.subscription.\(enquiryPlan.rawValue).enquireButton")
        } else {
            subscriptionOptionCardContent(
                title: title,
                subtitle: subtitle,
                status: isCurrent ? "Current" : "Available",
                isCurrent: isCurrent
            )
        }
    }

    private func subscriptionOptionCardContent(
        title: String,
        subtitle: String,
        status: String,
        isCurrent: Bool,
        trailingSystemImage: String? = nil
    ) -> some View {
        let isEnquiry = status == "Enquire"
        let statusColor = isCurrent
            ? Color.dashboardAccentPink
            : (isEnquiry ? Color.dashboardBrand : Color.secondary)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)

                Spacer()

                Text(status)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        statusColor.opacity(isCurrent || isEnquiry ? 0.16 : 0.12)
                    )
                    .clipShape(Capsule())

                if isEnquiry {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.dashboardBrand)
                }

                if let trailingSystemImage {
                    Image(systemName: trailingSystemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.dashboardBrand)
                        .frame(width: 18)
                }
            }

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isCurrent ? Color.green : Color.dashboardBorder, lineWidth: isCurrent ? 2 : 1)
        )
    }

    private func settingsCourtsCard(_ courts: [CourtSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Courts")
                .font(.headline.weight(.semibold))

            ForEach(courts) { court in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(court.courtName)
                            .font(.subheadline.weight(.semibold))
                        Text(court.courtAlias)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("#\(court.id)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var feedbackForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ping Us")
                .font(.headline.weight(.semibold))

            dashboardTextField(title: "Name", placeholder: "Your name", text: $feedbackName)
            dashboardTextField(title: "Email", placeholder: "you@example.com", text: $feedbackEmail, keyboardType: .emailAddress)

            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Category", selection: $feedbackCategory) {
                    Text("Feedback").tag("feedback")
                    Text("Issue").tag("issue")
                    Text("Idea").tag("idea")
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Message")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextEditor(text: $feedbackMessage)
                    .frame(minHeight: 120)
                    .padding(10)
                    .background(Color.dashboardInputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.dashboardBorder, lineWidth: 1)
                    )
            }

            if let feedbackErrorMessage {
                dashboardInlineError(feedbackErrorMessage)
            }


            Button(isSubmittingFeedback ? "Sending..." : "Send Feedback") {
                submitFeedback()
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.dashboardBrand)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .buttonStyle(.plain)
            .disabled(isSubmittingFeedback)
            .opacity(isSubmittingFeedback ? 0.75 : 1)

            Text(helpFooterText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var resetForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Password Reset")
                .font(.headline.weight(.semibold))

            dashboardTextField(title: "Account email", placeholder: "you@example.com", text: $resetEmail, keyboardType: .emailAddress)

            if let resetErrorMessage {
                dashboardInlineError(resetErrorMessage)
            }


            Button(isRequestingPasswordReset ? "Sending..." : "Send Reset Link") {
                requestPasswordReset()
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.dashboardBrand.opacity(0.9))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .buttonStyle(.plain)
            .disabled(isRequestingPasswordReset)
            .opacity(isRequestingPasswordReset ? 0.75 : 1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func dashboardTextField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        accessibilityIdentifier: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text)
                .textInputAutocapitalization(
                    keyboardType == .emailAddress || keyboardType == .URL ? .never : .words
                )
                .autocorrectionDisabled(keyboardType == .emailAddress || keyboardType == .URL)
                .keyboardType(keyboardType)
                .accessibilityIdentifier(accessibilityIdentifier ?? "settings.field.\(title.replacingOccurrences(of: " ", with: "").lowercased())")
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.dashboardInputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.dashboardBorder, lineWidth: 1)
                )
        }
    }

    private func dashboardInlineError(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dashboardInlineSuccess(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(Color.green)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsBadge(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.dashboardInputBackground)
            .clipShape(Capsule())
    }

    private func settingsSportBadgeRow(for sport: MatchSport) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.dashboardBrand.opacity(0.12))
                    .frame(width: 42, height: 42)

                racketSportGlyph(for: sport, isAvailable: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(sport.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(sport.isImplementedToday ? "Ready in the current app" : "Prepared for future release")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.dashboardInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func associationMembershipRow(_ membership: UserMembership) -> some View {
        return Button {
            openAssociationClub(membership)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.dashboardBrand.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: "building.2.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color.dashboardBrand)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(membership.organizationName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(planDisplayName(for: membership.plan ?? "club_essentials"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(roleDisplayName(for: membership.role))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dashboardBrand)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.dashboardBrand.opacity(0.12))
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.dashboardBrand)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.dashboardInputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.dashboardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.association.\(membership.organizationID)")
    }

    private func accountContextSwitcher(label: String?, compact: Bool = false) -> some View {
        Button {
            showsAccountContextMenu.toggle()
        } label: {
            HStack(spacing: 8) {
                if let label, !label.isEmpty {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(session?.isPersonalAccount == true ? "Personal" : (session?.organizationName ?? "Account"))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: compact ? "line.3.horizontal" : "chevron.up.chevron.down")
                    .font(compact ? .subheadline.weight(.semibold) : .caption2.weight(.bold))
                    .foregroundStyle(Color.dashboardBrand)
            }
            .frame(maxWidth: compact ? nil : .infinity)
            .padding(.horizontal, compact ? 12 : 14)
            .padding(.vertical, compact ? 9 : 10)
            .background(Color.dashboardCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 22 : 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 22 : 16, style: .continuous)
                    .stroke(Color.dashboardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(
            isPresented: $showsAccountContextMenu,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .top
        ) {
            accountContextPanel
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityIdentifier("account.contextSwitcher")
    }

    private var accountContextPanel: some View {
        VStack(spacing: 0) {
            ForEach(Array(orderedMemberships.enumerated()), id: \.element.id) { index, membership in
                accountContextMembershipRow(membership)

                if index < orderedMemberships.count - 1 {
                    Divider()
                        .padding(.horizontal, 12)
                }
            }

            Divider()
                .padding(.horizontal, 12)

            Button {
                showsAccountContextMenu = false
                container.logout()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Logout")
                            .font(.subheadline.weight(.bold))
                        Text("Sign out of HitnScore")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)
                }
                .foregroundStyle(Color.dashboardAccentPink)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 320)
        .padding(.vertical, 6)
        .background(Color.dashboardCardBackground)
    }

    private func accountContextMembershipRow(_ membership: UserMembership) -> some View {
        let isCurrent = membership.organizationID == session?.organizationID
        let title = isPersonalMembership(membership) ? "Personal" : membership.organizationName
        let plan = planDisplayName(for: membership.plan ?? (isPersonalMembership(membership) ? "personal_free" : "club_essentials"))
        let subtitle = isPersonalMembership(membership)
            ? plan
            : "\(plan) · \(roleDisplayName(for: membership.role))"

        return Button {
            guard !isCurrent else { return }
            showsAccountContextMenu = false
            switchAssociation(to: membership)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.dashboardBrand.opacity(isCurrent ? 0.18 : 0.1))
                        .frame(width: 42, height: 42)

                    Image(systemName: isPersonalMembership(membership) ? "person.fill" : "building.2.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.dashboardBrand)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if isCurrent {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Current")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.dashboardBrand)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.dashboardBrand)
                    }
                } else {
                    Text("Switch")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.dashboardBrand)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(isCurrent ? Color.dashboardBrand.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isCurrent)
        .accessibilityIdentifier("account.context.\(membership.organizationID)")
    }

    @ViewBuilder
    private func racketSportGlyph(for sport: MatchSport, isAvailable: Bool) -> some View {
        let foreground = isAvailable ? Color.dashboardBrand : Color.secondary.opacity(0.72)

        switch sport {
        case .squash:
            settingsSportBallImage(named: "SportBallSquash", isAvailable: isAvailable)
        case .racketball:
            settingsSportBallImage(named: "SportBallRacketball", isAvailable: isAvailable)
        case .tennis:
            settingsSportBallImage(named: "SportBallTennis", isAvailable: isAvailable)
        case .padel:
            settingsSportBallImage(named: "SportBallPadel", isAvailable: isAvailable)
        case .tableTennis:
            ZStack {
                Circle()
                    .fill(foreground)
                    .frame(width: 12, height: 12)
                    .offset(x: -2, y: -5)
                Capsule()
                    .fill(foreground)
                    .frame(width: 7, height: 16)
                    .offset(x: 5, y: 6)
            }
        case .pickleball:
            ZStack {
                Circle()
                    .stroke(foreground, lineWidth: 2.0)
                    .frame(width: 16, height: 16)
                ForEach([(-3.0), 0.0, 3.0], id: \.self) { y in
                    Circle().fill(foreground).frame(width: 3, height: 3).offset(x: -3, y: y)
                    Circle().fill(foreground).frame(width: 3, height: 3).offset(x: 3, y: y)
                }
            }
        case .badminton:
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Capsule().fill(foreground).frame(width: 4, height: 10).rotationEffect(.degrees(-20))
                    Capsule().fill(foreground).frame(width: 4, height: 10)
                    Capsule().fill(foreground).frame(width: 4, height: 10).rotationEffect(.degrees(20))
                }
                Circle()
                    .fill(foreground)
                    .frame(width: 7, height: 7)
            }
        }
    }

    private func settingsSportBallImage(named assetName: String, isAvailable: Bool) -> some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: 26, height: 26)
            .opacity(isAvailable ? 1 : 0.48)
            .shadow(color: Color.black.opacity(isAvailable ? 0.16 : 0.06), radius: 2, x: 0, y: 1)
    }

    private func syncSettingsDrafts(from settings: OrganizationSettings) {
        let lookupEmails = Set(
            [
                session?.username,
                session?.email,
                personalProfileDraft.email
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        )
        let profileUser = settings.users.first { user in
            lookupEmails.contains(user.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }

        organizationDetailsDraft = OrganizationDetailsDraft(profile: settings.organization)
        organizationUserDrafts = Dictionary(
            uniqueKeysWithValues: settings.users.map { ($0.id, OrganizationUserDraft(user: $0)) }
        )
        courtDrafts = Dictionary(
            uniqueKeysWithValues: settings.courts.map { ($0.id, CourtDraft(court: $0)) }
        )
        enabledSportsDraft = settings.organization.enabledSports
        timedBreakDefaultsDraft = settings.organization.timedBreakDefaults
        personalProfileDraft = PersonalProfileDraft(user: profileUser, fallbackSession: session)
        normalizeSelectedSettingsMenuItem()
    }

    private func loadDashboard() async {
        guard let currentSession = container.sessionStore.session else {
            print("DASHBOARD LOAD: missing organization ID in session")
            return
        }
        let organizationID = currentSession.organizationID
        let personalOrganizationID = currentSession.isPersonalAccount
            ? organizationID
            : personalMembership?.organizationID

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        guard isOnline else {
            await MainActor.run {
                isLoading = false
                errorMessage = nil
            }
            return
        }

        do {
            let dashboard = try await container.apiClient.getDashboard(
                organizationID: organizationID,
                activeLimit: 200,
                recentLimit: 1000,
                analyticsPeriodDays: analyticsPeriodDays
            )
            let personalDashboard: DashboardResponse?
            if let personalOrganizationID, personalOrganizationID != organizationID {
                personalDashboard = try await container.apiClient.getDashboard(
                    organizationID: personalOrganizationID,
                    activeLimit: 0,
                    recentLimit: 0,
                    analyticsPeriodDays: analyticsPeriodDays
                )
            } else {
                personalDashboard = dashboard
            }

            await MainActor.run {
                organizationSummary = dashboard.organization
                activeMatches = dashboard.activeMatches
                scheduledMatches = dashboard.scheduledMatches
                recentMatches = dashboard.recentMatches
                viewedMatches = dashboard.viewedMatches

                performanceSummary = personalDashboard?.performance
                personalAppAnalytics = personalDashboard?.appAnalytics
                personalPlayerAnalytics = personalDashboard?.playerAnalytics

                if currentSession.isPersonalAccount {
                    selectedAnalyticsCategory = .personal
                    clubAppAnalytics = nil
                    clubAnalytics = nil
                } else {
                    clubAppAnalytics = dashboard.appAnalytics
                    clubAnalytics = dashboard.clubAnalytics
                }

                isLoading = false
            }
        } catch is CancellationError {
            await MainActor.run {
                isLoading = false
            }
        } catch let urlError as URLError where urlError.code == .cancelled {
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                print("DASHBOARD LOAD ERROR:", error)
                errorMessage = (error as? APIErrorResponse)?.message ?? "Unable to fetch dashboard data."
                isLoading = false
            }
        }
    }

    private func prepareAnalyticsExport() async {
        guard isOnline else {
            await MainActor.run { analyticsExportError = "Connect to the internet to export analytics." }
            return
        }

        let organizationID: Int?
        if selectedAnalyticsCategory == .club {
            organizationID = isPersonalAccount ? nil : session?.organizationID
        } else {
            organizationID = personalMembership?.organizationID ?? (isPersonalAccount ? session?.organizationID : nil)
        }
        guard let organizationID else { return }

        await MainActor.run {
            isExportingAnalytics = true
            analyticsExportError = nil
            analyticsExportURL = nil
        }

        do {
            let report = try await container.apiClient.exportAnalytics(
                organizationID: organizationID,
                periodDays: analyticsPeriodDays
            )
            let safeFilename = report.filename.replacingOccurrences(of: "/", with: "-")
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(safeFilename)
            try report.csvContent.write(to: url, atomically: true, encoding: .utf8)
            await MainActor.run {
                analyticsExportURL = url
                isExportingAnalytics = false
            }
        } catch {
            await MainActor.run {
                analyticsExportError = (error as? APIErrorResponse)?.message ?? "Unable to prepare the analytics export."
                isExportingAnalytics = false
            }
        }
    }
    private func loadNotifications() async {
        guard isOnline, let organizationID = session?.organizationID else { return }
        do {
            let loaded = try await container.apiClient.getNotifications(organizationID: organizationID)
            await MainActor.run {
                notifications = loaded
                notificationErrorMessage = nil
            }
        } catch {
            await MainActor.run {
                notificationErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to load notifications."
            }
        }
    }

    private func markNotificationRead(_ notification: AppNotification) async {
        guard let organizationID = session?.organizationID else { return }
        do {
            try await container.apiClient.markNotificationRead(notificationID: notification.id, organizationID: organizationID)
            await loadNotifications()
        } catch {
            await MainActor.run {
                notificationErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to mark this notification as read."
            }
        }
    }

    private func loadOrganizationSettingsIfNeeded(force: Bool = false) async {
        guard let organizationID = container.sessionStore.session?.organizationID else {
            return
        }

        if organizationSettings != nil && !force {
            return
        }

        await MainActor.run {
            isLoadingSettings = true
            settingsErrorMessage = nil
        }

        do {
            let settings = try await container.apiClient.getOrganizationSettings(organizationID: organizationID)
            await MainActor.run {
                organizationSettings = settings
                syncSettingsDrafts(from: settings)
                isLoadingSettings = false
            }
        } catch {
            await MainActor.run {
                settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to load organisation settings."
                isLoadingSettings = false
            }
        }
    }

    private func openClubSubscriptionEnquiry(_ plan: ClubSubscriptionPlan) {
        clubEnquiryDraft = ClubSubscriptionEnquiryDraft(
            clubName: isPersonalAccount ? "" : (session?.organizationName ?? ""),
            clubAddress: "",
            clubPostcode: "",
            clubEmail: "",
            clubWebsite: "",
            clubTelephone: ""
        )
        clubEnquiryErrorMessage = nil
        clubEnquirySuccessMessage = nil
        isSubmittingClubEnquiry = false
        clubEnquiryPlan = plan
    }

    private func submitClubSubscriptionEnquiry(_ plan: ClubSubscriptionPlan) {
        let clubName = clubEnquiryDraft.clubName.trimmingCharacters(in: .whitespacesAndNewlines)
        let clubAddress = clubEnquiryDraft.clubAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let clubPostcode = clubEnquiryDraft.clubPostcode.trimmingCharacters(in: .whitespacesAndNewlines)
        let clubEmail = clubEnquiryDraft.clubEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let clubWebsite = clubEnquiryDraft.clubWebsite.trimmingCharacters(in: .whitespacesAndNewlines)
        let clubTelephone = clubEnquiryDraft.clubTelephone.trimmingCharacters(in: .whitespacesAndNewlines)
        let accountEmail = (session?.email ?? session?.username ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !clubName.isEmpty,
              !clubAddress.isEmpty,
              !clubPostcode.isEmpty,
              !clubWebsite.isEmpty,
              !clubTelephone.isEmpty else {
            clubEnquiryErrorMessage = "Complete all club details before sending the enquiry."
            return
        }

        guard isValidEmail(clubEmail) else {
            clubEnquiryErrorMessage = "Enter a valid club email address."
            return
        }

        guard isValidEmail(accountEmail) else {
            clubEnquiryErrorMessage = "Your signed-in account does not contain a valid email address. Update your profile before sending the enquiry."
            return
        }

        guard isOnline else {
            clubEnquiryErrorMessage = "An internet connection is required to send a club enquiry."
            return
        }

        isSubmittingClubEnquiry = true
        clubEnquiryErrorMessage = nil

        Task {
            do {
                try await container.apiClient.registerInterest(
                    firstName: currentUserFirstName,
                    surname: currentUserSurname,
                    email: accountEmail,
                    useType: "club",
                    clubName: clubName,
                    requestedPlan: plan.rawValue,
                    clubAddress: clubAddress,
                    clubPostcode: clubPostcode,
                    clubEmail: clubEmail,
                    clubWebsite: clubWebsite,
                    clubTelephone: clubTelephone,
                    pageURL: "ios-app://settings/subscription"
                )
                await MainActor.run {
                    isSubmittingClubEnquiry = false
                    clubEnquirySuccessMessage = "We have received your \(plan.displayName) enquiry for \(clubName). A confirmation has been sent to \(accountEmail), and the Hit n Score team will contact you about the next steps."
                }
            } catch {
                await MainActor.run {
                    isSubmittingClubEnquiry = false
                    clubEnquiryErrorMessage = (error as? APIErrorResponse)?.message
                        ?? "Unable to send the club enquiry right now."
                }
            }
        }
    }

    private func savePersonalProfile() {
        guard let organizationID = personalProfileOrganizationID else {
            return
        }

        let trimmedEmail = personalProfileDraft.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidEmail(trimmedEmail) else {
            settingsErrorMessage = "Enter a valid email address."
            settingsSuccessMessage = nil
            return
        }

        savingSettingsKey = "profile-save"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        let emailChanged = trimmedEmail != (session?.email ?? session?.username ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        Task {
            do {
                let settings = try await container.apiClient.updatePersonalProfile(
                    organizationID: organizationID,
                    firstName: personalProfileDraft.firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                    surname: personalProfileDraft.surname.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: trimmedEmail,
                    country: personalProfileDraft.country.trimmingCharacters(in: .whitespacesAndNewlines),
                    telephone: personalProfileDraft.telephone.trimmingCharacters(in: .whitespacesAndNewlines),
                    cityLocation: "",
                    birthMonth: personalProfileDraft.birthMonth,
                    birthYear: personalProfileDraft.birthYear
                )
                await MainActor.run {
                    if isPersonalAccount {
                        organizationSettings = settings
                        syncSettingsDrafts(from: settings)
                    }
                    persistSessionProfile(
                        firstName: personalProfileDraft.firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                        surname: personalProfileDraft.surname.trimmingCharacters(in: .whitespacesAndNewlines),
                        email: trimmedEmail,
                        country: personalProfileDraft.country.trimmingCharacters(in: .whitespacesAndNewlines),
                        telephone: personalProfileDraft.telephone.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    settingsSuccessMessage = emailChanged
                        ? "Profile updated. Please sign in again with your new email."
                        : "Profile updated."
                    isEditingPersonalProfile = false
                    savingSettingsKey = nil
                }

                if emailChanged {
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    await MainActor.run {
                        container.sessionStore.clear()
                    }
                }
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to save your profile."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func updateBiometricUnlockPreference(_ isEnabled: Bool) {
        guard !isUpdatingBiometricUnlock else {
            return
        }

        settingsErrorMessage = nil
        settingsSuccessMessage = nil
        isUpdatingBiometricUnlock = true

        Task {
            if isEnabled {
                do {
                    try await container.sessionStore.enableBiometricUnlock()
                    await MainActor.run {
                        settingsSuccessMessage = "\(container.sessionStore.biometricDisplayName) login enabled for this device."
                        isUpdatingBiometricUnlock = false
                    }
                } catch {
                    await MainActor.run {
                        settingsErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to enable biometric login."
                        isUpdatingBiometricUnlock = false
                    }
                }
            } else {
                await MainActor.run {
                    container.sessionStore.disableBiometricUnlock()
                    settingsSuccessMessage = "Biometric login disabled."
                    isUpdatingBiometricUnlock = false
                }
            }
        }
    }

    private func currentSettingsButtonTitle(for key: String, defaultTitle: String) -> String {
        savingSettingsKey == key ? "Working..." : defaultTitle
    }

    private func saveOrganizationDetails() {
        guard let organizationID = session?.organizationID else {
            return
        }

        savingSettingsKey = "organization-save"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        Task {
            do {
                let settings = try await container.apiClient.updateOrganizationDetails(
                    organizationID: organizationID,
                    draft: organizationDetailsDraft
                )
                await MainActor.run {
                    organizationSettings = settings
                    syncSettingsDrafts(from: settings)
                    settingsSuccessMessage = "Organisation details updated."
                    savingSettingsKey = nil
                }
                await loadDashboard()
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to save organisation details."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func saveOrganizationEnabledSports() {
        guard let organizationID = personalProfileOrganizationID else {
            return
        }

        savingSettingsKey = "sports-save"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        Task {
            do {
                let settings = try await container.apiClient.updateOrganizationEnabledSports(
                    organizationID: organizationID,
                    enabledSports: normalizedEnabledSportsDraft()
                )
                await MainActor.run {
                    enabledSportsDraft = settings.organization.enabledSports
                    timedBreakDefaultsDraft = settings.organization.timedBreakDefaults
                    if isPersonalAccount { persistSessionEnabledSports(settings.organization.enabledSports) }
                    settingsSuccessMessage = "Sport access updated."
                    savingSettingsKey = nil
                }
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to update sport access."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func saveTimedBreakDefaults() {
        guard let organizationID = personalProfileOrganizationID else {
            return
        }

        savingSettingsKey = "timer-defaults-save"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        Task {
            do {
                let settings = try await container.apiClient.updateOrganizationTimedBreakDefaults(
                    organizationID: organizationID,
                    timedBreakDefaults: timedBreakDefaultsDraft
                )
                await MainActor.run {
                    enabledSportsDraft = settings.organization.enabledSports
                    timedBreakDefaultsDraft = settings.organization.timedBreakDefaults
                    settingsSuccessMessage = "Per-sport timer defaults updated."
                    savingSettingsKey = nil
                }
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to update timer defaults."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func createOrganizationUser() {
        guard let organizationID = session?.organizationID else {
            return
        }

        let email = newOrganizationUserDraft.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidEmail(email) else {
            settingsErrorMessage = "Enter a valid email address for the user."
            settingsSuccessMessage = nil
            return
        }

        var draft = newOrganizationUserDraft
        draft.username = email

        savingSettingsKey = "user-create"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        Task {
            do {
                try await container.apiClient.createOrganizationUser(
                    organizationID: organizationID,
                    draft: draft
                )
                await loadOrganizationSettingsIfNeeded(force: true)
                await MainActor.run {
                    newOrganizationUserDraft = OrganizationUserDraft()
                    settingsSuccessMessage = "User added to organisation. Invitation email sent and access is pending approval."
                    savingSettingsKey = nil
                }
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to create organisation user."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func updateOrganizationUser(_ user: OrganizationUser) {
        guard let organizationID = session?.organizationID else {
            return
        }
        guard let draft = organizationUserDrafts[user.id] else {
            return
        }

        savingSettingsKey = "user-save-\(user.id)"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        Task {
            do {
                try await container.apiClient.updateOrganizationUser(
                    organizationID: organizationID,
                    userID: user.id,
                    draft: draft
                )
                await loadOrganizationSettingsIfNeeded(force: true)
                await MainActor.run {
                    settingsSuccessMessage = "User updated."
                    savingSettingsKey = nil
                }
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to update the user."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func sendOrganizationUserPasswordReset(_ user: OrganizationUser) {
        savingSettingsKey = "user-password-\(user.id)"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil
        Task {
            do {
                try await container.apiClient.requestPasswordReset(email: user.username)
                await MainActor.run {
                    settingsSuccessMessage = "A secure password reset link has been sent if this email is registered."
                    savingSettingsKey = nil
                }
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to send a password reset right now."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func deleteOrganizationUser(_ user: OrganizationUser) {
        guard let organizationID = session?.organizationID else {
            return
        }

        savingSettingsKey = "user-delete-\(user.id)"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        Task {
            do {
                try await container.apiClient.deleteOrganizationUser(
                    organizationID: organizationID,
                    userID: user.id
                )
                await loadOrganizationSettingsIfNeeded(force: true)
                await MainActor.run {
                    settingsSuccessMessage = "User deleted."
                    savingSettingsKey = nil
                }
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to delete the user."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func createCourt() {
        guard let organizationID = session?.organizationID else {
            return
        }

        savingSettingsKey = "court-create"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        Task {
            do {
                try await container.apiClient.createCourt(
                    organizationID: organizationID,
                    draft: newCourtDraft
                )
                await loadOrganizationSettingsIfNeeded(force: true)
                await MainActor.run {
                    newCourtDraft = CourtDraft()
                    settingsSuccessMessage = "Court created."
                    savingSettingsKey = nil
                }
                await loadDashboard()
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to create the court."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func updateCourt(_ court: CourtSummary) {
        guard let organizationID = session?.organizationID else {
            return
        }
        guard let draft = courtDrafts[court.id] else {
            return
        }

        savingSettingsKey = "court-save-\(court.id)"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        Task {
            do {
                try await container.apiClient.updateCourt(
                    organizationID: organizationID,
                    courtID: court.id,
                    draft: draft
                )
                await loadOrganizationSettingsIfNeeded(force: true)
                await MainActor.run {
                    settingsSuccessMessage = "Court updated."
                    savingSettingsKey = nil
                }
                await loadDashboard()
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to update the court."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func deleteCourt(_ court: CourtSummary) {
        guard let organizationID = session?.organizationID else {
            return
        }

        savingSettingsKey = "court-delete-\(court.id)"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        Task {
            do {
                try await container.apiClient.deleteCourt(
                    organizationID: organizationID,
                    courtID: court.id
                )
                await loadOrganizationSettingsIfNeeded(force: true)
                await MainActor.run {
                    settingsSuccessMessage = "Court deleted."
                    savingSettingsKey = nil
                }
                await loadDashboard()
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to delete the court."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func regenerateCourtDisplayCode(_ court: CourtSummary) {
        guard let organizationID = session?.organizationID else {
            return
        }

        savingSettingsKey = "court-code-\(court.id)"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        Task {
            do {
                let settings = try await container.apiClient.createCourtDisplayCode(
                    organizationID: organizationID,
                    courtID: court.id
                )
                await MainActor.run {
                    organizationSettings = settings
                    syncSettingsDrafts(from: settings)
                    settingsSuccessMessage = "Display code updated."
                    savingSettingsKey = nil
                }
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to update the display code."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func startScheduledMatch(_ matchID: String) async {
        await MainActor.run {
            startingScheduledMatchID = matchID
            errorMessage = nil
        }

        do {
            let activatedMatch = try await container.apiClient.startScheduledMatch(matchID: matchID)
            await MainActor.run {
                startingScheduledMatchID = nil
                navigationTarget = MatchRoute(id: activatedMatch.id)
            }
            await loadDashboard()
        } catch {
            await MainActor.run {
                startingScheduledMatchID = nil
                errorMessage = (error as? APIErrorResponse)?.message ?? "Unable to start the scheduled match."
            }
        }
    }

    private func handleStartNewMatchResult(_ result: StartNewMatchResult) {
        activeSheet = nil
        Task { await loadDashboard() }

        switch result {
        case .openMatch(let matchID):
            dashboardNotice = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                navigationTarget = MatchRoute(id: matchID)
            }
        case .scheduled(let notice):
            dashboardNotice = notice ?? "Match saved as scheduled."
        }
    }

    private func submitFeedback() {
        let name = feedbackName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = feedbackEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let message = feedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else {
            feedbackErrorMessage = "Your name is required."
            feedbackSuccessMessage = nil
            return
        }

        guard isValidEmail(email) else {
            feedbackErrorMessage = "A valid email address is required."
            feedbackSuccessMessage = nil
            return
        }

        guard message.count >= 5 else {
            feedbackErrorMessage = "Please provide more detail."
            feedbackSuccessMessage = nil
            return
        }

        isSubmittingFeedback = true
        feedbackErrorMessage = nil
        feedbackSuccessMessage = nil

        Task {
            do {
                try await container.apiClient.submitFeedback(
                    name: name,
                    email: email,
                    category: feedbackCategory,
                    message: message,
                    username: session?.username ?? "",
                    organizationName: session?.organizationName ?? "",
                    version: "RcktScore iOS",
                    build: AppConfig.buildID,
                    pageURL: "ios-app://dashboard/help"
                )
                await MainActor.run {
                    feedbackSuccessMessage = "Thanks. Your message has been sent."
                    feedbackErrorMessage = nil
                    feedbackMessage = ""
                    isSubmittingFeedback = false
                }
            } catch {
                await MainActor.run {
                    feedbackErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to send your message."
                    feedbackSuccessMessage = nil
                    isSubmittingFeedback = false
                }
            }
        }
    }

    private func requestPasswordReset() {
        let email = resetEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidEmail(email) else {
            resetErrorMessage = "Enter a valid email address."
            resetMessage = nil
            return
        }

        isRequestingPasswordReset = true
        resetErrorMessage = nil
        resetMessage = nil

        Task {
            do {
                try await container.apiClient.requestPasswordReset(email: email)
                await MainActor.run {
                    resetMessage = "If that email is registered, a password reset link has been sent."
                    resetErrorMessage = nil
                    isRequestingPasswordReset = false
                }
            } catch {
                await MainActor.run {
                    resetErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to request password reset right now."
                    resetMessage = nil
                    isRequestingPasswordReset = false
                }
            }
        }
    }

    private func switchAssociation(to membership: UserMembership) {
        guard membership.organizationID != session?.organizationID else {
            return
        }

        container.sessionStore.switchMembership(to: membership)
        organizationSummary = nil
        organizationSettings = nil
        activeMatches = []
        scheduledMatches = []
        recentMatches = []
        settingsErrorMessage = nil
        settingsSuccessMessage = nil
        settingsNavigationItem = nil
        dashboardNotice = "Switched to \(isPersonalMembership(membership) ? "Personal" : membership.organizationName)."

        Task {
            await loadDashboard()
            await loadOrganizationSettingsIfNeeded(force: true)
        }
    }

    private func openAssociationClub(_ membership: UserMembership) {
        if membership.organizationID != session?.organizationID {
            switchAssociation(to: membership)
        }
        associationClubRoute = AssociationClubRoute(membership: membership)
    }

    private func isPersonalMembership(_ membership: UserMembership) -> Bool {
        membership.organizationType?.lowercased() == "personal" || membership.organizationID >= 50_000
    }

    private func roleDisplayName(for role: String) -> String {
        switch role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "admin":
            return "Administrator"
        case "scorer", "user":
            return "Scorer"
        case "read_only", "readonly":
            return "Read only"
        default:
            return role.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func presentTransientNotice(_ message: String) {
        transientNoticeTask?.cancel()
        transientNotice = message
        transientNoticeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            transientNotice = nil
        }
    }

    private func seedHelpDefaults() {
        if feedbackName.isEmpty {
            feedbackName = session?.fullName ?? session?.username ?? ""
        }
        if feedbackEmail.isEmpty {
            feedbackEmail = session?.email ?? ""
        }
        if resetEmail.isEmpty {
            resetEmail = session?.email ?? ""
        }
    }

    private func matchDisplayName(for match: MatchSummary) -> String {
        let player1 = [match.player1Name, match.player1Surname]
            .compactMap { value in
                guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return value
            }
            .joined(separator: " ")

        let player2 = [match.player2Name, match.player2Surname]
            .compactMap { value in
                guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return value
            }
            .joined(separator: " ")

        return "\(player1) vs \(player2)"
    }

    private func userDisplayName(_ user: OrganizationUser) -> String {
        let name = [user.firstName, user.surname]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return name.isEmpty ? user.username : name
    }

    private func historyWinnerLine(for match: MatchSummary) -> String {
        match.winnerName ?? match.state?.winnerName ?? "Completed match"
    }

    private func historyWinnerSide(for match: MatchSummary) -> Int? {
        let player1Games = match.state?.player1GamesWon ?? 0
        let player2Games = match.state?.player2GamesWon ?? 0

        if player1Games > player2Games {
            return 1
        }
        if player2Games > player1Games {
            return 2
        }

        let winnerName = historyWinnerLine(for: match).lowercased()
        if winnerName == match.player1Name.lowercased() {
            return 1
        }
        if winnerName == match.player2Name.lowercased() {
            return 2
        }

        return nil
    }

    private func historyScoreLine(for match: MatchSummary) -> String {
        let player1Games = match.state?.player1GamesWon ?? 0
        let player2Games = match.state?.player2GamesWon ?? 0
        let completedGameScores = (match.state?.gameHistory ?? [])
            .map { "\($0.player1Score)-\($0.player2Score)" }
            .joined(separator: " | ")
        let fallbackScore = "\(match.state?.player1Score ?? 0)-\(match.state?.player2Score ?? 0)"
        let scoreSeries = completedGameScores.isEmpty ? fallbackScore : completedGameScores
        return "\(player1Games)-\(player2Games) [\(scoreSeries)]"
    }

    private func historyFinalScoreLine(for match: MatchSummary) -> String {
        let player1Games = match.state?.player1GamesWon ?? 0
        let player2Games = match.state?.player2GamesWon ?? 0
        return "\(player1Games)-\(player2Games)"
    }

    private func currentScoreLine(for match: MatchSummary) -> String {
        let player1GamesWon = match.state?.player1GamesWon ?? 0
        let player2GamesWon = match.state?.player2GamesWon ?? 0
        return "\(player1GamesWon) - \(player2GamesWon)"
    }

    private func sportDisplayName(_ value: String?) -> String {
        switch (value ?? "squash").lowercased() {
        case "racketball": return "Racketball"
        case "tennis": return "Tennis"
        case "padel": return "Padel"
        case "table_tennis": return "Table Tennis"
        case "badminton": return "Badminton"
        case "pickleball": return "Pickleball"
        default: return "Squash"
        }
    }

    private func splitPlayerName(_ firstName: String, surname: String?) -> (firstName: String, surname: String) {
        ((firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Player" : firstName), surname ?? "")
    }

    private func formattedMatchDate(for match: MatchSummary) -> String {
        if let completedAt = match.completedAt, !completedAt.isEmpty {
            return formatDateOnly(completedAt)
        }
        if let updatedAt = match.updatedAt, !updatedAt.isEmpty {
            return formatDateOnly(updatedAt)
        }
        return "Unknown date"
    }

    private func recentMatchDateParts(for match: MatchSummary) -> (day: String, month: String) {
        let rawValue: String
        if let completedAt = match.completedAt, !completedAt.isEmpty {
            rawValue = completedAt
        } else if let updatedAt = match.updatedAt, !updatedAt.isEmpty {
            rawValue = updatedAt
        } else {
            return ("--", "Unknown")
        }

        guard let date = parsedISODate(rawValue) else {
            return ("--", "Unknown")
        }

        return (
            DateFormatter.dashboardRecentDay.string(from: date),
            DateFormatter.dashboardRecentMonth.string(from: date)
        )
    }

    private func recentPlayersLine(player1: String, player2: String, winnerSide: Int?) -> some View {
        let player1Color = winnerSide == 1 ? Color.dashboardAccentPink : Color.dashboardInk
        let player2Color = winnerSide == 2 ? Color.dashboardAccentPink : Color.dashboardInk

        return HStack(spacing: 0) {
            Text(player1)
                .foregroundStyle(player1Color)
            Text(" vs ")
                .foregroundStyle(Color.secondary)
            Text(player2)
                .foregroundStyle(player2Color)
        }
    }

    private func formatDateOnly(_ value: String) -> String {
        guard let date = parsedISODate(value) else {
            return value
        }

        return DateFormatter.dashboardDateOnly.string(from: date)
    }

    private func formatDate(_ value: String) -> String {
        guard let date = parsedISODate(value) else {
            return value
        }

        return DateFormatter.dashboardSummary.string(from: date)
    }

    private func parsedISODate(_ value: String) -> Date? {
        if let date = ISO8601DateFormatter.dashboardWithFractionalSeconds.date(from: value) {
            return date
        }

        return ISO8601DateFormatter.dashboardStandard.date(from: value)
    }

    private func isValidEmail(_ value: String) -> Bool {
        let emailPattern = "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"
        return value.range(of: emailPattern, options: .regularExpression) != nil
    }

    private func normalizeSelectedSettingsMenuItem() {
        if !settingsAvailableItems.contains(where: { $0.section == selectedSettingsSection }) {
            selectedSettingsSection = settingsAvailableItems.first?.section ?? .subscription
        }
    }

    private func loadSelectedProfilePhoto() async {
        guard let photoItem = selectedProfilePhotoItem else {
            return
        }

        do {
            guard let source = try await photoItem.loadTransferable(type: Data.self) else { return }
            guard source.count <= 5 * 1024 * 1024 else {
                throw ProfileImagePreparationError.message("Choose an image no larger than 5 MB.")
            }
            guard let jpeg = preparedProfileJPEG(source) else {
                throw ProfileImagePreparationError.message("Choose an image that is at least 256 × 256 pixels.")
            }
            guard let organizationID = personalProfileOrganizationID else { return }
            await MainActor.run {
                profileImageBusy = true
                selectedProfilePhotoData = jpeg
            }
            let upload = try await container.apiClient.beginProfileImageUpload(organizationID: organizationID)
            try await container.apiClient.uploadProfileImageJPEG(jpeg, using: upload)
            let image = try await container.apiClient.completeProfileImageUpload(
                organizationID: organizationID,
                objectKey: upload.objectKey
            )
            await MainActor.run {
                profileImageURL = image.url
                profileImageBusy = false
                selectedProfilePhotoItem = nil
                dashboardNotice = "Your profile photo is now shared across HitnScore clients."
            }
        } catch {
            await MainActor.run {
                profileImageBusy = false
                selectedProfilePhotoItem = nil
                dashboardNotice = (error as? ProfileImagePreparationError)?.message ?? (error as? APIErrorResponse)?.message ?? "Unable to update that profile photo."
            }
        }
    }

    private func loadCentralProfileImage() async {
        guard let organizationID = personalProfileOrganizationID, isOnline else { return }
        if let image = try? await container.apiClient.getProfileImage(organizationID: organizationID) {
            await MainActor.run { profileImageURL = image.url }
        }
    }

    private func removeCentralProfileImage() async {
        guard let organizationID = personalProfileOrganizationID else { return }
        await MainActor.run { profileImageBusy = true }
        do {
            try await container.apiClient.deleteProfileImage(organizationID: organizationID)
            await MainActor.run {
                selectedProfilePhotoData = nil
                profileImageURL = nil
                profileImageBusy = false
                dashboardNotice = "Your profile photo has been removed from every HitnScore client."
            }
        } catch {
            await MainActor.run {
                profileImageBusy = false
                dashboardNotice = (error as? APIErrorResponse)?.message ?? "Unable to remove your profile photo."
            }
        }
    }

    private func preparedProfileJPEG(_ source: Data) -> Data? {
        guard let image = UIImage(data: source) else { return nil }
        let width = image.size.width * image.scale
        let height = image.size.height * image.scale
        guard min(width, height) >= 256 else { return nil }
        let side = min(image.size.width, image.size.height)
        let crop = CGRect(
            x: (image.size.width - side) / 2,
            y: (image.size.height - side) / 2,
            width: side,
            height: side
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512), format: format).image { context in
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
            image.draw(
                in: CGRect(
                    x: -crop.minX * (512 / side),
                    y: -crop.minY * (512 / side),
                    width: image.size.width * (512 / side),
                    height: image.size.height * (512 / side)
                )
            )
        }
        return rendered.jpegData(compressionQuality: 0.85)
    }

    private func profileAvatarView(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.dashboardAccentPink.opacity(0.9),
                            Color.dashboardBrand.opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let selectedProfileImage {
                selectedProfileImage
                    .resizable()
                    .scaledToFill()
            } else if let profileImageURL {
                AsyncImage(url: profileImageURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        Text(personalIdentityInitials)
                            .font(.system(size: size * 0.34, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            } else {
                Text(personalIdentityInitials)
                    .font(.system(size: size * 0.34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: 3)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
    }

    private func sportEnabledBinding(for sport: MatchSport) -> Binding<Bool> {
        Binding(
            get: { sport.isImplementedToday && enabledSportIDs.contains(sport.rawValue) },
            set: { isEnabled in
                guard sport.isImplementedToday else { return }
                setSportEnabled(sport, isEnabled: isEnabled)
            }
        )
    }

    private func setSportEnabled(_ sport: MatchSport, isEnabled: Bool) {
        var enabledIDs = enabledSportIDs
        if isEnabled {
            enabledIDs.insert(sport.rawValue)
        } else {
            enabledIDs.remove(sport.rawValue)
        }

        enabledSportsDraft = availableSportOptions
            .map(\.rawValue)
            .filter { enabledIDs.contains($0) }
    }

    private func normalizedEnabledSportsDraft() -> [String] {
        availableSportOptions
            .filter(\.isImplementedToday)
            .map(\.rawValue)
            .filter { enabledSportIDs.contains($0) }
    }

    private func persistSessionEnabledSports(_ enabledSports: [String]) {
        guard let currentSession = session else {
            return
        }

        let updatedMemberships = currentSession.availableMemberships?.map { membership in
            guard membership.organizationID == currentSession.organizationID else {
                return membership
            }

            return UserMembership(
                id: membership.id,
                username: membership.username,
                role: membership.role,
                organizationID: membership.organizationID,
                organizationName: membership.organizationName,
                organizationType: membership.organizationType,
                plan: membership.plan,
                enabledSports: enabledSports,
                firstName: membership.firstName,
                surname: membership.surname,
                fullName: membership.fullName,
                email: membership.email,
                country: membership.country,
                telephone: membership.telephone
            )
        }

        let updatedSession = UserSession(
            id: currentSession.id,
            username: currentSession.username,
            role: currentSession.role,
            sessionToken: currentSession.sessionToken,
            sessionExpiresAt: currentSession.sessionExpiresAt,
            organizationID: currentSession.organizationID,
            organizationName: currentSession.organizationName,
            organizationType: currentSession.organizationType,
            plan: currentSession.plan,
            enabledSports: enabledSports,
            firstName: currentSession.firstName,
            surname: currentSession.surname,
            fullName: currentSession.fullName,
            email: currentSession.email,
            country: currentSession.country,
            telephone: currentSession.telephone,
            availableMemberships: updatedMemberships
        )
        container.sessionStore.save(updatedSession)
    }

    private func persistSessionProfile(
        firstName: String,
        surname: String,
        email: String,
        country: String,
        telephone: String
    ) {
        guard let currentSession = session else {
            return
        }

        let fullName = [firstName, surname].filter { !$0.isEmpty }.joined(separator: " ")
        let updatedMemberships = currentSession.availableMemberships?.map { membership in
            UserMembership(
                id: membership.id,
                username: email,
                role: membership.role,
                organizationID: membership.organizationID,
                organizationName: membership.organizationName,
                organizationType: membership.organizationType,
                plan: membership.plan,
                enabledSports: membership.enabledSports,
                firstName: firstName,
                surname: surname,
                fullName: fullName,
                email: email,
                country: country,
                telephone: telephone
            )
        }

        let updatedSession = UserSession(
            id: currentSession.id,
            username: email,
            role: currentSession.role,
            sessionToken: currentSession.sessionToken,
            sessionExpiresAt: currentSession.sessionExpiresAt,
            organizationID: currentSession.organizationID,
            organizationName: currentSession.organizationName,
            organizationType: currentSession.organizationType,
            plan: currentSession.plan,
            enabledSports: currentSession.enabledSports,
            firstName: firstName,
            surname: surname,
            fullName: fullName,
            email: email,
            country: country,
            telephone: telephone,
            availableMemberships: updatedMemberships
        )
        container.sessionStore.save(updatedSession)
    }

    private func planDisplayName(for plan: String) -> String {
        switch plan.lowercased() {
        case "personal_plus":
            return "Personal Plus"
        case "personal_free":
            return "Personal Free"
        case "club_pro":
            return "Club Pro"
        case "club_essentials":
            return "Club Essentials"
        default:
            return plan.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

private enum ClubSubscriptionPlan: String, Identifiable {
    case essentials = "club_essentials"
    case pro = "club_pro"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .essentials:
            return "Club Essentials"
        case .pro:
            return "Club Pro"
        }
    }
}

private struct ClubSubscriptionEnquiryDraft {
    var clubName = ""
    var clubAddress = ""
    var clubPostcode = ""
    var clubEmail = ""
    var clubWebsite = ""
    var clubTelephone = ""
}

private struct MatchRoute: Hashable, Identifiable {
    let id: String
    var presentation: MatchPresentation = .live(openSettingsOnLoad: false)
}

private enum MatchPresentation: Hashable {
    case live(openSettingsOnLoad: Bool)
    case historic
}

private enum DashboardSheet: Identifiable {
    case newMatch
    case watchMatch(String)

    var id: String {
        switch self {
        case .newMatch:
            return "new-match"
        case .watchMatch(let code):
            return "watch-match-\(code)"
        }
    }
}

private enum DashboardTab: String, CaseIterable, Identifiable {
    case home
    case matches
    case history
    case performance
    case settings
    case help

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .matches:
            return "Matches"
        case .history:
            return "History"
        case .performance:
            return "Analytics"
        case .settings:
            return "Settings"
        case .help:
            return "Need Help"
        }
    }

    var icon: String {
        switch self {
        case .home:
            return "house.fill"
        case .matches:
            return "calendar.badge.clock"
        case .history:
            return "clock"
        case .performance:
            return "chart.xyaxis.line"
        case .settings:
            return "gearshape"
        case .help:
            return "questionmark.circle"
        }
    }
}

private enum MatchesCategory: String, CaseIterable, Identifiable {
    case current
    case scheduled
    case history

    var id: String { rawValue }
    var title: String {
        switch self {
        case .current: return "Current"
        case .scheduled: return "Scheduled"
        case .history: return "History"
        }
    }
}

private enum AnalyticsCategory: String, CaseIterable, Identifiable {
    case personal
    case club

    var id: String { rawValue }
    var title: String { self == .personal ? "Personal" : "Club" }
}

private enum ProfileImagePreparationError: Error {
    case message(String)

    var message: String {
        switch self {
        case .message(let value): value
        }
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case subscription
    case profile
    case association
    case racketSports
    case gameSettings
    case about
    case helpFeedback
    case reporting
    case organisation
    case orgSettings
    case users
    case courts

    var id: String { rawValue }
}

private enum AccountDeletionPrompt: String, Identifiable {
    case first
    case final

    var id: String { rawValue }
}

private enum SettingsMenuItem: String, CaseIterable, Identifiable {
    case subscription
    case profile
    case association
    case racketSports
    case gameSettings
    case about
    case helpFeedback
    case reporting
    case organisation
    case orgSettings
    case users
    case courts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .subscription:
            return "Subscription"
        case .profile:
            return "Profile"
        case .association:
            return "Association"
        case .racketSports:
            return "Club Settings"
        case .gameSettings:
            return "Game Settings"
        case .about:
            return "About"
        case .helpFeedback:
            return "Help & Feedback"
        case .reporting:
            return "Reporting"
        case .organisation:
            return "Organisation"
        case .orgSettings:
            return "Org Settings"
        case .users:
            return "Users"
        case .courts:
            return "Courts"
        }
    }

    var icon: String {
        switch self {
        case .subscription:
            return "creditcard"
        case .profile:
            return "person.crop.circle"
        case .association:
            return "person.2.wave.2"
        case .racketSports:
            return "sportscourt"
        case .gameSettings:
            return "slider.horizontal.3"
        case .about:
            return "info.circle"
        case .helpFeedback:
            return "bubble.left.and.bubble.right"
        case .reporting:
            return "chart.bar.xaxis"
        case .organisation:
            return "building.2"
        case .orgSettings:
            return "gearshape.2"
        case .users:
            return "person.3"
        case .courts:
            return "square.grid.2x2"
        }
    }

    var section: SettingsSection {
        switch self {
        case .subscription:
            return .subscription
        case .profile:
            return .profile
        case .association:
            return .association
        case .racketSports:
            return .racketSports
        case .gameSettings:
            return .gameSettings
        case .about:
            return .about
        case .helpFeedback:
            return .helpFeedback
        case .reporting:
            return .reporting
        case .organisation:
            return .organisation
        case .orgSettings:
            return .orgSettings
        case .users:
            return .users
        case .courts:
            return .courts
        }
    }
}

private struct SettingsMenuSectionDescriptor: Identifiable {
    let title: String?
    let items: [SettingsMenuItem]

    var id: String {
        if let title {
            return title
        }
        return items.map(\.rawValue).joined(separator: "-")
    }
}

private struct AssociationClubRoute: Identifiable, Hashable {
    let membership: UserMembership

    var id: Int { membership.organizationID }
}

private extension DateFormatter {
    static let dashboardSummary: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let dashboardDateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let dashboardRecentDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter
    }()

    static let dashboardRecentMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }()
}

private extension ISO8601DateFormatter {
    static let dashboardWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let dashboardStandard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private extension Color {
    static let dashboardBrand = Color(red: 18 / 255, green: 116 / 255, blue: 208 / 255)
    static let dashboardBrandDeep = Color(red: 15 / 255, green: 87 / 255, blue: 194 / 255)
    static let dashboardAccentPink = Color(red: 236 / 255, green: 94 / 255, blue: 168 / 255)
    static let dashboardInk = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.white
                : UIColor(red: 20 / 255, green: 31 / 255, blue: 45 / 255, alpha: 1)
        }
    )
    static let dashboardBackgroundStart = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 14 / 255, green: 22 / 255, blue: 33 / 255, alpha: 1)
                : UIColor(red: 233 / 255, green: 242 / 255, blue: 250 / 255, alpha: 1)
        }
    )
    static let dashboardBackgroundEnd = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 9 / 255, green: 16 / 255, blue: 24 / 255, alpha: 1)
                : UIColor(red: 245 / 255, green: 248 / 255, blue: 252 / 255, alpha: 1)
        }
    )
    static let dashboardHeroBackground = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 20 / 255, green: 31 / 255, blue: 45 / 255, alpha: 1)
                : UIColor(red: 248 / 255, green: 251 / 255, blue: 255 / 255, alpha: 1)
        }
    )
    static let dashboardTabBarBackground = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 12 / 255, green: 20 / 255, blue: 29 / 255, alpha: 0.98)
                : UIColor.white.withAlphaComponent(0.98)
        }
    )
    static let dashboardTabMuted = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.systemGray3
                : UIColor(red: 76 / 255, green: 92 / 255, blue: 120 / 255, alpha: 1)
        }
    )
    static let dashboardCardBackground = Color(UIColor.secondarySystemGroupedBackground)
    static let dashboardInnerCardBackground = Color(UIColor.tertiarySystemGroupedBackground)
    static let dashboardInputBackground = Color(UIColor.systemBackground)
    static let dashboardMutedStatus = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.systemGray3
                : UIColor.systemGray2
        }
    )
    static let dashboardActiveStatus = Color(red: 82 / 255, green: 205 / 255, blue: 120 / 255)
    static let dashboardCompletedStatus = Color(red: 196 / 255, green: 68 / 255, blue: 92 / 255)
    static let dashboardBorder = Color(
        UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor.white.withAlphaComponent(0.08)
            }

            return UIColor(
                red: 217 / 255,
                green: 226 / 255,
                blue: 236 / 255,
                alpha: 1
            )
        }
    )
}
