import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.colorScheme) private var colorScheme

    @State private var activeMatches: [MatchSummary] = []
    @State private var scheduledMatches: [MatchSummary] = []
    @State private var recentMatches: [MatchSummary] = []
    @State private var organizationSummary: DashboardOrganizationSummary?
    @State private var organizationSettings: OrganizationSettings?
    @State private var isLoading = false
    @State private var isLoadingSettings = false
    @State private var errorMessage: String?
    @State private var settingsErrorMessage: String?
    @State private var startingScheduledMatchID: String?
    @State private var navigationTarget: MatchRoute?
    @State private var activeSheet: DashboardSheet?
    @State private var dashboardNotice: String?
    @State private var selectedTab: DashboardTab = .home
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

    private var session: UserSession? { container.sessionStore.session }
    private var isPersonalAccount: Bool { session?.isPersonalAccount ?? false }
    private var headerPlanLine: String {
        session?.planDisplayName ?? (isPersonalAccount ? "Personal Free" : "Club Essentials")
    }
    private var headerUserLine: String {
        session?.email ?? session?.username ?? ""
    }
    private var homeActiveMatches: [MatchSummary] { Array(activeMatches.prefix(3)) }
    private var homeScheduledMatches: [MatchSummary] { Array(scheduledMatches.prefix(3)) }
    private var homeRecentMatches: [MatchSummary] { Array(recentMatches.prefix(3)) }
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
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
                MatchScoringView(matchID: route.id)
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .newMatch:
                    NavigationStack {
                        StartNewMatchView(activeMatches: activeMatches) { result in
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
            }
            .task(id: selectedTab) {
                seedHelpDefaults()
                if selectedTab == .settings {
                    await loadOrganizationSettingsIfNeeded()
                }
            }
            .refreshable { await loadDashboard() }
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

                    if !headerUserLine.isEmpty {
                        Text(headerUserLine)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.dashboardInk.opacity(0.88))
                            .lineLimit(1)
                    }

                    Text(headerPlanLine)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)

                VStack(alignment: .trailing, spacing: 12) {
                    HStack(spacing: 10) {
                        Button {
                            dashboardNotice = "Notifications are not added yet."
                        } label: {
                            Image(systemName: "bell")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(Color.dashboardInk)
                        }
                        .buttonStyle(.plain)

                        Button("Logout") {
                            Task {
                                await container.logout()
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dashboardBrand)
                    }
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
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(Color.dashboardBrand)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Start New Match")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
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
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(
                color: colorScheme == .dark ? .clear : Color.black.opacity(0.12),
                radius: 16,
                x: 0,
                y: 10
            )
        }
        .buttonStyle(.plain)
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
                subtitle: isPersonalAccount ? "Your current live matches." : "Live matches for your club."
            ) {
                activeMatchesContent(matches: homeActiveMatches)
            }

            quickSwitchRow(
                primaryTitle: "Matches",
                primaryTab: .matches,
                secondaryTitle: "History",
                secondaryTab: .history
            )

            if !isPersonalAccount {
                dashboardSection(
                    title: "Scheduled Matches",
                    subtitle: "Upcoming matches ready to start."
                ) {
                    scheduledMatchesContent(matches: homeScheduledMatches)
                }
            }

            dashboardSection(
                title: "Recent Matches",
                subtitle: recentMatchesSubtitle
            ) {
                recentMatchesContent(matches: homeRecentMatches)
            }
        }
    }

    private var matchesContent: some View {
        VStack(spacing: 18) {
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

    private var historyContent: some View {
        VStack(spacing: 18) {
            dashboardSection(
                title: "Recent Matches",
                subtitle: "Search completed matches by player name, surname, or date."
            ) {
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
            }
        }
    }

    private var settingsContent: some View {
        VStack(spacing: 18) {
            dashboardSection(
                title: "Settings",
                subtitle: "Club and plan details for this signed-in account."
            ) {
                if isLoadingSettings && organizationSettings == nil {
                    HStack {
                        ProgressView()
                        Spacer()
                    }
                } else {
                    VStack(spacing: 14) {
                        if let settingsErrorMessage {
                            dashboardInlineError(settingsErrorMessage)
                        }

                        settingsSummaryCard

                        if let courts = organizationSettings?.courts, !courts.isEmpty {
                            settingsCourtsCard(courts)
                        } else {
                            emptyState("No courts available yet.")
                        }
                    }
                }
            }
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
                }
            }
        }
    }

    private var bottomNavigationBar: some View {
        HStack(spacing: 0) {
            ForEach(DashboardTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22, weight: selectedTab == tab ? .semibold : .regular))

                        Text(tab.title)
                            .font(.caption.weight(selectedTab == tab ? .semibold : .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedTab == tab ? Color.dashboardBrand : Color.dashboardTabMuted)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
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
        if isLoading && matches.isEmpty {
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
        if isLoading && matches.isEmpty {
            HStack {
                ProgressView()
                Spacer()
            }
        } else if matches.isEmpty {
            emptyState(emptyMessage)
        } else {
            VStack(spacing: 12) {
                ForEach(matches) { match in
                    Button {
                        navigationTarget = MatchRoute(id: match.id)
                    } label: {
                        recentMatchCard(match)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func dashboardSection<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

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

    private func quickSwitchRow(
        primaryTitle: String,
        primaryTab: DashboardTab,
        secondaryTitle: String,
        secondaryTab: DashboardTab
    ) -> some View {
        HStack(spacing: 12) {
            dashboardMiniAction(title: primaryTitle, systemImage: primaryTab.icon) {
                selectedTab = primaryTab
            }
            dashboardMiniAction(title: secondaryTitle, systemImage: secondaryTab.icon) {
                selectedTab = secondaryTab
            }
        }
    }

    private func dashboardMiniAction(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.dashboardCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.dashboardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.dashboardBrand)
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
        let winner = historyWinnerLine(for: match)
        let players = matchDisplayName(for: match)

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(players)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(formattedMatchDate(for: match))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(winner)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dashboardInk)

                Text(historyScoreLine(for: match))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.dashboardBrand)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.92))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.dashboardBorder, lineWidth: 1))
        }
        .padding(16)
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
        VStack(alignment: .leading, spacing: 12) {
            Text(settingsOrganizationName)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                settingsBadge(title: settingsPlanLine)
                if let organizationType = organizationSummary?.type ?? session?.organizationType {
                    settingsBadge(title: organizationType.capitalized)
                }
            }

            HStack(spacing: 12) {
                settingsMetric(title: "Courts", value: String(organizationSummary?.courtCount ?? organizationSettings?.courts.count ?? 0))
                settingsMetric(title: "Users", value: String(organizationSummary?.userCount ?? 0))
                settingsMetric(title: "Role", value: session?.role.replacingOccurrences(of: "_", with: " ").capitalized ?? "User")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text)
                .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                .autocorrectionDisabled(keyboardType == .emailAddress)
                .keyboardType(keyboardType)
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

    private func loadDashboard() async {
        guard let organizationID = container.sessionStore.session?.organizationID else {
            print("DASHBOARD LOAD: missing organization ID in session")
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            print("DASHBOARD LOAD: requesting organization ID \(organizationID)")
            let dashboard = try await container.apiClient.getDashboard(
                organizationID: organizationID,
                activeLimit: 200,
                recentLimit: 200
            )
            await MainActor.run {
                organizationSummary = dashboard.organization
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
                isLoadingSettings = false
            }
        } catch {
            await MainActor.run {
                settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to load organisation settings."
                isLoadingSettings = false
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

    private func historyWinnerLine(for match: MatchSummary) -> String {
        match.winnerName ?? match.state?.winnerName ?? "Completed match"
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

    private var recentMatchesSubtitle: String {
        if isPersonalAccount {
            return "Completed matches available on your current plan."
        }

        let count = organizationSummary?.historyLimit ?? recentMatches.count
        return "Showing the latest \(count) completed matches for your club plan."
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
            return formatDate(completedAt)
        }
        if let updatedAt = match.updatedAt, !updatedAt.isEmpty {
            return formatDate(updatedAt)
        }
        return "Unknown date"
    }

    private func formatDate(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: value) else {
            return value
        }

        return DateFormatter.dashboardSummary.string(from: date)
    }

    private func isValidEmail(_ value: String) -> Bool {
        let emailPattern = "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"
        return value.range(of: emailPattern, options: .regularExpression) != nil
    }

    private func planDisplayName(for plan: String) -> String {
        switch plan.lowercased() {
        case "personal_plus":
            return "Personal+"
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

private struct MatchRoute: Hashable, Identifiable {
    let id: String
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
        case .settings:
            return "gearshape"
        case .help:
            return "questionmark.circle"
        }
    }
}

private extension DateFormatter {
    static let dashboardSummary: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
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
