import SwiftUI

struct RemoteMatchWatchView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    let code: String
    let onSaved: () -> Void

    @State private var watch: MatchWatchPayload?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var session: UserSession? { container.sessionStore.session }
    private var match: MatchDetail? { watch?.match }
    private var live: MatchState? { match?.state }
    private var player1Name: String { fullName(match?.player1Name, match?.player1Surname) }
    private var player2Name: String { fullName(match?.player2Name, match?.player2Surname) }
    private var isFinished: Bool { watch?.finished == true }
    private var scoringEvents: [MatchEvent] {
        Array((live?.events ?? [])
            .filter { ["score_point", "stroke", "let"].contains($0.eventType) }
            .reversed())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isFinished ? "Match Finished" : "Live Match")
                            .font(.title2.weight(.bold))
                        Text("Viewing code \(code)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(.bordered)
                }

                if isLoading {
                    ProgressView("Opening match…")
                        .frame(maxWidth: .infinity)
                        .padding(30)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if let match {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label(isFinished ? "This match has finished" : "Updating automatically", systemImage: isFinished ? "checkmark.circle.fill" : "dot.radiowaves.left.and.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isFinished ? Color.dashboardBrand : Color.green)
                            Spacer()
                            Text((match.sport ?? "Match").replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }

                        if watch?.saved == true {
                            Label("Added to Viewed Matches", systemImage: "bookmark.fill")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.dashboardBrand)
                        } else {
                            Button {
                                Task { await saveToProfile() }
                            } label: {
                                Label(isSaving ? "Adding…" : "Add to Viewed Matches", systemImage: "bookmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isSaving)
                        }
                    }
                    .padding(16)
                    .background(Color.dashboardCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    scoreCard
                    timelineCard
                }
            }
            .padding(18)
        }
        .background(Color.dashboardBackgroundStart.ignoresSafeArea())
        .task(id: code) {
            await loadWatch()
            while !Task.isCancelled, watch?.finished != true {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await loadWatch(silent: true)
            }
        }
    }

    private var scoreCard: some View {
        HStack(spacing: 10) {
            scoreColumn(name: player1Name, points: player1Points, games: player1Games)
            Text("–")
                .font(.title2.weight(.bold))
                .foregroundStyle(.secondary)
            scoreColumn(name: player2Name, points: player2Points, games: player2Games)
        }
        .padding(14)
        .background(Color.dashboardCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func scoreColumn(name: String, points: String, games: Int) -> some View {
        VStack(spacing: 7) {
            Text(name)
                .font(.subheadline.weight(.bold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(isFinished ? String(games) : points)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(Color.dashboardBrand)
            Text("\(games) \(games == 1 ? "game" : "games")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isFinished ? "Result Timeline" : "Live Timeline")
                .font(.headline)

            if scoringEvents.isEmpty {
                Text("No points have been recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(scoringEvents) { event in
                    let side = event.payload?.scorer ?? event.payload?.playerSide
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(side == "player2" ? player2Name : player1Name)
                                .font(.subheadline.weight(.semibold))
                            if let summary = event.summary, !summary.isEmpty {
                                Text(summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(eventScore(event))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(Color.dashboardBrand)
                    }
                    .padding(12)
                    .background(Color.dashboardInnerCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.dashboardCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var player1Games: Int { live?.player1GamesWon ?? 0 }
    private var player2Games: Int { live?.player2GamesWon ?? 0 }
    private var player1Points: String { live?.player1ScoreLabel ?? String(live?.player1Score ?? 0) }
    private var player2Points: String { live?.player2ScoreLabel ?? String(live?.player2Score ?? 0) }

    private func fullName(_ firstName: String?, _ surname: String?) -> String {
        [firstName, surname]
            .compactMap { value in
                guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return value
            }
            .joined(separator: " ")
    }

    private func eventScore(_ event: MatchEvent) -> String {
        let payload = event.payload
        if let left = payload?.pointPlayer1ScoreLabel, let right = payload?.pointPlayer2ScoreLabel {
            return "\(left)–\(right)"
        }
        if let left = payload?.pointPlayer1Score, let right = payload?.pointPlayer2Score {
            return "\(left)–\(right)"
        }
        if let left = payload?.player1Score, let right = payload?.player2Score {
            return "\(left)–\(right)"
        }
        return "Point"
    }

    @MainActor
    private func loadWatch(silent: Bool = false) async {
        guard let organizationID = session?.organizationID else { return }
        if !silent { isLoading = true }
        do {
            watch = try await container.apiClient.getWatchedMatch(organizationID: organizationID, code: code)
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = (error as? APIErrorResponse)?.message ?? "Unable to open this match."
        }
        if !silent { isLoading = false }
    }

    @MainActor
    private func saveToProfile() async {
        guard let organizationID = session?.organizationID else { return }
        isSaving = true
        do {
            watch = try await container.apiClient.saveWatchedMatch(organizationID: organizationID, code: code)
            errorMessage = nil
            onSaved()
        } catch {
            errorMessage = (error as? APIErrorResponse)?.message ?? "Unable to add this match to Viewed Matches."
        }
        isSaving = false
    }
}
