import SwiftUI

struct HistoricMatchView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let matchID: String

    @State private var match: MatchDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showMatchInformation = false
    @State private var showGameTimes = false

    private var isOnline: Bool { container.networkMonitor.isOnline }
    private var live: MatchState? { match?.state }
    private var player1GamesWon: Int { live?.player1GamesWon ?? 0 }
    private var player2GamesWon: Int { live?.player2GamesWon ?? 0 }
    private var isTennisStyle: Bool {
        ["tennis", "padel"].contains((match?.sport ?? "").lowercased())
            || (live?.scoreDisplayMode ?? "").lowercased() == "tennis"
    }
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
                            title: timelineTitle(for: event),
                            score: eventScoreLine(event),
                            timestamp: event.createdAt,
                            winnerSide: event.payload?.scorer ?? event.payload?.playerSide,
                            serverSide: event.payload?.currentServerSide,
                            serviceSideLabel: String(event.payload?.serviceSide?.prefix(1) ?? "").uppercased(),
                            tennisGameCompleted: event.payload?.tennisGameCompleted == true,
                            setCompleted: event.payload?.setCompleted == true,
                            completedGameScore: completedGameScore(event),
                            matchCompleted: event.payload?.matchCompleted == true
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
    private var historicMatchDurationSeconds: Int {
        let recordedDuration = match?.matchDurationSeconds ?? live?.matchDurationSeconds ?? 0
        let derivedGameDuration = gameDurations.reduce(0) { $0 + $1.seconds }

        // Older matches can contain a stale recorded timer value. The total
        // shown above the game rows must never be shorter than those rows.
        return max(0, max(recordedDuration, derivedGameDuration))
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
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showMatchInformation.toggle()
                }
            } label: {
                HStack {
                    Text("Match Information")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: showMatchInformation ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.rcktBlue)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showMatchInformation ? "Collapse match information" : "Expand match information")

            if showMatchInformation {
                historicInfoRow(
                    title: "Sport",
                    value: sportDisplayName(match.sport)
                )
                historicInfoRow(
                    title: "Game Details",
                    value: gameDetailsLine(for: match)
                )
                historicInfoRow(title: "Date", value: matchStartDate(match))
                historicInfoRow(title: "Started", value: matchStartTime(match))
                historicInfoRow(title: "Court", value: historicCourtName(match))
                historicInfoRow(title: "Referee", value: match.refereeName ?? "Not added")
            }
        }
        .padding(showMatchInformation ? 18 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rcktCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.rcktBorder, lineWidth: 1)
        )
    }

    private func timeCard(_ match: MatchDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                        Text(formatSeconds(historicMatchDurationSeconds))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.rcktBlue)
                    }

                    Spacer()

                    Image(systemName: showGameTimes ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.rcktBlue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if showGameTimes {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
                    spacing: 8
                ) {
                        ForEach(gameDurations) { game in
                            VStack(spacing: 3) {
                                Text("\(isTennisStyle ? "Set" : "Game") \(game.gameNumber)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(formatSeconds(game.seconds))
                                    .font(.caption.weight(.bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 7)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rcktCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
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
                VStack(spacing: 10) {
                    ForEach(groupedTimeline) { game in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(isTennisStyle ? "Set" : "Game") \(game.gameNumber)")
                                    .font(.subheadline.weight(.bold))
                            }

                            HStack(spacing: 8) {
                                Text(fullName(firstName: match.player1Name, surname: match.player1Surname))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(game.result.map { "\($0.player1Score)-\($0.player2Score)" } ?? "")
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundStyle(Color.rcktBlue)
                                    .frame(minWidth: 48)

                                Text(fullName(firstName: match.player2Name, surname: match.player2Surname))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .padding(.horizontal, 6)

                            LazyVStack(spacing: 3) {
                                ForEach(game.entries) { entry in
                                    if isTennisStyle {
                                        HStack(spacing: 8) {
                                            VStack(alignment: .leading, spacing: 0) {
                                                Text(timelineWinnerName(entry, match: match))
                                                    .font(.caption.weight(.bold))
                                                    .lineLimit(1)

                                                if let timestamp = entry.timestamp {
                                                    Text(formatTimeOnly(timestamp))
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }

                                            Spacer(minLength: 4)

                                            if let score = entry.score {
                                                Text(score)
                                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                                    .foregroundStyle(entry.winnerSide == "player2" ? Color.rcktSlate : Color.rcktBlue)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color(.secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    } else {
                                        HStack(alignment: .center, spacing: 6) {
                                            historicTimelineSide(playerSide: "player1", entry: entry, tint: Color.rcktBlue, serveFirst: true)
                                                .frame(width: 58, alignment: .leading)
                                            VStack(spacing: 0) {
                                                Text(timelineWinnerName(entry, match: match))
                                                    .font(.caption.weight(.bold))
                                                    .multilineTextAlignment(.center)
                                                    .lineLimit(1)
                                                if let timestamp = entry.timestamp {
                                                    Text(formatTimeOnly(timestamp)).font(.caption2).foregroundStyle(.secondary)
                                                }
                                            }
                                            .frame(maxWidth: .infinity)
                                            historicTimelineSide(playerSide: "player2", entry: entry, tint: Color.rcktSlate, serveFirst: false)
                                                .frame(width: 58, alignment: .trailing)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color(.secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }

                                    if isTennisStyle, entry.tennisGameCompleted {
                                        completionBanner(
                                            title: entry.matchCompleted ? "Game, Set and Match" : "Game",
                                            winner: timelineWinnerName(entry, match: match),
                                            score: entry.completedGameScore
                                        )
                                    }

                                    if isTennisStyle, entry.setCompleted, !entry.matchCompleted {
                                        completionBanner(
                                            title: "Set",
                                            winner: timelineWinnerName(entry, match: match),
                                            score: game.result.map { "\($0.player1Score)-\($0.player2Score)" }
                                        )
                                    }
                                }
                            }

                            if !isTennisStyle, game.result != nil {
                                Text("Games \(completedGamesScore(after: game.gameNumber))")
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundStyle(Color.rcktBlue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .background(Color.rcktBlue.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
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
        .padding(14)
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

    @ViewBuilder
    private func historicTimelineSide(
        playerSide: String,
        entry: HistoricTimelineEntry,
        tint: Color,
        serveFirst: Bool
    ) -> some View {
        if entry.winnerSide == playerSide {
            let isServing = entry.serverSide == playerSide
            let scoreMarker = historicScoreMarker(
                score: entry.score,
                tint: tint
            )

            HStack(spacing: 6) {
                if serveFirst {
                    if isServing {
                        historicServeMarker(label: entry.serviceSideLabel)
                    }
                    scoreMarker
                } else {
                    scoreMarker
                    if isServing {
                        historicServeMarker(label: entry.serviceSideLabel)
                    }
                }

                if !serveFirst {
                    Spacer(minLength: 0)
                }
            }
        } else {
            Color.clear
                .frame(width: 1, height: 28)
                .accessibilityHidden(true)
        }
    }

    private func historicServeMarker(label: String?) -> some View {
        Circle()
            .fill(Color.rcktServe)
            .frame(width: 18, height: 18)
            .overlay(
                Group {
                    if let label, !label.isEmpty {
                        Text(label)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            )
    }

    private func historicScoreMarker(score: String?, tint: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 28, height: 28)
                .overlay(
                    Group {
                        if let score {
                            Text(score)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                                .foregroundStyle(.white)
                        }
                    }
                )
        }
    }

    private func completedGamesScore(after gameNumber: Int) -> String {
        let completedGames = (live?.gameHistory ?? [])
            .filter { $0.gameNumber <= gameNumber }

        let player1Games = completedGames.filter { $0.player1Score > $0.player2Score }.count
        let player2Games = completedGames.filter { $0.player2Score > $0.player1Score }.count
        return "\(player1Games)–\(player2Games)"
    }

    private func gameDetailsLine(for match: MatchDetail) -> String {
        let bestOfValue = live?.bestOf ?? match.bestOf
        if isTennisStyle {
            let scoring = live?.tennisNoAdScoring == true ? "Golden Point" : "Advantage scoring"
            return "Best of \(bestOfValue) sets • \(scoring)"
        }
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
        if isTennisStyle {
            if let player1 = event.payload?.pointPlayer1ScoreLabel,
               let player2 = event.payload?.pointPlayer2ScoreLabel {
                return "\(player1)-\(player2)"
            }
            if let player1 = event.payload?.pointPlayer1Score,
               let player2 = event.payload?.pointPlayer2Score {
                return tennisScoreLine(player1: player1, player2: player2, tieBreak: event.payload?.isTieBreak == true)
            }
        }
        let player1 = event.payload?.gameResult?.player1Score ?? event.payload?.player1Score
        let player2 = event.payload?.gameResult?.player2Score ?? event.payload?.player2Score

        guard let player1, let player2 else {
            return nil
        }

        return "\(player1)-\(player2)"
    }

    private func tennisScoreLine(player1: Int, player2: Int, tieBreak: Bool) -> String {
        guard !tieBreak else { return "\(player1)-\(player2)" }
        let labels = ["0", "15", "30", "40"]
        if player1 >= 3 && player2 >= 3 {
            if player1 == player2 { return "Deuce" }
            return player1 > player2 ? "Advantage-40" : "40-Advantage"
        }
        return "\(labels[min(player1, 3)])-\(labels[min(player2, 3)])"
    }

    private func timelineTitle(for event: MatchEvent) -> String {
        switch event.eventType {
        case "stroke": return "Stroke"
        case "let": return "Let"
        default: return "Point"
        }
    }

    private func timelineWinnerName(_ entry: HistoricTimelineEntry, match: MatchDetail) -> String {
        let side = entry.winnerSide ?? "player1"
        if isTennisStyle,
           (live?.teamFormat ?? "").lowercased() == "doubles",
           let participants = live?.tennisTeams?[side], !participants.isEmpty {
            return participants.map(\.displayName).joined(separator: " & ")
        }
        return side == "player2"
            ? fullName(firstName: match.player2Name, surname: match.player2Surname)
            : fullName(firstName: match.player1Name, surname: match.player1Surname)
    }

    private func completedGameScore(_ event: MatchEvent) -> String? {
        guard let player1 = event.payload?.completedGamePlayer1Games,
              let player2 = event.payload?.completedGamePlayer2Games else { return nil }
        return "\(player1)-\(player2)"
    }

    private func matchStartTime(_ match: MatchDetail) -> String {
        let startedAt = match.state?.events.first(where: { $0.eventType == "match_started" })?.createdAt ?? match.createdAt
        return formatTimeOnly(startedAt)
    }

    private func matchStartDate(_ match: MatchDetail) -> String {
        let startedAt = match.state?.events.first(where: { $0.eventType == "match_started" })?.createdAt ?? match.createdAt
        return formatDateOnly(startedAt)
    }

    private func completionBanner(title: String, winner: String, score: String?) -> some View {
        VStack(spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.heavy))
                .foregroundStyle(Color.rcktCompleted)
            Text(winner).font(.subheadline.weight(.bold))
            if let score {
                Text(score).font(.title3.weight(.heavy)).foregroundStyle(Color.rcktBlue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.rcktCompleted.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.rcktCompleted.opacity(0.35), lineWidth: 1))
    }

    private func fullName(firstName: String, surname: String?) -> String {
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSurname = surname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedSurname.isEmpty else {
            return trimmedFirstName
        }

        if let existingSurname = trimmedFirstName.split(separator: " ").last,
           String(existingSurname).caseInsensitiveCompare(trimmedSurname) == .orderedSame {
            return trimmedFirstName
        }

        return "\(trimmedFirstName) \(trimmedSurname)"
    }

    private func historicCourtName(_ match: MatchDetail) -> String {
        let values = [match.courtName, match.courtAlias]
            .compactMap { value -> String? in
                guard let value else { return nil }
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }

        return values.reduce(into: [String]()) { result, value in
            if !result.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
                result.append(value)
            }
        }
        .joined(separator: " • ")
    }

    private func sportDisplayName(_ value: String?) -> String {
        switch (value ?? "squash").lowercased() {
        case "table_tennis":
            return "Table Tennis"
        case "pickleball":
            return "Pickleball"
        case "racketball":
            return "Racketball"
        case "badminton":
            return "Badminton"
        case "padel":
            return "Padel"
        case "tennis":
            return "Tennis"
        default:
            return "Squash"
        }
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
        let clampedValue = max(0, value)
        let minutes = String(format: "%02d", clampedValue / 60)
        let seconds = String(format: "%02d", clampedValue % 60)
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
    let tennisGameCompleted: Bool
    let setCompleted: Bool
    let completedGameScore: String?
    let matchCompleted: Bool
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
