import SwiftUI

private struct PointRailEntry: Identifiable {
    let id: String
    let serverSide: String?
    let serviceSideLabel: String?
    let winnerSide: String?
    let winnerScore: String?
    let isCurrentServe: Bool
}

private enum RailMarkerKind {
    case server
    case winner
}

struct MatchScoringView: View {
    @EnvironmentObject private var container: AppContainer

    let matchID: String

    @State private var match: MatchDetail?
    @State private var isLoading = false
    @State private var isMutating = false
    @State private var errorMessage: String?
    @State private var showDetails = false

    private var live: MatchState? { match?.state }

    private var isMatchComplete: Bool {
        live?.matchComplete == true || match?.status.lowercased() == "completed"
    }

    private var pointRailEntries: [PointRailEntry] {
        guard let match else { return [] }
        let currentGameNumber = live?.currentGameNumber ?? 1
        let pointEvents = (live?.events ?? []).filter { event in
            guard ["score_point", "stroke"].contains(event.eventType) else {
                return false
            }
            return event.payload?.gameNumber == currentGameNumber
        }

        let historyEntries = pointEvents.map { event in
            let winnerSide = event.payload?.scorer ?? event.payload?.playerSide
            let serverSide = event.payload?.currentServerSide ?? winnerSide
            let serviceSideLabel = String(event.payload?.serviceSide?.prefix(1) ?? "").uppercased()
            let winnerScore: String

            if winnerSide == "player1" {
                winnerScore = String(event.payload?.gameResult?.player1Score ?? event.payload?.player1Score ?? 0)
            } else {
                winnerScore = String(event.payload?.gameResult?.player2Score ?? event.payload?.player2Score ?? 0)
            }

            return PointRailEntry(
                id: event.id,
                serverSide: serverSide,
                serviceSideLabel: serviceSideLabel,
                winnerSide: winnerSide,
                winnerScore: winnerScore,
                isCurrentServe: false
            )
        }

        let currentServe = PointRailEntry(
            id: "current-serve-\(match.id)-\(live?.currentServerSide ?? "player1")-\(live?.serviceSide ?? "Right")",
            serverSide: live?.currentServerSide,
            serviceSideLabel: String(live?.serviceSide?.prefix(1) ?? "").uppercased(),
            winnerSide: nil,
            winnerScore: nil,
            isCurrentServe: true
        )

        return historyEntries + [currentServe]
    }

