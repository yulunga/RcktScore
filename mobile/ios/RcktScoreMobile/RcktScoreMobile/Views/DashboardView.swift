import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var activeMatches: [MatchSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Session") {
                    Text(container.sessionStore.session?.organizationName ?? "Unknown organisation")
                    Text(container.sessionStore.session?.username ?? "Unknown user")
                        .foregroundStyle(.secondary)
                }

                Section("Active Matches") {
                    if isLoading {
                        ProgressView()
                    } else if activeMatches.isEmpty {
                        Text("No active matches")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(activeMatches) { match in
                            NavigationLink {
                                MatchScoringView(matchID: match.id)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text("\(match.player1Name) vs \(match.player2Name)")
                                    Text(match.courtName ?? "Court unassigned")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Dashboard")
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
            .alert("Unable to load dashboard", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "Unknown error")
            })
        }
    }

    private func loadDashboard() async {
        guard let organizationID = container.sessionStore.session?.organizationID else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let dashboard = try await container.apiClient.getDashboard(organizationID: organizationID)
            activeMatches = dashboard.activeMatches
        } catch {
            errorMessage = (error as? APIErrorResponse)?.message ?? "Unable to fetch dashboard data."
        }
    }
}
