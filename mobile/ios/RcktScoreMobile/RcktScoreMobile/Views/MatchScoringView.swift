import Combine
import SwiftUI

private let warmupSeconds = 60
private let intervalSeconds = 90
private let matchTimerStorageKeyPrefix = "rcktscore.matchTimer"

private enum MatchTimerPhase: String, Codable {
    case warmupReady = "warmup_ready"
    case warmupSideOne = "warmup_side_one"
    case warmupSideTwo = "warmup_side_two"
    case firstServer = "first_server"
    case interval
    case matchLive = "match_live"
}

private struct MatchTimerSnapshot: Codable {
    let phase: MatchTimerPhase
    let running: Bool
    let seconds: Int
    let matchDurationSeconds: Int
    let updatedAt: TimeInterval
}

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
    @Environment(\.colorScheme) private var colorScheme

    let matchID: String

    @State private var match: MatchDetail?
    @State private var isLoading = false
    @State private var isMutating = false
    @State private var errorMessage: String?
    @State private var showDetails = false
    @State private var timerPhase: MatchTimerPhase = .warmupReady
    @State private var timerSeconds = warmupSeconds
    @State private var matchDurationSeconds = 0
    @State private var timerRunning = false
    @State private var bootstrappedMatchID: String?
    @State private var previousGameHistoryCount = 0
    @State private var durationSyncedMatchID: String?

    private let timerTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var live: MatchState? { match?.state }
    private var isPersonalAccount: Bool { container.sessionStore.session?.isPersonalAccount ?? false }

    private var isMatchComplete: Bool {
        live?.matchComplete == true || match?.status.lowercased() == "completed"
    }

    private var undoLocked: Bool {
        guard isMatchComplete, let completedAt = parseISODate(match?.completedAt) else {
            return false
        }

        return Date().timeIntervalSince(completedAt) > 300
    }

    private var canToggleCurrentServeSide: Bool {
        guard timerPhase == .matchLive else {
            return false
        }

        return canCurrentServerChooseServiceSide(
            events: live?.events ?? [],
            serverSide: live?.currentServerSide ?? "player1"
        )
    }

    private var recordedMatchDurationSeconds: Int {
        live?.matchDurationSeconds ?? match?.matchDurationSeconds ?? 0
    }

    private var displayedTimerSeconds: Int {
        if isMatchComplete {
            return max(recordedMatchDurationSeconds, matchDurationSeconds)
        }

        return timerPhase == .matchLive ? matchDurationSeconds : timerSeconds
    }

    private var timerLabel: String {
        if isMatchComplete {
            return "Match Time"
        }

        switch timerPhase {
        case .warmupReady:
            return "Warm-Up Ready"
        case .warmupSideOne:
            return "Warm-Up: Side 1"
        case .warmupSideTwo:
            return "Warm-Up: Side 2"
        case .firstServer:
            return "First Server"
        case .interval:
            return "Game Break - 90s"
        case .matchLive:
            return "Match Time"
        }
    }

    private var timerHelperText: String {
        if isMatchComplete {
            return recordedMatchDurationSeconds > 0
                ? "Recorded total match time: \(formatSeconds(recordedMatchDurationSeconds))"
                : "Recording total match time..."
        }

        switch timerPhase {
        case .warmupReady:
            return "Warm-up starts when both players are ready."
        case .warmupSideOne, .warmupSideTwo:
            return "Warm-up runs for 60 seconds on each side of the court."
        case .firstServer:
            return "Choose the opening server to begin the live match clock."
        case .interval:
            return "90 second break between games."
        case .matchLive:
            return "Tap the clock to pause or resume the match."
        }
    }

    private var timerSkipLabel: String? {
        switch timerPhase {
        case .warmupSideOne, .warmupSideTwo:
            return "Skip Warm-Up"
        case .interval:
            return "Skip Break"
        default:
            return nil
        }
    }

    private var showWarmupOverlay: Bool {
        switch timerPhase {
        case .warmupReady, .warmupSideOne, .warmupSideTwo, .firstServer:
            return !isMatchComplete
        default:
            return false
        }
    }

    private var showIntervalOverlay: Bool {
        timerPhase == .interval && !isMatchComplete
    }

    private var isWarmupCountdownWarning: Bool {
        timerRunning
            && (timerPhase == .warmupSideOne || timerPhase == .warmupSideTwo)
            && timerSeconds <= 10
            && timerSeconds > 0
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
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading && match == nil {
                        ProgressView("Loading match…")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let match {
                        scoreboardCard(match)
                        timerCard

                        if !isPersonalAccount {
                            detailsCard(match)
                        }
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

            if showWarmupOverlay {
                overlayBackdrop {
                    warmupOverlay
                }
            }

            if showIntervalOverlay {
                overlayBackdrop {
                    intervalOverlay
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(match?.courtName ?? "Live Match")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMatch()
        }
        .task(id: match?.id) {
            if let match {
                bootstrapTimerIfNeeded(for: match)
            }
        }
        .onChange(of: live?.gameHistory.count ?? 0) {
            syncIntervalState()
        }
        .onChange(of: isMatchComplete) {
            syncCompletedMatchTimer()
        }
        .onChange(of: timerPhase) {
            persistTimerState()
        }
        .onChange(of: timerRunning) {
            persistTimerState()
        }
        .onChange(of: timerSeconds) {
            persistTimerState()
        }
        .onChange(of: matchDurationSeconds) {
            persistTimerState()
        }
        .onReceive(timerTicker) { _ in
            advanceTimerTick()
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
                    controlButton("Stroke P1", color: .rcktSlate, isDisabled: isMutating || timerPhase != .matchLive || isMatchComplete) {
                        await awardStroke(to: "player1")
                    }
                    controlButton("Let", color: .rcktSlate, isDisabled: isMutating || timerPhase != .matchLive || isMatchComplete) {
                        await callLet()
                    }
                    controlButton("Stroke P2", color: .rcktSlate, isDisabled: isMutating || timerPhase != .matchLive || isMatchComplete) {
                        await awardStroke(to: "player2")
                    }
                }

                HStack(spacing: 10) {
                    controlButton("Undo Last Action", color: .rcktDanger, isDisabled: isMutating || undoLocked) {
                        await undoLastAction()
                    }
                    controlButton("End Match Early", color: .rcktDanger, isDisabled: isMutating || isMatchComplete) {
                        await endMatchEarly()
                    }
                }
            }
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

    private var timerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Match Timer")
                    .font(.headline)
                Spacer()
                if timerPhase == .matchLive && !isMatchComplete {
                    Text(timerRunning ? "Running" : "Paused")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(timerRunning ? Color.rcktActive : .secondary)
                }
            }

            Text(timerLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Button {
                handleToggleTimer()
            } label: {
                Text(timerPhase == .warmupReady ? "Start Warm-Up" : formatSeconds(displayedTimerSeconds))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(timerChipBackgroundColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isMatchComplete || timerPhase == .firstServer)
            .opacity((isMatchComplete || timerPhase == .firstServer) ? 0.8 : 1)

            Text(timerHelperText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let timerSkipLabel {
                Button(timerSkipLabel) {
                    handleSkipTimedPhase()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.rcktBlue)
                .disabled(isMatchComplete)
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

    @ViewBuilder
    private func overlayBackdrop<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()

            content()
                .padding(.horizontal, 22)
        }
    }

    @ViewBuilder
    private var warmupOverlay: some View {
        if timerPhase == .firstServer, let match {
            VStack(alignment: .leading, spacing: 18) {
                Text("First Server")
                    .font(.title2.weight(.bold))

                Text("Choose which player starts serving. The match begins after this selection.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    Button {
                        Task { await chooseFirstServer("player1", using: match) }
                    } label: {
                        Text(fullName(firstName: match.player1Name, surname: match.player1Surname))
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.rcktBlue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isMutating)

                    Button {
                        Task { await chooseFirstServer("player2", using: match) }
                    } label: {
                        Text(fullName(firstName: match.player2Name, surname: match.player2Surname))
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.rcktSlate)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isMutating)
                }
            }
            .padding(24)
            .frame(maxWidth: 420, alignment: .leading)
            .background(Color.rcktCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.rcktBorder, lineWidth: 1)
            )
        } else {
            VStack(alignment: .leading, spacing: 18) {
                Text(timerPhase == .warmupSideTwo ? "Change Sides" : "Warm-Up")
                    .font(.title2.weight(.bold))

                Text(warmupOverlayMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)

                if timerPhase == .warmupReady {
                    HStack(spacing: 12) {
                        Button("Start Warm-Up") {
                            handleStartWarmup()
                        }
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.rcktBlue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        Button("Skip Warm-Up") {
                            handleSkipWarmup()
                        }
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.rcktSlate)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                } else {
                    Button {
                        handleToggleTimer()
                    } label: {
                        Text(formatSeconds(displayedTimerSeconds))
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(timerChipBackgroundColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button("Skip Warm-Up") {
                        handleSkipTimedPhase()
                    }
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.rcktSlate)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding(24)
            .frame(maxWidth: 420, alignment: .leading)
            .background(Color.rcktCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.rcktBorder, lineWidth: 1)
            )
        }
    }

    private var intervalOverlay: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Game Break")
                .font(.title2.weight(.bold))

            Text("90 second interval between games. Tap the clock to pause or resume if needed.")
                .font(.body)
                .foregroundStyle(.secondary)

            Button {
                handleToggleTimer()
            } label: {
                Text(formatSeconds(displayedTimerSeconds))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(timerChipBackgroundColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)

            Button("Skip Break") {
                handleSkipTimedPhase()
            }
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.rcktSlate)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(24)
        .frame(maxWidth: 420, alignment: .leading)
        .background(Color.rcktCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.rcktBorder, lineWidth: 1)
        )
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
                    Text("Playing")
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

                if displayedTimerSeconds > 0 {
                    detailItem("Match Time", value: formatSeconds(displayedTimerSeconds))
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
        .background(Color.rcktCardBackground)
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
                    .disabled(isMutating || isMatchComplete || !canToggleCurrentServeSide)
                    .opacity(canToggleCurrentServeSide ? 1 : 0.72)
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
        let loweredStatus = status.lowercased()
        let indicatorColor: Color = loweredStatus == "completed"
            ? .rcktCompleted
            : (loweredStatus == "active" ? .rcktActive : .gray.opacity(0.5))
        let backgroundColor: Color = loweredStatus == "completed"
            ? .rcktCompleted.opacity(0.18)
            : .rcktActive.opacity(0.18)

        HStack(spacing: 8) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 12, height: 12)
            Text(status.capitalized)
                .font(.headline.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(backgroundColor)
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
    private func controlButton(
        _ title: String,
        color: Color,
        isDisabled: Bool,
        action: @escaping () async -> Void
    ) -> some View {
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
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.72 : 1)
    }

    private var warmupOverlayMessage: String {
        switch timerPhase {
        case .warmupReady:
            return "Start 60 seconds on side 1, swap sides for another 60 seconds, then choose the first server."
        case .warmupSideTwo:
            return "Side 1 is complete. Players should change sides while the second warm-up runs."
        default:
            return "Warm-up is running. Keep this screen open until the first server is selected."
        }
    }

    private var timerChipBackgroundColor: Color {
        if timerPhase == .interval {
            return Color.rcktServe
        }

        if isWarmupCountdownWarning {
            return Color.rcktDanger
        }

        if timerPhase == .matchLive {
            return timerRunning ? Color.rcktBlue : Color.rcktSlate
        }

        return timerRunning ? Color.rcktBlue : Color.rcktSlate
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

    private func bootstrapTimerIfNeeded(for match: MatchDetail) {
        guard bootstrappedMatchID != match.id else {
            return
        }

        bootstrappedMatchID = match.id
        previousGameHistoryCount = live?.gameHistory.count ?? 0
        durationSyncedMatchID = nil

        if let storedState = readStoredTimerState(matchID: match.id) {
            let advancedState = advanceTimerSnapshot(storedState)
            timerPhase = advancedState.phase
            timerSeconds = advancedState.seconds
            matchDurationSeconds = advancedState.matchDurationSeconds
            timerRunning = advancedState.running
            return
        }

        if isMatchComplete {
            let duration = max(recordedMatchDurationSeconds, 0)
            timerPhase = .matchLive
            timerSeconds = duration
            matchDurationSeconds = duration
            timerRunning = false
            return
        }

        if isFreshMatch(match) {
            timerPhase = .warmupReady
            timerSeconds = warmupSeconds
            matchDurationSeconds = 0
            timerRunning = false
            return
        }

        let duration = max(recordedMatchDurationSeconds, 0)
        timerPhase = .matchLive
        timerSeconds = duration
        matchDurationSeconds = duration
        timerRunning = true
    }

    private func syncIntervalState() {
        guard let match, bootstrappedMatchID == match.id else {
            return
        }

        let currentCount = live?.gameHistory.count ?? 0
        let previousCount = previousGameHistoryCount

        if currentCount > previousCount {
            previousGameHistoryCount = currentCount

            if !isMatchComplete {
                timerPhase = .interval
                timerSeconds = intervalSeconds
                timerRunning = true
            }
            return
        }

        previousGameHistoryCount = currentCount
    }

    private func syncCompletedMatchTimer() {
        guard isMatchComplete, let match else {
            return
        }

        timerRunning = false
        clearStoredTimerState(matchID: match.id)

        if recordedMatchDurationSeconds > 0 {
            matchDurationSeconds = recordedMatchDurationSeconds
            timerSeconds = recordedMatchDurationSeconds
            durationSyncedMatchID = match.id
            return
        }

        if durationSyncedMatchID == match.id {
            return
        }

        let finalDuration = max(0, resolveMatchDurationSeconds())
        matchDurationSeconds = finalDuration
        timerSeconds = finalDuration
        durationSyncedMatchID = match.id

        guard finalDuration > 0 else {
            return
        }

        Task {
            await recordMatchDuration(finalDuration)
        }
    }

    private func persistTimerState() {
        guard let match else {
            return
        }

        if isMatchComplete {
            clearStoredTimerState(matchID: match.id)
            return
        }

        let snapshot = MatchTimerSnapshot(
            phase: timerPhase,
            running: timerRunning,
            seconds: timerSeconds,
            matchDurationSeconds: matchDurationSeconds,
            updatedAt: Date().timeIntervalSince1970
        )
        writeStoredTimerState(snapshot, matchID: match.id)
    }

    private func advanceTimerTick() {
        guard timerRunning else {
            return
        }

        switch timerPhase {
        case .matchLive:
            matchDurationSeconds += 1
            timerSeconds = matchDurationSeconds
        case .warmupSideOne, .warmupSideTwo, .interval:
            timerSeconds = max(0, timerSeconds - 1)
            if timerSeconds == 0 {
                handleElapsedTimedPhase()
            }
        case .warmupReady, .firstServer:
            timerRunning = false
        }
    }

    private func handleElapsedTimedPhase() {
        switch timerPhase {
        case .warmupSideOne:
            timerPhase = .warmupSideTwo
            timerSeconds = warmupSeconds
            timerRunning = true
        case .warmupSideTwo:
            timerPhase = .firstServer
            timerSeconds = 0
            timerRunning = false
        case .interval:
            timerPhase = .matchLive
            timerSeconds = matchDurationSeconds
            timerRunning = true
        case .warmupReady, .firstServer, .matchLive:
            break
        }
    }

    private func handleToggleTimer() {
        guard !isMatchComplete else {
            return
        }

        if timerPhase == .warmupReady {
            handleStartWarmup()
            return
        }

        guard timerPhase != .firstServer else {
            return
        }

        timerRunning.toggle()
    }

    private func handleStartWarmup() {
        timerPhase = .warmupSideOne
        timerSeconds = warmupSeconds
        matchDurationSeconds = 0
        timerRunning = true
    }

    private func handleSkipWarmup() {
        timerPhase = .firstServer
        timerSeconds = 0
        timerRunning = false
    }

    private func handleSkipTimedPhase() {
        switch timerPhase {
        case .warmupSideOne, .warmupSideTwo:
            timerPhase = .firstServer
            timerSeconds = 0
            timerRunning = false
        case .interval:
            timerPhase = .matchLive
            timerSeconds = matchDurationSeconds
            timerRunning = true
        default:
            break
        }
    }

    private func chooseFirstServer(_ playerSide: String, using match: MatchDetail) async {
        guard !isMutating else { return }

        let selectedPlayerName = playerSide == "player2" ? match.player2Name : match.player1Name
        let receiverHandedness = playerSide == "player2" ? match.player1Handedness : match.player2Handedness
        let serviceSide = receiverHandedness?.lowercased() == "left" ? "Left" : "Right"

        await performMutation {
            try await container.apiClient.selectFirstServer(
                matchID: matchID,
                currentServer: selectedPlayerName,
                currentServerSide: playerSide,
                serviceSide: serviceSide
            )
        }

        await MainActor.run {
            if errorMessage == nil {
                timerPhase = .matchLive
                timerSeconds = matchDurationSeconds
                timerRunning = true
            }
        }
    }

    private func resolveMatchDurationSeconds() -> Int {
        if timerPhase == .matchLive {
            return matchDurationSeconds
        }

        if let match, let storedState = readStoredTimerState(matchID: match.id) {
            return advanceTimerSnapshot(storedState).matchDurationSeconds
        }

        return max(recordedMatchDurationSeconds, matchDurationSeconds)
    }

    private func addPoint(for side: String) async {
        guard !isMutating, !isMatchComplete, timerPhase == .matchLive else { return }
        await performMutation {
            try await container.apiClient.scorePoint(matchID: matchID, scorer: side)
        }
    }

    private func awardStroke(to side: String) async {
        guard !isMutating, !isMatchComplete, timerPhase == .matchLive else { return }
        await performMutation {
            try await container.apiClient.awardStroke(matchID: matchID, playerSide: side)
        }
    }

    private func callLet() async {
        guard !isMutating, !isMatchComplete, timerPhase == .matchLive else { return }
        await performMutation {
            try await container.apiClient.callLet(matchID: matchID)
        }
    }

    private func toggleServeSide(current: String) async {
        guard !isMutating, !isMatchComplete, timerPhase == .matchLive else { return }
        let nextSide = current.lowercased() == "left" ? "Right" : "Left"
        await performMutation {
            try await container.apiClient.setServeSide(matchID: matchID, side: nextSide)
        }
    }

    private func undoLastAction() async {
        guard !isMutating, !undoLocked else { return }
        await performMutation {
            try await container.apiClient.undoAction(matchID: matchID)
        }
    }

    private func endMatchEarly() async {
        guard !isMutating, !isMatchComplete else { return }

        let finalDuration = max(0, resolveMatchDurationSeconds())
        timerRunning = false
        timerSeconds = finalDuration
        matchDurationSeconds = finalDuration

        await performMutation {
            try await container.apiClient.endMatchEarly(
                matchID: matchID,
                matchDurationSeconds: finalDuration
            )
        }
    }

    private func recordMatchDuration(_ durationSeconds: Int) async {
        await performMutation {
            try await container.apiClient.recordMatchDuration(matchID: matchID, durationSeconds: durationSeconds)
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

    private func findServerBeforeEvent(_ events: [MatchEvent], eventIndex: Int) -> String {
        guard eventIndex > 0 else { return "player1" }

        for index in stride(from: eventIndex - 1, through: 0, by: -1) {
            let event = events[index]

            if event.eventType == "server", let currentServerSide = event.payload?.currentServerSide {
                return currentServerSide
            }

            if ["score_point", "stroke"].contains(event.eventType), let currentServerSide = event.payload?.currentServerSide {
                return currentServerSide
            }
        }

        return "player1"
    }

    private func canCurrentServerChooseServiceSide(events: [MatchEvent], serverSide: String) -> Bool {
        var latestScoringEventIndex: Int?
        for index in stride(from: events.count - 1, through: 0, by: -1) {
            if ["score_point", "stroke"].contains(events[index].eventType) {
                latestScoringEventIndex = index
                break
            }
        }

        guard let latestScoringEventIndex else {
            return true
        }

        let latestScoringEvent = events[latestScoringEventIndex]
        if latestScoringEvent.payload?.gameCompleted == true && latestScoringEvent.payload?.matchCompleted != true {
            return true
        }

        let previousServerSide = findServerBeforeEvent(events, eventIndex: latestScoringEventIndex)
        let scorerSide = latestScoringEvent.payload?.scorer ?? latestScoringEvent.payload?.playerSide
        let serverAfterRally = latestScoringEvent.payload?.currentServerSide ?? scorerSide

        if serverAfterRally != serverSide {
            return true
        }

        return scorerSide != previousServerSide
    }

    private func isFreshMatch(_ match: MatchDetail) -> Bool {
        let state = match.state
        let events = state?.events ?? []

        return (state?.currentGameNumber ?? 1) == 1
            && (state?.player1Score ?? 0) == 0
            && (state?.player2Score ?? 0) == 0
            && (state?.gameHistory ?? []).isEmpty
            && events.count <= 1
    }

    private func fullName(firstName: String, surname: String?) -> String {
        guard let surname, !surname.isEmpty else {
            return firstName
        }

        return "\(firstName) \(surname)"
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
        guard let date = parseISODate(value) else {
            return value
        }

        return DateFormatter.matchMeta.string(from: date)
    }

    private func formatSeconds(_ value: Int) -> String {
        let minutes = String(max(0, value) / 60).padding(toLength: 2, withPad: "0", startingAt: 0)
        let seconds = String(max(0, value) % 60).padding(toLength: 2, withPad: "0", startingAt: 0)
        return "\(minutes):\(seconds)"
    }

    private func timerStorageKey(for matchID: String) -> String {
        "\(matchTimerStorageKeyPrefix).\(matchID)"
    }

    private func readStoredTimerState(matchID: String) -> MatchTimerSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: timerStorageKey(for: matchID)) else {
            return nil
        }

        return try? JSONDecoder().decode(MatchTimerSnapshot.self, from: data)
    }

    private func writeStoredTimerState(_ snapshot: MatchTimerSnapshot, matchID: String) {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }

        UserDefaults.standard.set(data, forKey: timerStorageKey(for: matchID))
    }

    private func clearStoredTimerState(matchID: String) {
        UserDefaults.standard.removeObject(forKey: timerStorageKey(for: matchID))
    }

    private func advanceTimerSnapshot(_ snapshot: MatchTimerSnapshot) -> MatchTimerSnapshot {
        guard snapshot.running else {
            return snapshot
        }

        let elapsed = max(0, Int(Date().timeIntervalSince1970 - snapshot.updatedAt))
        guard elapsed > 0 else {
            return snapshot
        }

        var phase = snapshot.phase
        var running = snapshot.running
        var seconds = snapshot.seconds
        var duration = snapshot.matchDurationSeconds
        var remainingElapsed = elapsed

        while remainingElapsed > 0 {
            switch phase {
            case .warmupReady:
                running = false
                remainingElapsed = 0
            case .warmupSideOne:
                if seconds <= 0 {
                    phase = .warmupSideTwo
                    seconds = warmupSeconds
                    continue
                }
                if remainingElapsed >= seconds {
                    remainingElapsed -= seconds
                    phase = .warmupSideTwo
                    seconds = warmupSeconds
                } else {
                    seconds -= remainingElapsed
                    remainingElapsed = 0
                }
            case .warmupSideTwo:
                if seconds <= 0 {
                    phase = .firstServer
                    seconds = 0
                    running = false
                    remainingElapsed = 0
                    continue
                }
                if remainingElapsed >= seconds {
                    remainingElapsed -= seconds
                    phase = .firstServer
                    seconds = 0
                    running = false
                    remainingElapsed = 0
                } else {
                    seconds -= remainingElapsed
                    remainingElapsed = 0
                }
            case .firstServer:
                running = false
                remainingElapsed = 0
            case .interval:
                if seconds <= 0 {
                    phase = .matchLive
                    seconds = duration
                    continue
                }
                if remainingElapsed >= seconds {
                    remainingElapsed -= seconds
                    phase = .matchLive
                    seconds = duration
                } else {
                    seconds -= remainingElapsed
                    remainingElapsed = 0
                }
            case .matchLive:
                duration += remainingElapsed
                seconds = duration
                remainingElapsed = 0
            }
        }

        if phase == .matchLive {
            seconds = duration
        }

        return MatchTimerSnapshot(
            phase: phase,
            running: running,
            seconds: seconds,
            matchDurationSeconds: duration,
            updatedAt: Date().timeIntervalSince1970
        )
    }

    private func parseISODate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
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
