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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    headerCard

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

                    dashboardSection(
                        title: "Active Matches",
                        subtitle: "Matches currently in progress for this organisation."
                    ) {
                        activeMatchesContent
                    }

                    dashboardSection(
                        title: "Scheduled Matches",
                        subtitle: "Matches queued and ready to start."
                    ) {
                        scheduledMatchesContent
                    }

                    dashboardSection(
                        title: "Recent Matches",
                        subtitle: "Completed matches and recent activity."
                    ) {
                        recentMatchesContent
                    }
                }
                .padding()
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
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $navigationTarget) { route in
                MatchScoringView(matchID: route.id)
            }
            .toolbar {
                ToolbarItem(placement: .principal) { EmptyView() }
            }
            .task { await loadDashboard() }
            .refreshable { await loadDashboard() }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image("BrandLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hit n Score")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.dashboardBrand)

                            Text("Live scoring dashboard")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                }

                Spacer()

                Button("Logout") {
                    container.sessionStore.clear()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.dashboardBrand)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(container.sessionStore.session?.username ?? "Unknown user")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(container.sessionStore.session?.organizationName ?? "Unknown organisation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                dashboardMetaPill("\(AppConfig.environmentName.capitalized)")
                dashboardMetaPill("Build \(AppConfig.buildID)")
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardHeroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.dashboardBorder, lineWidth: 1)
        )
        .shadow(
            color: colorScheme == .dark ? .clear : Color.black.opacity(0.06),
            radius: 18,
            x: 0,
            y: 10
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
                            statusLabel: "Active",
                            statusColor: .dashboardActiveStatus,
                            actionTitle: "Open",
                            actionTint: .dashboardBrand
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
                            subtitle: match.updatedAt.map(formatDate) ?? "Completed match",
                            statusLabel: "Recent",
                            statusColor: .dashboardMutedStatus,
                            actionTitle: "View",
                            actionTint: .dashboardBrand
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
        statusLabel: String,
        statusColor: Color,
        actionTitle: String,
        actionTint: Color,
        actionDisabled: Bool = false,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(matchDisplayName(for: match))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if let courtName = match.courtName, !courtName.isEmpty {
                        Text(courtName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.dashboardBrand)
                    }

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
    private func dashboardMetaPill(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.dashboardBrand)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.dashboardBrand.opacity(colorScheme == .dark ? 0.18 : 0.1))
            .clipShape(Capsule())
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
