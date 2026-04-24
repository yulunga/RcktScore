import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.colorScheme) private var colorScheme

    @State private var activeMatches: [MatchSummary] = []
    @State private var scheduledMatches: [MatchSummary] = []
    @State private var recentMatches: [MatchSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var startingScheduledMatchID: String?
    @State private var navigationTarget: MatchRoute?
    @State private var activeSheet: DashboardSheet?
    @State private var dashboardNotice: String?
    @State private var selectedTab: DashboardTab = .home

    private var session: UserSession? { container.sessionStore.session }
    private var isPersonalAccount: Bool { session?.isPersonalAccount ?? false }
    private var historyTitle: String { isPersonalAccount ? "Match History" : "Recent Matches" }
    private var historySubtitle: String {
        isPersonalAccount
            ? "Completed matches available on your current plan."
            : "Completed matches and recent activity."
    }
    private var headerPlanLine: String {
        isPersonalAccount
            ? (session?.planDisplayName ?? "Personal Free")
            : (session?.organizationName ?? "Unknown organisation")
    }
    private var headerUserLine: String {
        session?.email ?? session?.username ?? ""
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    headerSection
                    startNewMatchHero

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
            .task { await loadDashboard() }
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
                            container.sessionStore.clear()
                        }
                        .buttonStyle(.plain)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dashboardBrand)
                    }
                }
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
        case .players:
            placeholderPanel(
                title: "Players",
                message: "Player browsing will land here next."
            )
        case .more:
            placeholderPanel(
                title: "More",
                message: "Settings and more tools will live here."
            )
        }
    }

    private var homeContent: some View {
        VStack(spacing: 18) {
            dashboardSection(
                title: "Active Matches",
                subtitle: isPersonalAccount
                    ? "Your active personal matches."
                    : "Matches currently in progress for this organisation."
            ) {
                activeMatchesContent
            }

            if !isPersonalAccount {
                dashboardSection(
                    title: "Scheduled Matches",
                    subtitle: "Matches queued and ready to start."
                ) {
                    scheduledMatchesContent
                }
            }

            dashboardSection(
                title: historyTitle,
                subtitle: historySubtitle
            ) {
                recentMatchesContent
            }
        }
    }

    private var matchesContent: some View {
        VStack(spacing: 18) {
            dashboardSection(
                title: "Active Matches",
                subtitle: isPersonalAccount
                    ? "Your active personal matches."
                    : "Matches currently in progress for this organisation."
            ) {
                activeMatchesContent
            }

            if !isPersonalAccount {
                dashboardSection(
                    title: "Scheduled Matches",
                    subtitle: "Matches queued and ready to start."
                ) {
                    scheduledMatchesContent
                }
            }
        }
    }

    private var historyContent: some View {
        dashboardSection(
            title: historyTitle,
            subtitle: historySubtitle
        ) {
            recentMatchesContent
        }
    }

    private func placeholderPanel(title: String, message: String) -> some View {
        dashboardSection(title: title, subtitle: "Coming soon") {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
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
    private var activeMatchesContent: some View {
        if isLoading && activeMatches.isEmpty {
            HStack {
                ProgressView()
                Spacer()
            }
        } else if activeMatches.isEmpty {
            emptyState("No active matches")
        } else {
            VStack(spacing: 12) {
                ForEach(activeMatches) { match in
                    Button {
                        navigationTarget = MatchRoute(id: match.id)
                    } label: {
                        dashboardMatchCard(
                            match,
                            subtitle: "Resume live scoring",
                            detailLine: nil,
                            statusLabel: "Active",
                            statusColor: .dashboardActiveStatus,
                            actionTitle: "Open",
                            actionTint: .dashboardBrand,
                            showCourtName: !isPersonalAccount
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var scheduledMatchesContent: some View {
        if isLoading && scheduledMatches.isEmpty {
            HStack {
                ProgressView()
                Spacer()
            }
        } else if scheduledMatches.isEmpty {
            emptyState("No scheduled matches")
        } else {
            VStack(spacing: 12) {
                ForEach(scheduledMatches) { match in
                    dashboardMatchCard(
                        match,
                        subtitle: match.bestOf != nil ? "Best of \(match.bestOf ?? 1)" : "Ready to start",
                        detailLine: nil,
                        statusLabel: "Scheduled",
                        statusColor: .dashboardBrand.opacity(0.72),
                        actionTitle: startingScheduledMatchID == match.id ? "Starting..." : "Start",
                        actionTint: .dashboardBrand,
                        actionDisabled: startingScheduledMatchID != nil
                    ) {
                        Task { await startScheduledMatch(match.id) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentMatchesContent: some View {
        if isLoading && recentMatches.isEmpty {
            HStack {
                ProgressView()
                Spacer()
            }
        } else if recentMatches.isEmpty {
            emptyState("No recent matches")
        } else {
            VStack(spacing: 12) {
                ForEach(recentMatches) { match in
                    Button {
                        navigationTarget = MatchRoute(id: match.id)
                    } label: {
                        dashboardMatchCard(
                            match,
                            subtitle: historyWinnerLine(for: match),
                            detailLine: historyScoreLine(for: match),
                            statusLabel: "Completed",
                            statusColor: .dashboardCompletedStatus,
                            actionTitle: "View",
                            actionTint: .dashboardBrand,
                            showCourtName: !isPersonalAccount
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func dashboardSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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

    @ViewBuilder
    private func dashboardMatchCard(
        _ match: MatchSummary,
        subtitle: String,
        detailLine: String?,
        statusLabel: String,
        statusColor: Color,
        actionTitle: String,
        actionTint: Color,
        actionDisabled: Bool = false,
        showCourtName: Bool = true,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(matchDisplayName(for: match))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if showCourtName, let courtName = match.courtName, !courtName.isEmpty {
                        Text(courtName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.dashboardBrand)
                    }

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let detailLine, !detailLine.isEmpty {
                        Text(detailLine)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 10) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusLabel)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }

                    if let action {
                        Button(actionTitle) {
                            action()
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(actionTint)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                        .disabled(actionDisabled)
                        .opacity(actionDisabled ? 0.7 : 1)
                    } else {
                        Text(actionTitle)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(actionTint)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func emptyState(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
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
            let dashboard = try await container.apiClient.getDashboard(organizationID: organizationID)
            await MainActor.run {
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

    private func formatDate(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: value) else {
            return value
        }

        return DateFormatter.dashboardSummary.string(from: date)
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
    case players
    case more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .matches:
            return "Matches"
        case .history:
            return "History"
        case .players:
            return "Players"
        case .more:
            return "More"
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
        case .players:
            return "person.2"
        case .more:
            return "line.3.horizontal"
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
