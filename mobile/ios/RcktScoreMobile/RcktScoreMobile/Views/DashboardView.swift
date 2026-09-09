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
    @State private var performanceSummary: PersonalPerformanceSummary?
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
    @State private var enabledSportsDraft: [String] = []
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
    @State private var isUpdatingBiometricUnlock = false
    @State private var accountDeletionPrompt: AccountDeletionPrompt?
    @State private var isDeletingAccount = false
    @State private var showsNotifications = false
    @State private var notifications: [AppNotification] = []
    @State private var notificationErrorMessage: String?
    @State private var selectedMatchesCategory: MatchesCategory = .current
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
    private var isAdmin: Bool { session?.role.lowercased() == "admin" }
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
    private var homeRecentMatches: [MatchSummary] { Array(recentMatches.prefix(3)) }
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
        if isPersonalPlus {
            return [.home, .matches, .performance, .settings, .help]
        }
        return DashboardTab.allCases.filter { $0 != .performance }
    }
    private var bottomNavigationIconSize: CGFloat {
        usesCompactBottomNavigation ? 18 : 22
    }
    private var bottomNavigationFont: Font {
        usesCompactBottomNavigation ? .system(size: 10, weight: .medium) : .caption
    }
    private var personalSettingsItems: [SettingsMenuItem] {
        var items: [SettingsMenuItem] = [.about, .profile, .subscription, .association, .racketSports, .gameSettings]
        if isPersonalPlus {
            items.append(.reporting)
        }
        items.append(.helpFeedback)
        return items
    }
    private var clubSettingsPrimaryItems: [SettingsMenuItem] {
        [.about, .profile, .subscription, .association, .racketSports, .gameSettings, .reporting, .helpFeedback]
    }
    private var settingsMenuSections: [SettingsMenuSectionDescriptor] {
        if isPersonalAccount {
            return [
                SettingsMenuSectionDescriptor(title: nil, items: personalSettingsItems)
            ]
        }

        return [
            SettingsMenuSectionDescriptor(title: "Account", items: clubSettingsPrimaryItems),
            SettingsMenuSectionDescriptor(title: "Club Admin", items: [.organisation, .orgSettings, .users, .courts])
        ]
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: selectedTab == .settings ? 12 : 22) {
                    headerSection

                    if selectedTab == .home {
                        startNewMatchHero
                    }

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
                        StartNewMatchFlowView(activeMatches: activeMatches) { result in
                            handleStartNewMatchResult(result)
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
            .refreshable { await loadDashboard() }
            .alert(item: $accountDeletionPrompt) { prompt in
                accountDeletionAlert(for: prompt)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 82, height: 82)
                    .offset(y: -9)

                VStack(alignment: .leading, spacing: 3) {
                    (
                        Text("Hit")
                            .foregroundStyle(Color.dashboardBrand)
                        + Text("n")
                            .foregroundStyle(Color.dashboardAccentPink)
                        + Text("Score")
                            .foregroundStyle(Color.dashboardBrand)
                    )
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 2)

                VStack(alignment: .trailing, spacing: 12) {
                    Button {
                        guard isOnline else { return }
                        showsNotifications = true
                    } label: {
                        Image(systemName: isOnline ? (hasUnreadNotifications ? "bell.fill" : "bell") : "wifi.slash")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(
                                isOnline
                                    ? (hasUnreadNotifications ? Color.yellow : Color.white)
                                    : Color.orange
                            )
                            .shadow(
                                color: isOnline && hasUnreadNotifications ? Color.yellow.opacity(0.9) : .clear,
                                radius: 8
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isOnline ? "Notifications" : "Offline")
                    .accessibilityIdentifier(isOnline ? "dashboard.notificationButton" : "dashboard.offlineIndicator")
                    .disabled(!isOnline)
                }
                .padding(.top, 8)
            }

            if let dashboardNotice {
                Text(dashboardNotice)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var startNewMatchHero: some View {
        Button {
            activeSheet = .newMatch
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(Color.dashboardBrand)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Start New Match")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color.dashboardBrand,
                        Color.dashboardBrandDeep
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(
                color: colorScheme == .dark ? .clear : Color.black.opacity(0.12),
                radius: 12,
                x: 0,
                y: 8
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dashboard.startNewMatchButton")
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
            if isPersonalPlus {
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
            }

            if isPersonalPlus && selectedMatchesCategory == .history {
                historyContent
            } else {
                dashboardSection(
                    title: "Matches",
                    subtitle: isPersonalAccount
                        ? "Your live and upcoming matches in one place."
                        : "All active courts first, then scheduled matches below."
                ) {
                    VStack(spacing: 18) {
                        matchesSubsection(title: "Active Matches", icon: "dot.radiowaves.left.and.right") {
                            activeMatchesContent(matches: activeMatches)
                        }

                        if !isPersonalAccount {
                            matchesSubsection(title: "Scheduled Matches", icon: "calendar.badge.clock") {
                                scheduledMatchesContent(matches: scheduledMatches)
                            }
                        }
                    }
                }
            }
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
            dashboardSection(
                title: "Performance",
                systemImage: "chart.xyaxis.line",
                subtitle: "Results, court time, serving and progress across your sports."
            ) {
                if !isPersonalPlus {
                    upgradePerformanceCard
                } else if isLoading && performanceSummary == nil {
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
                    emptyState("No completed matches are available for performance reporting yet.")
                }
            }
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

                    if let settingsSuccessMessage {
                        dashboardInlineSuccess(settingsSuccessMessage)
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
            settingsSummaryCard

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

            Text(currentUserDisplayName)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            if let email = session?.email, !email.isEmpty {
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
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
        Button {
            selectedSettingsSection = item.section
            settingsNavigationItem = item
        } label: {
            HStack(spacing: 14) {
                settingsMenuIconView(for: item)

                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle()
                        .fill(Color.dashboardBorder.opacity(0.9))
                        .frame(height: 1)
                        .padding(.leading, 54)
                }
            }
        }
        .buttonStyle(.plain)
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
                sportSetupCard
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

                if let settingsSuccessMessage {
                    dashboardInlineSuccess(settingsSuccessMessage)
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

    private var subscriptionSettingsCard: some View {
        let freeHistoryLimit = organizationSummary?.availablePlanEntitlements["personal_free"]?.historyLimit
            ?? organizationSettings?.organization.availablePlanEntitlements["personal_free"]?.historyLimit
            ?? 3
        let plusHistoryLimit = organizationSummary?.availablePlanEntitlements["personal_plus"]?.historyLimit
            ?? organizationSettings?.organization.availablePlanEntitlements["personal_plus"]?.historyLimit
            ?? 100
        let planCards: [(title: String, subtitle: String, isCurrent: Bool, enquiryPlan: ClubSubscriptionPlan?)] = isPersonalAccount
            ? [
                ("Personal", "Core scoring with your latest \(freeHistoryLimit) completed matches.", !isPersonalPlus, nil),
                ("Personal Plus", "\(plusHistoryLimit) completed matches plus performance, opponent, serving, streak and progress insights.", isPersonalPlus, nil),
                ("Club Essentials", "Club management with courts, users, and match operations.", false, .essentials),
                ("Club Pro", "Expanded club package with higher-tier operational tooling.", false, .pro)
            ]
            : [
                ("Club Essentials", "Core club package for match operations and member management.", (session?.plan ?? "").lowercased() == "club_essentials", .essentials),
                ("Club Pro", "Higher-tier club package for advanced reporting and expansion.", (session?.plan ?? "").lowercased() == "club_pro", .pro)
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
            guard isPersonalAccount else { return }
            await container.purchaseService.loadProducts()
            await container.purchaseService.refreshCurrentEntitlements()
        }
        .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
        .onChange(of: showsManageSubscriptions) { _, isPresented in
            guard !isPresented else { return }
            Task {
                await container.purchaseService.refreshCurrentEntitlements()
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

            if purchaseService.canRunLocalPurchases && !isPersonalPlus {
                Text("Choose Personal Plus")
                    .font(.subheadline.weight(.bold))

                ForEach(purchaseService.products, id: \.id) { product in
                    Button {
                        Task {
                            await purchaseService.purchase(product)
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

                Text("Local StoreKit testing only — completing a test purchase does not change the Hit n Score account plan yet.")
                    .font(.caption)
                    .foregroundStyle(.orange)
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
                        Task { await purchaseService.restorePurchases() }
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

            dashboardTextField(title: "First Name", placeholder: "First name", text: $personalProfileDraft.firstName, accessibilityIdentifier: "settings.profile.firstNameField")
            dashboardTextField(title: "Surname", placeholder: "Surname", text: $personalProfileDraft.surname, accessibilityIdentifier: "settings.profile.surnameField")
            dashboardTextField(title: "Email", placeholder: "you@example.com", text: $personalProfileDraft.email, keyboardType: .emailAddress, accessibilityIdentifier: "settings.profile.emailField")
            dashboardTextField(title: "Telephone", placeholder: "Telephone", text: $personalProfileDraft.telephone, keyboardType: .phonePad, accessibilityIdentifier: "settings.profile.telephoneField")
            dashboardTextField(title: "Country of Origin", placeholder: "Country", text: $personalProfileDraft.country, accessibilityIdentifier: "settings.profile.countryField")

            Button(currentSettingsButtonTitle(for: "profile-save", defaultTitle: "Save Profile")) {
                savePersonalProfile()
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

            VStack(spacing: 10) {
                Button(isRequestingPasswordReset ? "Sending..." : "Password Reset") {
                    resetEmail = personalProfileDraft.email.isEmpty ? (session?.email ?? resetEmail) : personalProfileDraft.email
                    requestPasswordReset()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.dashboardBrand.opacity(0.9))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(isRequestingPasswordReset || personalProfileDraft.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity((isRequestingPasswordReset || personalProfileDraft.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.7 : 1)
                .accessibilityIdentifier("settings.profile.passwordResetButton")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 14)

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

            if let resetMessage {
                dashboardInlineSuccess(resetMessage)
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
            Text("Association")
                .font(.headline.weight(.semibold))

            if availableMemberships.count > 1 {
                Text("Choose which club or account you want to work in for this session.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(availableMemberships) { membership in
                    associationMembershipRow(membership)
                }
            } else {
                settingsValueRow(title: "Account Type", value: isPersonalAccount ? "Personal" : "Club")
                settingsValueRow(title: "Organisation", value: settingsOrganizationName)
                settingsValueRow(title: "Tier", value: settingsPlanLine)

                Text("This login currently has access to a single account.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

            Text("Match format controls remain tied to the sport and setup flow you choose when starting a new match. Broader account presets will live here as the settings model expands.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    SecureField("Required for new users", text: $newOrganizationUserDraft.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.dashboardInputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.dashboardBorder, lineWidth: 1)
                        )
                        .accessibilityIdentifier("settings.users.new.passwordField")
                }
                .disabled(!isAdmin)

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

            Text("Choose which racket sports club users can see when they start a match.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(availableSportOptions) { sport in
                sportAccessRow(for: sport)
            }

            Text("Implemented sports are available in the current iOS setup flow. Other sports can be pre-configured here for later release.")
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
        .disabled(!isAdmin)
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

            if user.canEditPassword {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    SecureField("Optional password change", text: binding.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.dashboardInputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.dashboardBorder, lineWidth: 1)
                        )
                        .accessibilityIdentifier("settings.users.\(user.id).passwordField")
                }
                .disabled(!isAdmin)
            }

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
                Text("User").tag("user")
                Text("Admin").tag("admin")
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
                subtitle: "Send feedback or request a password reset without leaving the app."
            ) {
                VStack(spacing: 14) {
                    feedbackForm
                    resetForm
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
                    text: "An unexpired login session may be stored in the iOS Keychain when biometric login is enabled. One active match and its queued scoring actions may be stored temporarily on the device for offline use. A selected profile photograph currently remains local to the device. Face ID and Touch ID templates are managed by Apple and are never received or stored by Hit n Score."
                )
                privacySection(
                    title: "Retention and deletion",
                    text: "Account data is retained while the account is active and only as long as reasonably necessary for service, security, legal and operational purposes. Personal-account owners can permanently delete their account from Profile settings. Deletion removes the personal account, its owned matches and scoring records, its signup record and active sessions, except for limited information that must be retained by law or in time-limited backups."
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
                message: Text("This will permanently remove your personal account, matches and scoring history. This action cannot be undone."),
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
                message: Text("Your account and its data will be permanently deleted now."),
                primaryButton: .destructive(Text("Delete Permanently")) {
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

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                if let courtName = match.courtName, !courtName.isEmpty {
                    Text(courtName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Ready to start")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dashboardBrand)
            }

            HStack(alignment: .center, spacing: 12) {
                playerColumn(firstName: player1.firstName, surname: player1.surname, alignment: .leading)

                Spacer(minLength: 4)

                VStack(spacing: 4) {
                    Text(match.courtName ?? "Court")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dashboardInk.opacity(0.64))
                    Text("Best of \(match.bestOf ?? 3)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                playerColumn(firstName: player2.firstName, surname: player2.surname, alignment: .trailing)

                VStack(spacing: 8) {
                    Button(startingScheduledMatchID == match.id ? "Starting..." : "Start") {
                        action()
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.dashboardBrand)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                    .disabled(startingScheduledMatchID != nil)
                    .opacity(startingScheduledMatchID != nil ? 0.7 : 1)

                    Button("Edit") {
                        navigationTarget = MatchRoute(id: match.id, presentation: .live(openSettingsOnLoad: true))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dashboardBrand)
                    .buttonStyle(.plain)
                }
            }

            if let updatedAt = match.updatedAt {
                Text("Scheduled \(formatDate(updatedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                }

                Spacer(minLength: 4)

                VStack(spacing: 0) {
                    Text("\(player1Games)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.dashboardBrand)
                    Text("\(player2Games)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.dashboardBrand)
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

    private var settingsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(settingsOrganizationName)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Text(settingsPlanLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.dashboardBrand)

            HStack(spacing: 12) {
                settingsMetric(title: "Courts", value: String(organizationSummary?.courtCount ?? organizationSettings?.courts.count ?? 0))
                settingsMetric(title: "Users", value: String(organizationSummary?.userCount ?? organizationSettings?.users.count ?? 0))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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

            if let feedbackSuccessMessage {
                dashboardInlineSuccess(feedbackSuccessMessage)
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

            if let resetMessage {
                dashboardInlineSuccess(resetMessage)
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

    private func settingsMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func settingsMenuIconView(for item: SettingsMenuItem) -> some View {
        if item == .racketSports {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.dashboardBrand.opacity(0.12))
                    .frame(width: 24, height: 24)

                settingsRacketGlyph
            }
            .frame(width: 24, height: 24)
        } else {
            Image(systemName: item.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.secondary)
                .frame(width: 24)
        }
    }

    private var settingsRacketGlyph: some View {
        ZStack {
            Circle()
                .stroke(Color.dashboardBrand, lineWidth: 1.8)
                .frame(width: 11, height: 13)
                .offset(x: -1.5, y: -2.5)

            RoundedRectangle(cornerRadius: 1.4, style: .continuous)
                .fill(Color.dashboardBrand)
                .frame(width: 2.4, height: 8.5)
                .rotationEffect(.degrees(-32))
                .offset(x: 4.5, y: 4.6)
        }
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
        let isCurrent = membership.organizationID == session?.organizationID

        return Button {
            switchAssociation(to: membership)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(membership.organizationName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(planDisplayName(for: membership.plan ?? (membership.organizationType == "personal" ? "personal_free" : "club_essentials")))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(isCurrent ? "Current" : "Switch")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isCurrent ? Color.dashboardBrand : Color.dashboardAccentPink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((isCurrent ? Color.dashboardBrand : Color.dashboardAccentPink).opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.dashboardInputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isCurrent)
        .opacity(isCurrent ? 0.92 : 1)
        .accessibilityIdentifier("settings.association.\(membership.organizationID)")
    }

    @ViewBuilder
    private func racketSportGlyph(for sport: MatchSport, isAvailable: Bool) -> some View {
        let foreground = isAvailable ? Color.dashboardBrand : Color.secondary.opacity(0.72)

        switch sport {
        case .squash:
            ZStack {
                Circle()
                    .stroke(foreground, lineWidth: 2.2)
                    .frame(width: 16, height: 16)
                Circle()
                    .fill(foreground)
                    .frame(width: 4, height: 4)
                    .offset(x: 3, y: -3)
            }
        case .racketball:
            ZStack {
                Circle()
                    .fill(foreground)
                    .frame(width: 16, height: 16)
                Circle()
                    .fill(Color.dashboardAccentPink)
                    .frame(width: 3.5, height: 3.5)
                    .offset(x: -3, y: -3)
                Circle()
                    .fill(Color.dashboardAccentPink)
                    .frame(width: 3.5, height: 3.5)
                    .offset(x: 3, y: 3)
            }
        case .tennis, .padel:
            ZStack {
                Circle()
                    .stroke(foreground, lineWidth: 2.1)
                    .frame(width: 18, height: 18)
                Path { path in
                    path.move(to: CGPoint(x: 14, y: 8))
                    path.addQuadCurve(to: CGPoint(x: 14, y: 24), control: CGPoint(x: 8, y: 16))
                    path.move(to: CGPoint(x: 26, y: 8))
                    path.addQuadCurve(to: CGPoint(x: 26, y: 24), control: CGPoint(x: 20, y: 16))
                }
                .stroke(foreground, lineWidth: 1.8)
                .frame(width: 34, height: 34)
            }
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
        personalProfileDraft = PersonalProfileDraft(user: profileUser, fallbackSession: session)
        normalizeSelectedSettingsMenuItem()
    }

    private func loadDashboard() async {
        guard let organizationID = container.sessionStore.session?.organizationID else {
            print("DASHBOARD LOAD: missing organization ID in session")
            return
        }

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
            print("DASHBOARD LOAD: requesting organization ID \(organizationID)")
            let dashboard = try await container.apiClient.getDashboard(
                organizationID: organizationID,
                activeLimit: 200,
                recentLimit: 1000
            )
            await MainActor.run {
                organizationSummary = dashboard.organization
                performanceSummary = dashboard.performance
                activeMatches = dashboard.activeMatches
                scheduledMatches = dashboard.scheduledMatches
                recentMatches = dashboard.recentMatches
                isLoading = false
                print(
                    "DASHBOARD LOAD: active=\(dashboard.activeMatches.count) " +
                    "scheduled=\(dashboard.scheduledMatches.count) " +
                    "recent=\(dashboard.recentMatches.count)"
                )
            }
        } catch {
            await MainActor.run {
                print("DASHBOARD LOAD ERROR:", error)
                errorMessage = (error as? APIErrorResponse)?.message ?? "Unable to fetch dashboard data."
                isLoading = false
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
        guard let organizationID = session?.organizationID else {
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
                    cityLocation: ""
                )
                await MainActor.run {
                    organizationSettings = settings
                    syncSettingsDrafts(from: settings)
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
        guard let organizationID = session?.organizationID else {
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
                    organizationSettings = settings
                    syncSettingsDrafts(from: settings)
                    persistSessionEnabledSports(settings.organization.enabledSports)
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
                    draft: draft,
                    allowPasswordChange: user.canEditPassword
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
        settingsSuccessMessage = "Switched to \(membership.organizationName)."
        settingsNavigationItem = nil
        dashboardNotice = nil

        Task {
            await loadDashboard()
            await loadOrganizationSettingsIfNeeded(force: true)
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
        let player1Score = match.state?.player1Score ?? 0
        let player2Score = match.state?.player2Score ?? 0
        return "\(player1Score) - \(player2Score)"
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
        guard let selectedProfilePhotoItem else {
            return
        }

        do {
            if let data = try await selectedProfilePhotoItem.loadTransferable(type: Data.self) {
                await MainActor.run {
                    selectedProfilePhotoData = data
                }
            }
        } catch {
            await MainActor.run {
                dashboardNotice = "Unable to load that profile photo."
            }
        }
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
            } else {
                Text(currentUserInitials)
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
            get: { enabledSportIDs.contains(sport.rawValue) },
            set: { isEnabled in
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
            .map(\.rawValue)
            .filter { enabledSportIDs.contains($0) }
    }

    private func persistSessionEnabledSports(_ enabledSports: [String]) {
        guard let currentSession = session else {
            return
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
            availableMemberships: currentSession.availableMemberships
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

    var id: String {
        switch self {
        case .newMatch:
            return "new-match"
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
            return "Performance"
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
    case history

    var id: String { rawValue }
    var title: String { self == .current ? "Current Matches" : "Match History" }
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
            return "Racket Sports"
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