    private var pointRailSignature: String {
        pointRailEntries.map(\.id).joined(separator: "|")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading && match == nil {
                    ProgressView("Loading match…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let match {
                    scoreboardCard(match)
                    detailsCard(match)
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
        .navigationTitle(match?.courtName ?? "Live Match")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMatch()
        }
    }

    @ViewBuilder
    private func scoreboardCard(_ match: MatchDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text(match.courtName ?? "Court")
                    .font(.title2.weight(.bold))

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    statusPill(match.status)

                    Text("Score to \(match.scoreType) • Game \(live?.currentGameNumber ?? 1) • Best of \(live?.bestOf ?? match.bestOf)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rcktBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.rcktBlue.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            HStack(alignment: .top, spacing: 12) {
                playerCard(
                    side: "player1",
                    firstName: match.player1Name,
                    surname: match.player1Surname,
                    score: live?.player1Score ?? 0,
                    games: live?.player1GamesWon ?? 0,
                    isServing: live?.currentServerSide == "player1",
                    serviceSide: live?.serviceSide ?? "Right"
                )

                pointRail

                playerCard(
                    side: "player2",
                    firstName: match.player2Name,
                    surname: match.player2Surname,
                    score: live?.player2Score ?? 0,
                    games: live?.player2GamesWon ?? 0,
                    isServing: live?.currentServerSide == "player2",
                    serviceSide: live?.serviceSide ?? "Right"
                )
            }

            matchHistoryStrip

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    controlButton("Stroke P1", color: .rcktSlate) {
                        await awardStroke(to: "player1")
                    }
                    controlButton("Let", color: .rcktSlate) {
                        await callLet()
                    }
                    controlButton("Stroke P2", color: .rcktSlate) {
                        await awardStroke(to: "player2")
                    }
                }

                HStack(spacing: 10) {
                    controlButton("Undo Last Action", color: .rcktDanger) {
                        await undoLastAction()
                    }
                    controlButton("End Match Early", color: .rcktDanger) {
                        await endMatchEarly()
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.rcktBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 8)
    }

    @ViewBuilder
    private var pointRail: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(pointRailEntries) { entry in
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                railMarker(kind: .server, active: entry.serverSide == "player1", label: entry.serverSide == "player1" ? (entry.serviceSideLabel ?? "") : "")
                                railMarker(kind: .server, active: entry.serverSide == "player2", label: entry.serverSide == "player2" ? (entry.serviceSideLabel ?? "") : "")
                            }
                            HStack(spacing: 8) {
                                railMarker(kind: .winner, active: entry.winnerSide == "player1", label: entry.winnerSide == "player1" ? (entry.winnerScore ?? "") : "")
                                railMarker(kind: .winner, active: entry.winnerSide == "player2", label: entry.winnerSide == "player2" ? (entry.winnerScore ?? "") : "")
                            }
                        }
                        .id(entry.id)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .frame(width: 48, height: 248)
            .onAppear {
                if let last = pointRailEntries.last?.id {
                    proxy.scrollTo(last, anchor: .bottom)
                }
            }
            .onChange(of: pointRailSignature) {
                if let last = pointRailEntries.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var matchHistoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if live?.gameHistory.isEmpty ?? true {
                    Text("No completed games yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    ForEach(live?.gameHistory ?? []) { game in
                        VStack(spacing: 4) {
                            Text("\(game.player1Score) - \(game.player2Score)")
                                .font(.subheadline.weight(.semibold))
                            Text(initials(for: game.winnerName))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 92)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func detailsCard(_ match: MatchDetail) -> some View {
        DisclosureGroup(isExpanded: $showDetails) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Updated \(formatDate(match.updatedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    detailItem("Server", value: live?.currentServer ?? "Not set")
                    detailItem("Service Side", value: live?.serviceSide ?? "Right")
                    detailItem("Referee", value: match.refereeName ?? "Not set")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Event Timeline")
                        .font(.headline)

                    if live?.events.isEmpty ?? true {
                        Text("No events yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(Array((live?.events ?? []).reversed())) { event in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.summary ?? event.eventType.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(.subheadline.weight(.semibold))
                                        if let createdAt = event.createdAt {
                                            Text(formatDate(createdAt))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                            }
                        }
                        .frame(maxHeight: 220)
                    }
                }
            }
            .padding(.top, 12)
        } label: {
            HStack {
                Text("Match Details")
                    .font(.headline)
                Spacer()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.rcktBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func playerCard(
        side: String,
        firstName: String,
        surname: String?,
        score: Int,
        games: Int,
        isServing: Bool,
        serviceSide: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(firstName)
                    .font(.title3.weight(.bold))
                if let surname, !surname.isEmpty {
                    Text(surname)
                        .font(.title3.weight(.bold))
                }
            }

            Text("\(score)")
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.white.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.24), lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Text("Games: \(games)")
                .font(.headline)

            HStack {
                if isServing {
                    Button {
                        Task { await toggleServeSide(current: serviceSide) }
                    } label: {
                        Text(serviceSide)
                            .font(.headline.weight(.semibold))
                            .frame(minWidth: 72)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.rcktServe)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isMutating || isMatchComplete)
                } else {
                    Capsule()
                        .fill(Color.clear)
                        .frame(width: 72, height: 42)
                }

                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
        .background(Color.rcktNavy)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            Task { await addPoint(for: side) }
        }
    }

    @ViewBuilder
    private func detailItem(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func statusPill(_ status: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(status.lowercased() == "active" ? Color.rcktActive : Color.gray.opacity(0.5))
                .frame(width: 12, height: 12)
            Text(status.capitalized)
                .font(.headline.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.rcktActive.opacity(0.18))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func railMarker(kind: RailMarkerKind, active: Bool, label: String) -> some View {
        ZStack {
            Circle()
                .fill(kind == .server && active ? Color.rcktServe : Color.clear)
                .overlay(
                    Circle()
                        .stroke(kind == .winner ? Color.rcktBlue : Color.clear, lineWidth: active ? 2.5 : 1.5)
                )
                .overlay(
                    Circle()
                        .stroke(Color.rcktBlue.opacity(active ? 0 : 0.18), lineWidth: active ? 0 : 1.5)
                )

            if active {
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(kind == .server ? .white : Color.rcktBlue)
            }
        }
        .frame(width: 20, height: 20)
    }

    @ViewBuilder
    private func controlButton(_ title: String, color: Color, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color)
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isMutating || (isMatchComplete && title != "Undo Last Action"))
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
                errorMessage = (error as? APIErrorResponse)?.message ?? "Unable to load the match."
                isLoading = false
            }
        }
    }

