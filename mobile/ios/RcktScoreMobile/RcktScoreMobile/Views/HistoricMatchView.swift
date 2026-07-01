import SwiftUI

struct HistoricMatchView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let matchID: String

    @State private var match: MatchDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showGameTimes = false

    private var isOnline: Bool { container.networkMonitor.isOnline }
    private var live: MatchState? { match?.state }
    private var player1GamesWon: Int { live?.player1GamesWon ?? 0 }
    private var player2GamesWon: Int { live?.player2GamesWon ?? 0 }
    private var groupedTimeline: [HistoricGameTimeline] {
        guard let match else { return [] }

        let events = (match.state?.events ?? [])
            .filter { event in
                ["score_point", "stroke", "let"].contains(event.eventType)
            }

        let grouped = Dictionary(grouping: events) { event in
            event.payload?.gameNumber ?? 1
        }

        let completedGames = match.state?.gameHistory ?? []
        let gameNumbers = Set(grouped.keys).union(completedGames.map(\.gameNumber))

        return gameNumbers.sorted().map { gameNumber in
            HistoricGameTimeline(
                gameNumber: gameNumber,
                result: completedGames.first(where: { $0.gameNumber == gameNumber }),
                entries: (grouped[gameNumber] ?? [])
                    .sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
                    .map { event in
                        HistoricTimelineEntry(
                            id: event.id,
                            title: event.summary ?? readableEventTitle(event.eventType),
                            score: eventScoreLine(event),
                            timestamp: event.createdAt,
                            winnerSide: event.payload?.scorer ?? event.payload?.playerSide,
                            serverSide: event.payload?.currentServerSide,
                            serviceSideLabel: String(event.payload?.serviceSide?.prefix(1) ?? "").uppercased()
                        )
                    }
            )
        }
    }
    private var gameDurations: [HistoricGameDuration] {
        groupedTimeline.compactMap { game in
            let startDate = game.entries.compactMap { parseISODate($0.timestamp) }.first
            let endDate = game.entries.compactMap { parseISODate($0.timestamp) }.last

            guard let startDate, let endDate else {
                return nil
            }

            return HistoricGameDuration(
                gameNumber: game.gameNumber,
                seconds: max(0, Int(endDate.timeIntervalSince(startDate)))
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !isOnline {
                    offlineStateCard
                } else if isLoading && match == nil {
                    ProgressView("Loading match…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if isOnline, let match {
                    summaryCard(match)
                    metadataCard(match)
                    timeCard(match)
                    timelineCard(match)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Historic Match")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.rcktBlue.opacity(0.12))
                    .foregroundStyle(Color.rcktBlue)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            guard isOnline else {
                return
            }
            await loadMatch()
        }
    }

    private var offlineStateCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.rcktBlue)

            Text("Offline")
                .font(.headline.weight(.semibold))

            Text("Historic matches can only be viewed while the app is online.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.rcktCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.rcktBorder, lineWidth: 1)
        )
    }

    private func summaryCard(_ match: MatchDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            historicPlayerScoreRow(
                playerName: fullName(firstName: match.player1Name, surname: match.player1Surname),
                gamesWon: player1GamesWon
            )

            historicPlayerScoreRow(
                playerName: fullName(firstName: match.player2Name, surname: match.player2Surname),
                gamesWon: player2GamesWon
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rcktCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.rcktBorder, lineWidth: 1)
        )
        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.05), radius: 16, x: 0, y: 8)
    }

    private func metadataCard(_ match: MatchDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Match Information")
                .font(.headline)

            historicInfoRow(
                title: "Game Details",
                value: gameDetailsLine(for: match)
            )
            historicInfoRow(title: "Date", value: formatDateOnly(match.completedAt ?? match.updatedAt))
            historicInfoRow(title: "Court", value: [match.courtName, match.courtAlias].compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }.joined(separator: " • "))
            historicInfoRow(title: "Referee", value: match.refereeName ?? "Not added")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rcktCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.rcktBorder, lineWidth: 1)
        )
    }

    private func timeCard(_ match: MatchDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showGameTimes.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Match Time")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(formatSeconds(match.matchDurationSeconds ?? live?.matchDurationSeconds ?? 0))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.rcktBlue)
                    }

                    Spacer()

                    Image(systemName: showGameTimes ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.rcktBlue)
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            if showGameTimes {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
                    spacing: 8
                ) {
                        ForEach(gameDurations) { game in
                            VStack(spacing: 3) {
                                Text("Game \(game.gameNumber)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(formatSeconds(game.seconds))
                                    .font(.caption.weight(.bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rcktCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.rcktBorder, lineWidth: 1)
        )
    }

    private func timelineCard(_ match: MatchDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Point Timeline")
                .font(.headline)

            if groupedTimeline.isEmpty {
                Text("No point history available for this match.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 14) {
                    ForEach(groupedTimeline) { game in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Game \(game.gameNumber)")
                                    .font(.subheadline.weight(.bold))
                                Spacer()
                                if let result = game.result {
                                    Text("\(result.player1Score)-\(result.player2Score)")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.rcktBlue)
                                }
                            }

                            HStack {
                                Text(match.player1Name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(match.player2Name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .padding(.horizontal, 6)

                            ForEach(game.entries) { entry in
                                HStack(alignment: .center, spacing: 12) {
                                    historicTimelineSide(
                                        playerSide: "player1",
                                        entry: entry,
                                        tint: Color.rcktBlue,
                                        serveFirst: true
                                    )
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    VStack(spacing: 2) {
                                        Text(entry.title)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        if let timestamp = entry.timestamp {
                                            Text(formatTimeOnly(timestamp))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(minWidth: 80)

                                    historicTimelineSide(
                                        playerSide: "player2",
                                        entry: entry,
                                        tint: Color.rcktSlate,
                                        serveFirst: false
                                    )
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                        .padding(.bottom, 6)

                        if game.id != groupedTimeline.last?.id {
                            Divider()
                                .overlay(Color.rcktBorder)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rcktCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.rcktBorder, lineWidth: 1)
        )
    }

    private func historicInfoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "Not available" : value)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func historicPlayerScoreRow(playerName: String, gamesWon: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(playerName)
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(gamesWon)")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.rcktBlue)
        }
    }

    private func historicTimelineSide(
        playerSide: String,
        entry: HistoricTimelineEntry,
        tint: Color,
        serveFirst: Bool
    ) -> some View {
        let serveMarker = historicServeMarker(
            isActive: entry.serverSide == playerSide,
            label: entry.serverSide == playerSide ? entry.serviceSideLabel : nil
        )
        let scoreMarker = historicScoreMarker(
            isActive: entry.winnerSide == playerSide,
            score: entry.winnerSide == playerSide ? entry.score : nil,
            tint: tint
        )

        return HStack(spacing: 8) {
            if serveFirst {
                serveMarker
                scoreMarker
            } else {
                scoreMarker
                serveMarker
            }

            if !serveFirst {
                Spacer(minLength: 0)
            }
        }
    }

    private func historicServeMarker(isActive: Bool, label: String?) -> some View {
        Circle()
            .fill(isActive ? Color.rcktServe : Color.clear)
            .frame(width: 24, height: 24)
            .overlay(
                Circle()
                    .stroke(isActive ? Color.rcktServe : Color.rcktBorder.opacity(0.9), lineWidth: 2)
            )
            .overlay(
                Group {
                    if let label, isActive, !label.isEmpty {
                        Text(label)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            )
    }

    private func historicScoreMarker(isActive: Bool, score: String?, tint: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isActive ? tint : Color.clear)
                .frame(width: 38, height: 38)
                .overlay(
                    Circle()
                        .stroke(tint.opacity(isActive ? 0.0 : 0.24), lineWidth: 2)
                )
                .overlay(
                    Group {
                        if let score, isActive {
                            Text(score)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                                .foregroundStyle(.white)
                        }
                    }
                )
        }
    }

    private func gameDetailsLine(for match: MatchDetail) -> String {
        let bestOfValue = live?.bestOf ?? match.bestOf
        let scoreTypeValue = live?.scoreType ?? match.scoreType
        let handicap = matchHandicapLine(for: match)
        return "\(handicap) • Best of \(bestOfValue) • PAR-\(scoreTypeValue)"
    }

    private func matchHandicapLine(for match: MatchDetail) -> String {
        let enabled = live?.handicap?.enabled ?? match.handicapEnabled
        guard enabled else {
            return "No handicap"
        }

        let player1Offset = live?.handicap?.player1Offset ?? match.player1Offset
        let player2Offset = live?.handicap?.player2Offset ?? match.player2Offset
        return "Handicap \(player1Offset) | \(player2Offset)"
    }

    private func readableEventTitle(_ eventType: String) -> String {
        eventType
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func eventScoreLine(_ event: MatchEvent) -> String? {
        let player1 = event.payload?.gameResult?.player1Score ?? event.payload?.player1Score
        let player2 = event.payload?.gameResult?.player2Score ?? event.payload?.player2Score

        guard let player1, let player2 else {
            return nil
        }

        return "\(player1)-\(player2)"
    }

    private func fullName(firstName: String, surname: String?) -> String {
        guard let surname, !surname.isEmpty else {
            return firstName
        }

        return "\(firstName) \(surname)"
    }

    private func formatDateOnly(_ value: String) -> String {
        guard let date = parseISODate(value) else {
            return value
        }

        return DateFormatter.historicDateOnly.string(from: date)
    }

    private func formatTimeOnly(_ value: String) -> String {
        guard let date = parseISODate(value) else {
            return value
        }

        return DateFormatter.historicTimeOnly.string(from: date)
    }

    private func formatSeconds(_ value: Int) -> String {
        let minutes = String(max(0, value) / 60).padding(toLength: 2, withPad: "0", startingAt: 0)
        let seconds = String(max(0, value) % 60).padding(toLength: 2, withPad: "0", startingAt: 0)
        return "\(minutes):\(seconds)"
    }

    private func parseISODate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }

        if let date = ISO8601DateFormatter.historicWithFractionalSeconds.date(from: value) {
            return date
        }

        return ISO8601DateFormatter.historicStandard.date(from: value)
    }

    private func loadMatch() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let fetched = try await container.apiClient.getMatch(matchID: matchID)
            await MainActor.run {
                match = fetched
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIErrorResponse)?.message ?? "Unable to load the historic match."
                isLoading = false
            }
        }
    }
}

private struct HistoricTimelineEntry: Identifiable {
    let id: String
    let title: String
    let score: String?
    let timestamp: String?
    let winnerSide: String?
    let serverSide: String?
    let serviceSideLabel: String?
}

private struct HistoricGameTimeline: Identifiable {
    let gameNumber: Int
    let result: GameHistoryEntry?
    let entries: [HistoricTimelineEntry]

    var id: Int { gameNumber }
}

private struct HistoricGameDuration: Identifiable {
    let gameNumber: Int
    let seconds: Int

    var id: Int { gameNumber }
}

private extension DateFormatter {
    static let historicDateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let historicTimeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

private extension ISO8601DateFormatter {
    static let historicWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let historicStandard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private extension Color {
    static let rcktBlue = Color(red: 18 / 255, green: 116 / 255, blue: 208 / 255)
    static let rcktSlate = Color(red: 77 / 255, green: 107 / 255, blue: 139 / 255)
    static let rcktServe = Color(red: 217 / 255, green: 130 / 255, blue: 43 / 255)
    static let rcktCompleted = Color(red: 196 / 255, green: 68 / 255, blue: 92 / 255)
    static let rcktCardBackground = Color(UIColor.secondarySystemGroupedBackground)
    static let rcktBorder = Color(
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
