import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var container: AppContainer

    @State private var activeMatches: [MatchSummary] = []
    @State private var scheduledMatches: [MatchSummary] = []
    @State private var recentMatches: [MatchSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var startingScheduledMatchID: String?
    @State private var navigationTarget: MatchRoute?

    var body: some View {
        NavigationStack {
            List {
                sessionSection
                activeMatchesSection
                scheduledMatchesSection
                recentMatchesSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Dashboard")
            .navigationDestination(item: $navigationTarget) { route in
                MatchScoringView(matchID: route.id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(AppConfig.environmentName) • \(AppConfig.buildID)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Logout") {
                        container.sessionStore.clear()
                    }
                }
            }
            .task { await loadDashboard() }
            .refreshable { await loadDashboard() }
            .alert("Unable to load dashboard", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "Unknown error")
            })
        }
    }

    private var sessionSection: some View {
        Section("Session") {
            Text(container.sessionStore.session?.organizationName ?? "Unknown organisation")
                .font(.headline)
            Text(container.sessionStore.session?.username ?? "Unknown user")
                .foregroundStyle(.secondary)
        }
    }

    private var activeMatchesSection: some View {
        Section("Active Matches") {
            if isLoading && activeMatches.isEmpty {
                ProgressView()
            } else if activeMatches.isEmpty {
                Text("No active matches")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(activeMatches) { match in
                    NavigationLink {
                        MatchScoringView(matchID: match.id)
                    } label: {
                        matchSummaryRow(match, subtitle: "Resume live scoring")
                    }
                }
            }
        }
    }

    private var scheduledMatchesSection: some View {
        Section("Scheduled Matches") {
            if isLoading && scheduledMatches.isEmpty {
                ProgressView()
            } else if scheduledMatches.isEmpty {
                Text("No scheduled matches")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(scheduledMatches) { match in
                    VStack(alignment: .leading, spacing: 10) {
                        matchSummaryRow(
                            match,
                            subtitle: match.bestOf != nil ? "Best of \(match.bestOf ?? 1)" : "Ready to start"
                        )

                        HStack {
                            Spacer()

                            Button {
                                Task { await startScheduledMatch(match.id) }
                            } label: {
                                if startingScheduledMatchID == match.id {
                                    ProgressView()
                                        .tint(.white)
                                        .frame(minWidth: 64)
                                } else {
                                    Text("Start")
                                        .frame(minWidth: 64)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(startingScheduledMatchID != nil)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var recentMatchesSection: some View {
        Section("Recent Matches") {
            if isLoading && recentMatches.isEmpty {
                ProgressView()
            } else if recentMatches.isEmpty {
                Text("No recent matches")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentMatches) { match in
                    NavigationLink {
                        MatchScoringView(matchID: match.id)
                    } label: {
                        matchSummaryRow(
                            match,
                            subtitle: match.updatedAt.map(formatDate) ?? "Completed match"
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func matchSummaryRow(_ match: MatchSummary, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(matchDisplayName(for: match))
                .font(.headline)
                .foregroundStyle(.primary)

            if let courtName = match.courtName, !courtName.isEmpty {
                Text(courtName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
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