    private func addPoint(for side: String) async {
        guard !isMutating, !isMatchComplete else { return }
        await performMutation {
            try await container.apiClient.scorePoint(matchID: matchID, scorer: side)
        }
    }

    private func awardStroke(to side: String) async {
        guard !isMutating, !isMatchComplete else { return }
        await performMutation {
            try await container.apiClient.awardStroke(matchID: matchID, playerSide: side)
        }
    }

    private func callLet() async {
        guard !isMutating, !isMatchComplete else { return }
        await performMutation {
            try await container.apiClient.callLet(matchID: matchID)
        }
    }

    private func toggleServeSide(current: String) async {
        guard !isMutating, !isMatchComplete else { return }
        let nextSide = current.lowercased() == "left" ? "Right" : "Left"
        await performMutation {
            try await container.apiClient.setServeSide(matchID: matchID, side: nextSide)
        }
    }

    private func undoLastAction() async {
        guard !isMutating else { return }
        await performMutation {
            try await container.apiClient.undoAction(matchID: matchID)
        }
    }

    private func endMatchEarly() async {
        guard !isMutating, !isMatchComplete else { return }
        await performMutation {
            try await container.apiClient.endMatchEarly(matchID: matchID)
        }
    }

    private func performMutation(_ operation: @escaping () async throws -> MatchDetail) async {
        await MainActor.run {
            isMutating = true
            errorMessage = nil
        }

        do {
            let updatedMatch = try await operation()
            await MainActor.run {
                match = updatedMatch
                isMutating = false
            }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIErrorResponse)?.message ?? "Unable to update the match."
                isMutating = false
            }
        }
    }

    private func initials(for value: String?) -> String {
        guard let value else { return "--" }
        let parts = value
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return "--" }

        return parts.prefix(2)
            .compactMap { $0.first?.uppercased() }
            .joined()
    }

    private func formatDate(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: value) else {
            return value
        }

        return DateFormatter.matchMeta.string(from: date)
    }
}

private extension DateFormatter {
    static let matchMeta: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private extension Color {
    static let rcktBlue = Color(red: 18 / 255, green: 116 / 255, blue: 208 / 255)
    static let rcktNavy = Color(red: 28 / 255, green: 61 / 255, blue: 99 / 255)
    static let rcktSlate = Color(red: 77 / 255, green: 107 / 255, blue: 139 / 255)
    static let rcktDanger = Color(red: 214 / 255, green: 69 / 255, blue: 69 / 255)
    static let rcktServe = Color(red: 217 / 255, green: 130 / 255, blue: 43 / 255)
    static let rcktActive = Color(red: 82 / 255, green: 205 / 255, blue: 120 / 255)
    static let rcktBorder = Color(red: 217 / 255, green: 226 / 255, blue: 236 / 255)
}
