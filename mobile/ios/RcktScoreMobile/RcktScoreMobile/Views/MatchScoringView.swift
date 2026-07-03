import Combine
import SwiftUI

private let defaultWarmupSeconds = 60
private let intervalSeconds = 90
private let matchTimerStorageKeyPrefix = "rcktscore.matchTimer"
private let squashScoreTypeOptions = [11, 15]
private let tennisScoreTypeOptions = [4, 6]
private let bestOfOptions = [1, 3, 5]

private struct ShirtColorOption: Identifiable {
    let id: String
    let value: String
    let label: String
    let fill: Color
    let border: Color
}

private struct MatchGameSettingsForm {
    var scoreType: Int = 15
    var bestOf: Int = 5
    var player1ShirtColor: String = "navy"
    var player2ShirtColor: String = "white"
}

private enum MatchSheetSection {
    case details
    case settings
}

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
    let displaySideLabel: String
    let displayScore: String
    let isCurrentServe: Bool
}

private enum MatchActionSelection {
    case letAwarded
    case strokeAgainst
}

struct MatchScoringView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let matchID: String
    let openSettingsOnLoad: Bool

    @State private var match: MatchDetail?
    @State private var displayAccess: MatchDisplayAccess?
    @State private var isLoading = false
    @State private var isMutating = false
    @State private var errorMessage: String?
    @State private var showDetails = false
    @State private var showGameSettingsSheet = false
    @State private var selectedSheetSection: MatchSheetSection = .settings
    @State private var gameSettingsForm = MatchGameSettingsForm()
    @State private var timerPhase: MatchTimerPhase = .warmupReady
    @State private var timerSeconds = defaultWarmupSeconds
    @State private var matchDurationSeconds = 0
    @State private var timerRunning = false
    @State private var bootstrappedMatchID: String?
    @State private var previousGameHistoryCount = 0
    @State private var durationSyncedMatchID: String?
    @State private var settingsAutoloaded = false
    @State private var selectedOpeningServerParticipantID: String?
    @State private var selectedOpeningReceiverParticipantID: String?
    @State private var showActionMenu = false
    @State private var pendingActionSelection: MatchActionSelection?
    @State private var showPlayerActionSheet = false

    private let timerTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var live: MatchState? { match?.state }
    private var isTennisMatch: Bool {
        (match?.sport ?? "").lowercased() == "tennis" || (live?.scoreDisplayMode ?? "").lowercased() == "tennis"
    }
    private var isTennisDoublesMatch: Bool {
        isTennisMatch && (live?.teamFormat ?? "").lowercased() == "doubles"
    }
    private var warmupDurationSeconds: Int {
        isTennisMatch ? 300 : defaultWarmupSeconds
    }
    private var isPersonalAccount: Bool { container.sessionStore.session?.isPersonalAccount ?? false }
    private var canChoosePlayerShirtColors: Bool {
        container.sessionStore.session?.canChooseShirtColors ?? false
    }
    private var scoreboardURL: String {
        "https://app.hitnscore.com/scoreboard"
    }
    private var displayCode: String {
        displayAccess?.displayCode
            ?? match?.courtDisplayCode
            ?? ""
    }

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
        guard !isTennisMatch else {
            return false
        }

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
            return isTennisMatch ? "Warm-Up" : "Warm-Up: Side 1"
        case .warmupSideTwo:
            return "Warm-Up: Side 2"
        case .firstServer:
            return isTennisMatch ? "Serve & Receive" : "First Server"
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
            return isTennisMatch
                ? "Warm-up runs for 5 minutes before the opening serve and receiver are confirmed."
                : "Warm-up runs for 60 seconds on each side of the court."
        case .firstServer:
            return isTennisMatch
                ? "Choose the opening server and receiver to begin the live match clock."
                : "Choose the opening server to begin the live match clock."
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

    private var hasBootstrappedCurrentMatch: Bool {
        guard let match else {
            return false
        }

        return bootstrappedMatchID == match.id
    }

    private var showWarmupOverlay: Bool {
        guard hasBootstrappedCurrentMatch else {
            return false
        }

        switch timerPhase {
        case .warmupReady, .warmupSideOne, .warmupSideTwo, .firstServer:
            return !isMatchComplete
        default:
            return false
        }
    }

    private var showIntervalOverlay: Bool {
        hasBootstrappedCurrentMatch && timerPhase == .interval && !isMatchComplete
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
                displaySideLabel: serviceSideLabel.isEmpty ? "-" : serviceSideLabel,
                displayScore: winnerScore,
                isCurrentServe: false
            )
        }

        let currentScore: String
        if live?.currentServerSide == "player2" {
            currentScore = String(live?.player2Score ?? 0)
        } else {
            currentScore = String(live?.player1Score ?? 0)
        }

        let currentServe = PointRailEntry(
            id: "current-serve-\(match.id)-\(live?.currentServerSide ?? "player1")-\(live?.serviceSide ?? "Right")",
            serverSide: live?.currentServerSide,
            displaySideLabel: String(live?.serviceSide?.prefix(1) ?? "").uppercased(),
            displayScore: currentScore,
            isCurrentServe: true
        )

        return historyEntries + [currentServe]
    }

    private var tennisTeamOneParticipants: [TennisParticipant] {
        live?.tennisTeams?["player1"] ?? []
    }

    private var tennisTeamTwoParticipants: [TennisParticipant] {
        live?.tennisTeams?["player2"] ?? []
    }

    private var availableScoreTypeOptions: [Int] {
        isTennisMatch ? tennisScoreTypeOptions : squashScoreTypeOptions
    }

    private var pointRailSignature: String {
        pointRailEntries.map(\.id).joined(separator: "|")
    }

    private var startingScheduledLabel: String {
        isMutating ? "Starting..." : "Start Match"
    }

    private var scorerBackButton: some View {
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

    private var scorerTitleView: some View {
        Text(match?.courtName ?? "Live Match")
            .font(.headline.weight(.bold))
            .lineLimit(1)
    }

    private var scorerSettingsButton: some View {
        Button {
            openGameSettings()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.rcktBlue.opacity(0.12))
                .foregroundStyle(Color.rcktBlue)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isMutating || match == nil)
        .opacity((isMutating || match == nil) ? 0.72 : 1)
        .accessibilityLabel("Game Settings")
    }

    private var scorerHeaderBar: some View {
        HStack(spacing: 12) {
            scorerBackButton
            Spacer(minLength: 0)
            scorerTitleView
            Spacer(minLength: 0)
            scorerSettingsButton
        }
        .frame(maxWidth: .infinity)
    }

    private var playerOneActionLabel: String {
        fullName(firstName: match?.player1Name ?? "Player 1", surname: match?.player1Surname)
    }

    private var playerTwoActionLabel: String {
        fullName(firstName: match?.player2Name ?? "Player 2", surname: match?.player2Surname)
    }

    @ViewBuilder
    private var playerActionDialogButtons: some View {
        Button(playerOneActionLabel) {
            Task { await handlePendingActionSelection(for: "player1") }
        }

        Button(playerTwoActionLabel) {
            Task { await handlePendingActionSelection(for: "player2") }
        }

        Button("Cancel", role: .cancel) {
            pendingActionSelection = nil
            showPlayerActionSheet = false
        }
    }

    private var actionDialogTitle: String {
        switch pendingActionSelection {
        case .letAwarded:
            return "Award Let"
        case .strokeAgainst:
            return "Stroke Against"
        case nil:
            return "Choose Player"
        }
    }

    private var playerActionSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(actionDialogTitle)
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(playerOneActionLabel) {
                    Task { await handlePendingActionSelection(for: "player1") }
                }
                .buttonStyle(.borderedProminent)
                .tint(.rcktBlue)
                .frame(maxWidth: .infinity)

                Button(playerTwoActionLabel) {
                    Task { await handlePendingActionSelection(for: "player2") }
                }
                .buttonStyle(.borderedProminent)
                .tint(.rcktBlue)
                .frame(maxWidth: .infinity)

                Button("Cancel", role: .cancel) {
                    pendingActionSelection = nil
                    showPlayerActionSheet = false
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 0)
            }
            .padding(24)
            .navigationTitle("Choose Player")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var shirtColorOptions: [ShirtColorOption] {
        [
            ShirtColorOption(id: "navy", value: "navy", label: "Navy", fill: Color(red: 25/255, green: 66/255, blue: 121/255), border: Color(red: 18/255, green: 50/255, blue: 92/255)),
            ShirtColorOption(id: "blue", value: "blue", label: "Blue", fill: Color.blue, border: Color.blue.opacity(0.8)),
            ShirtColorOption(id: "red", value: "red", label: "Red", fill: Color.red, border: Color.red.opacity(0.8)),
            ShirtColorOption(id: "green", value: "green", label: "Green", fill: Color.green, border: Color.green.opacity(0.8)),
            ShirtColorOption(id: "black", value: "black", label: "Black", fill: Color.black, border: Color.gray.opacity(0.7)),
            ShirtColorOption(id: "white", value: "white", label: "White", fill: Color.white, border: Color.gray.opacity(0.7)),
            ShirtColorOption(id: "yellow", value: "yellow", label: "Yellow", fill: Color.yellow, border: Color.yellow.opacity(0.9)),
            ShirtColorOption(id: "orange", value: "orange", label: "Orange", fill: Color.orange, border: Color.orange.opacity(0.8)),
            ShirtColorOption(id: "purple", value: "purple", label: "Purple", fill: Color.purple, border: Color.purple.opacity(0.8)),
            ShirtColorOption(id: "pink", value: "pink", label: "Pink", fill: Color.pink, border: Color.pink.opacity(0.8))
        ]
    }

    init(matchID: String, openSettingsOnLoad: Bool = false) {
        self.matchID = matchID
        self.openSettingsOnLoad = openSettingsOnLoad
    }

    @ViewBuilder
    private func scoringCanvas(
        compactLayout: Bool,
        isTabletLandscape: Bool,
        bottomDockReservedHeight: CGFloat
    ) -> some View {
        ZStack {
            VStack(spacing: compactLayout ? 12 : 16) {
                scorerHeaderBar

                if isLoading && match == nil {
                    ProgressView("Loading match…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let match {
                    if isTabletLandscape {
                        landscapeScoringLayout(match)
                    } else {
                        scoreboardCard(
                            match,
                            compact: compactLayout,
                            showsInlineControls: false
                        )

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Spacer(minLength: 0)
                    }
                } else {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, compactLayout ? 12 : 16)
            .padding(.top, compactLayout ? 10 : 14)
            .padding(.bottom, bottomDockReservedHeight)

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
    }

    var body: some View {
        GeometryReader { geometry in
            let compactLayout = geometry.size.height < 760
            let isTabletLandscape = UIDevice.current.userInterfaceIdiom == .pad && geometry.size.width > geometry.size.height
            let bottomDockInset = max(geometry.safeAreaInsets.bottom, 10)
            let bottomDockHeight = bottomDockReservedHeight(
                compactLayout: compactLayout,
                isTabletLandscape: isTabletLandscape,
                bottomInset: bottomDockInset
            )

            ZStack(alignment: .bottom) {
                scoringCanvas(
                    compactLayout: compactLayout,
                    isTabletLandscape: isTabletLandscape,
                    bottomDockReservedHeight: match == nil ? 0 : bottomDockHeight
                )

                if match != nil {
                    bottomScoringDock(
                        compactLayout: compactLayout,
                        isTabletLandscape: isTabletLandscape
                    )
                    .padding(.horizontal, compactLayout ? 12 : 16)
                    .padding(.bottom, bottomDockInset)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
        .task {
            await loadMatch()
        }
        .task(id: match?.id) {
            await handleMatchIdentityTask()
        }
        .task(id: match?.id) {
            handleTimerBootstrapTask()
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
        .sheet(isPresented: $showGameSettingsSheet) {
            gameSettingsSheet
        }
        .sheet(isPresented: $showPlayerActionSheet) {
            playerActionSheet
        }
        .confirmationDialog("Match Action", isPresented: $showActionMenu, titleVisibility: .visible) {
            if !isTennisMatch {
                Button("Stroke") {
                    pendingActionSelection = .strokeAgainst
                    showPlayerActionSheet = true
                }
                .disabled(isMutating || timerPhase != .matchLive || isMatchComplete)

                Button("Let") {
                    pendingActionSelection = .letAwarded
                    showPlayerActionSheet = true
                }
                .disabled(isMutating || timerPhase != .matchLive || isMatchComplete)
            }

            Button("Undo Last Action") {
                Task { await undoLastAction() }
            }
            .disabled(isMutating || undoLocked)

            Button("End Match Early", role: .destructive) {
                Task { await endMatchEarly() }
            }
            .disabled(isMutating || isMatchComplete)

            Button("Cancel", role: .cancel) {
                pendingActionSelection = nil
            }
        }
    }

    @ViewBuilder
    private func landscapeScoringLayout(_ match: MatchDetail) -> some View {
        VStack(spacing: 14) {
            scoreboardCard(
                match,
                compact: false,
                landscapeTablet: true
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func scoreboardCard(
        _ match: MatchDetail,
        compact: Bool,
        showsInlineControls: Bool = false,
        landscapeTablet: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 12) {
            scoreSummaryBanner(match, compact: compact)

            if match.status.lowercased() == "scheduled" {
                HStack {
                    Spacer()

                    Button(startingScheduledLabel) {
                        Task { await startScheduledMatchFromScorer() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.rcktBlue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                    .disabled(isMutating)
                    .opacity(isMutating ? 0.72 : 1)

                    Spacer()
                }
                .padding(.horizontal, compact ? 12 : 16)
            }

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    playerHeaderStrip(
                        firstName: match.player1Name,
                        surname: match.player1Surname,
                        isServing: live?.currentServerSide == "player1",
                        serviceSide: live?.serviceSide ?? "Right",
                        sport: match.sport ?? "",
                        shirtColorValue: shirtColorValue(for: "player1", match: match),
                        compact: compact,
                        landscapeTablet: landscapeTablet
                    )

                    playerHeaderStrip(
                        firstName: match.player2Name,
                        surname: match.player2Surname,
                        isServing: live?.currentServerSide == "player2",
                        serviceSide: live?.serviceSide ?? "Right",
                        sport: match.sport ?? "",
                        shirtColorValue: shirtColorValue(for: "player2", match: match),
                        compact: compact,
                        landscapeTablet: landscapeTablet
                    )
                }

                HStack(alignment: .top) {
                    playerCard(
                        side: "player1",
                        score: live?.player1Score ?? 0,
                        scoreLabel: displayScoreLabel(for: "player1"),
                        games: live?.player1GamesWon ?? 0,
                        currentSetGames: live?.player1SetGames ?? 0,
                        sport: match.sport ?? "",
                        shirtColorValue: shirtColorValue(for: "player1", match: match),
                        compact: compact,
                        landscapeTablet: landscapeTablet
                    )

                    Spacer(minLength: landscapeTablet ? 16 : (compact ? 8 : 12))

                    pointRail(compact: compact, landscapeTablet: landscapeTablet)

                    Spacer(minLength: landscapeTablet ? 16 : (compact ? 8 : 12))

                    playerCard(
                        side: "player2",
                        score: live?.player2Score ?? 0,
                        scoreLabel: displayScoreLabel(for: "player2"),
                        games: live?.player2GamesWon ?? 0,
                        currentSetGames: live?.player2SetGames ?? 0,
                        sport: match.sport ?? "",
                        shirtColorValue: shirtColorValue(for: "player2", match: match),
                        compact: compact,
                        landscapeTablet: landscapeTablet
                    )
                }
                .padding(.horizontal, landscapeTablet ? 12 : (compact ? 6 : 8))
                .padding(.top, landscapeTablet ? 16 : (compact ? 10 : 12))
                .padding(.bottom, landscapeTablet ? 18 : (compact ? 12 : 14))
            }

            matchHistoryStrip
                .padding(.horizontal, compact ? 12 : 16)
        }
        .padding(.top, compact ? 8 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rcktCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.rcktBorder, lineWidth: 1)
        )
        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.05), radius: 16, x: 0, y: 8)
    }

    private func bottomTimerActionBar(compactLayout: Bool, isTabletLandscape: Bool) -> some View {
        HStack(spacing: 14) {
            bottomTimerControl(compactLayout: compactLayout, isTabletLandscape: isTabletLandscape)
            bottomActionControl(compactLayout: compactLayout, isTabletLandscape: isTabletLandscape)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func bottomScoringDock(compactLayout: Bool, isTabletLandscape: Bool) -> some View {
        VStack(spacing: 6) {
            bottomTimerActionBar(compactLayout: compactLayout, isTabletLandscape: isTabletLandscape)

            if let timerSkipLabel {
                Button(timerSkipLabel) {
                    handleSkipTimedPhase()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.rcktBlue)
                .disabled(isMatchComplete)
            }
        }
        .padding(.horizontal, compactLayout ? 10 : 12)
        .padding(.top, compactLayout ? 8 : 10)
        .padding(.bottom, compactLayout ? 8 : 10)
        .background(Color.rcktCardBackground.opacity(colorScheme == .dark ? 0.94 : 0.98))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.rcktBorder, lineWidth: 1)
        )
        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
    }

    private func bottomTimerControl(compactLayout: Bool, isTabletLandscape: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                handleToggleTimer()
            } label: {
                Text(timerPhase == .warmupReady ? "Start Warm-Up" : formatSeconds(displayedTimerSeconds))
                    .font(.system(size: isTabletLandscape ? 28 : (compactLayout ? 21 : 24), weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isTabletLandscape ? 16 : (compactLayout ? 12 : 14))
                    .background(timerChipBackgroundColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isMatchComplete || timerPhase == .firstServer)
            .opacity((isMatchComplete || timerPhase == .firstServer) ? 0.8 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compactLayout ? 10 : 12)
        .background(Color.rcktCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.rcktBorder, lineWidth: 1)
        )
    }

    private func bottomActionControl(compactLayout: Bool, isTabletLandscape: Bool) -> some View {
        Button {
            showActionMenu = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.headline.weight(.bold))
                Text("Action")
                    .font(.headline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isTabletLandscape ? 20 : (compactLayout ? 16 : 18))
            .background(Color.rcktSlate)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(width: isTabletLandscape ? 200 : (compactLayout ? 124 : 142))
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
                Text(isTennisMatch ? "Serve & Receive" : "First Server")
                    .font(.title2.weight(.bold))

                Text(
                    isTennisMatch
                        ? "Choose the opening server and the opening receiver. The match begins after this selection."
                        : "Choose which player starts serving. The match begins after this selection."
                )
                    .font(.body)
                    .foregroundStyle(.secondary)

                if isTennisMatch {
                    tennisOpeningSelectionOverlay(match)
                } else {
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

    @ViewBuilder
    private func tennisOpeningSelectionOverlay(_ match: MatchDetail) -> some View {
        let serverParticipants = isTennisDoublesMatch
            ? (tennisTeamOneParticipants + tennisTeamTwoParticipants)
            : [
                TennisParticipant(id: "team1_player1", firstName: match.player1Name, surname: match.player1Surname, displayName: fullName(firstName: match.player1Name, surname: match.player1Surname)),
                TennisParticipant(id: "team2_player1", firstName: match.player2Name, surname: match.player2Surname, displayName: fullName(firstName: match.player2Name, surname: match.player2Surname)),
            ]
        let receivingParticipants = openingReceiverCandidates(for: selectedOpeningServerParticipantID, match: match)

        VStack(alignment: .leading, spacing: 14) {
            Text("Opening Server")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            ForEach(serverParticipants, id: \.id) { participant in
                selectionOverlayButton(
                    title: participant.displayName,
                    isSelected: selectedOpeningServerParticipantID == participant.id
                ) {
                    selectedOpeningServerParticipantID = participant.id
                    if let selectedReceiver = selectedOpeningReceiverParticipantID,
                       !receivingParticipants.map(\.id).contains(selectedReceiver) {
                        selectedOpeningReceiverParticipantID = nil
                    }
                }
            }

            Text("Opening Receiver")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.top, 4)

            ForEach(receivingParticipants, id: \.id) { participant in
                selectionOverlayButton(
                    title: participant.displayName,
                    isSelected: selectedOpeningReceiverParticipantID == participant.id
                ) {
                    selectedOpeningReceiverParticipantID = participant.id
                }
            }

            Button {
                Task { await chooseTennisOpeningOrder(using: match) }
            } label: {
                Text("Begin Match")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.rcktBlue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(
                isMutating
                    || selectedOpeningServerParticipantID == nil
                    || selectedOpeningReceiverParticipantID == nil
            )
            .opacity(
                (isMutating || selectedOpeningServerParticipantID == nil || selectedOpeningReceiverParticipantID == nil) ? 0.7 : 1
            )
            .padding(.top, 6)
        }
    }

    private func selectionOverlayButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 10)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? Color.rcktBlue : Color.rcktSlate)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
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
    private func pointRail(compact: Bool, landscapeTablet: Bool) -> some View {
        let isTabletPortrait = UIDevice.current.userInterfaceIdiom == .pad && !landscapeTablet
        let railHeight: CGFloat = {
            if landscapeTablet {
                return 360
            }
            if isTabletPortrait {
                return 520
            }
            return compact ? 360 : 420
        }()

        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: landscapeTablet ? 14 : (compact ? 10 : 12)) {
                    ForEach(pointRailEntries) { entry in
                        HStack {
                            if entry.serverSide == "player1" {
                                pointRailSlot(
                                    for: entry,
                                    side: "player1",
                                    compact: compact,
                                    landscapeTablet: landscapeTablet
                                )
                            } else {
                                Spacer(minLength: 0)
                            }

                            Rectangle()
                                .fill(Color.rcktBorder.opacity(0.9))
                                .frame(width: 1)
                                .padding(.vertical, 4)

                            if entry.serverSide == "player2" {
                                pointRailSlot(
                                    for: entry,
                                    side: "player2",
                                    compact: compact,
                                    landscapeTablet: landscapeTablet
                                )
                            } else {
                                Spacer(minLength: 0)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .id(entry.id)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .frame(
                width: landscapeTablet ? 264 : (isTabletPortrait ? 150 : (compact ? 120 : 140)),
                height: railHeight
            )
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
    private func pointRailSlot(
        for entry: PointRailEntry,
        side: String,
        compact: Bool,
        landscapeTablet: Bool
    ) -> some View {
        HStack(spacing: landscapeTablet ? 10 : 8) {
            scoreSheetMarker(
                label: entry.displaySideLabel,
                isCurrentServe: entry.isCurrentServe,
                accent: timelineAccent(for: side),
                compact: compact,
                landscapeTablet: landscapeTablet
            )
            scoreSheetMarker(
                label: entry.displayScore,
                isCurrentServe: entry.isCurrentServe,
                accent: timelineAccent(for: side),
                compact: compact,
                landscapeTablet: landscapeTablet
            )
        }
        .frame(maxWidth: .infinity, alignment: side == "player1" ? .trailing : .leading)
    }

    @ViewBuilder
    private func scoreSummaryBanner(_ match: MatchDetail, compact: Bool) -> some View {
        ZStack {
            Text(scoreSummaryText(for: match))
                .font(compact ? .footnote.weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(Color.rcktBlue)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Circle()
                    .fill(Color.rcktActive)
                    .frame(width: compact ? 8 : 10, height: compact ? 8 : 10)
                Spacer()
            }
        }
        .padding(.horizontal, compact ? 12 : 14)
        .padding(.vertical, compact ? 10 : 12)
        .background(Color.rcktBlue.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, compact ? 4 : 6)
    }

    private func scoreSummaryText(for match: MatchDetail) -> String {
        if isTennisMatch {
            return "First to \(live?.scoreType ?? match.scoreType) Games • Set \(live?.currentGameNumber ?? 1) • Best of \(live?.bestOf ?? match.bestOf)"
        }

        return "Score to \(match.scoreType) • Game \(live?.currentGameNumber ?? 1) • Best of \(live?.bestOf ?? match.bestOf)"
    }

    private func displayScoreLabel(for side: String) -> String {
        if side == "player1" {
            return live?.player1ScoreLabel ?? "\(live?.player1Score ?? 0)"
        }

        return live?.player2ScoreLabel ?? "\(live?.player2Score ?? 0)"
    }

    @ViewBuilder
    private var matchHistoryStrip: some View {
        if let gameHistory = live?.gameHistory, !gameHistory.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(gameHistory) { game in
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
    private func detailsCard(_ match: MatchDetail, compact: Bool) -> some View {
        DisclosureGroup(isExpanded: $showDetails) {
            matchDetailsContent(match)
                .padding(.top, 12)
        } label: {
            HStack {
                Text("Match Details")
                    .font(.headline)
                Spacer()
            }
        }
        .padding(compact ? 14 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rcktCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.rcktBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func matchDetailsContent(_ match: MatchDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Updated \(formatDate(match.updatedAt))")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                detailItem("Server", value: live?.currentServer ?? "Not set")
                detailItem("Service Side", value: live?.serviceSide ?? "Right")
                detailItem("Referee", value: match.refereeName ?? "Not set")
            }

            HStack(spacing: 12) {
                detailItem("Match Format", value: isTennisMatch ? "Best of \(live?.bestOf ?? match.bestOf) Sets" : "Best of \(live?.bestOf ?? match.bestOf)")
                detailItem("Game Format", value: isTennisMatch ? "First to \(live?.scoreType ?? match.scoreType) Games" : "PAR-\(live?.scoreType ?? match.scoreType)")
                detailItem("Court Alias", value: match.courtAlias ?? "Not set")
            }

            if canChoosePlayerShirtColors {
                HStack(spacing: 12) {
                    detailItem("P1 Shirt", value: (live?.player1ShirtColor ?? match.player1ShirtColor ?? "navy").capitalized)
                    detailItem("P2 Shirt", value: (live?.player2ShirtColor ?? match.player2ShirtColor ?? "white").capitalized)
                }
            }

            if displayedTimerSeconds > 0 {
                detailItem("Match Time", value: formatSeconds(displayedTimerSeconds))
            }

            if !isPersonalAccount {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Spectator Display")
                        .font(.headline)

                    detailItem("Scoreboard URL", value: scoreboardURL)
                    detailItem("Court Display Code", value: displayCode.isEmpty ? "Not available" : displayCode)
                }
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
    }

    @ViewBuilder
    private func playerHeaderStrip(
        firstName: String,
        surname: String?,
        isServing: Bool,
        serviceSide: String,
        sport: String,
        shirtColorValue: String,
        compact: Bool,
        landscapeTablet: Bool
    ) -> some View {
        let foreground = shirtForegroundColor(for: shirtColorValue)
        let isTennisHeader = sport.lowercased() == "tennis"

        VStack(spacing: compact ? 8 : 10) {
            Text(fullName(firstName: firstName, surname: surname))
                .font(.system(size: landscapeTablet ? 24 : (compact ? 19 : 21), weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            HStack {
                Spacer(minLength: 0)
                if isServing {
                    if isTennisHeader {
                        Text("Serving")
                            .font(.subheadline.weight(.semibold))
                            .frame(minWidth: compact ? 62 : 68)
                            .padding(.horizontal, compact ? 10 : 12)
                            .padding(.vertical, compact ? 7 : 8)
                            .background(.white)
                            .foregroundStyle(.black)
                            .overlay(
                                Capsule()
                                    .stroke(Color.rcktCompleted, lineWidth: 2)
                            )
                            .clipShape(Capsule())
                    } else {
                        Button {
                            Task { await toggleServeSide(current: serviceSide) }
                        } label: {
                            Text(serviceSide)
                                .font(.subheadline.weight(.semibold))
                                .frame(minWidth: compact ? 62 : 68)
                                .padding(.horizontal, compact ? 10 : 12)
                                .padding(.vertical, compact ? 7 : 8)
                                .background(.white)
                                .foregroundStyle(.black)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.rcktCompleted, lineWidth: 2)
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isMutating || isMatchComplete || !canToggleCurrentServeSide)
                        .opacity(canToggleCurrentServeSide ? 1 : 0.72)
                    }
                } else {
                    Capsule()
                        .fill(Color.clear)
                        .frame(width: compact ? 62 : 68, height: compact ? 34 : 36)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, compact ? 14 : 16)
        .padding(.vertical, landscapeTablet ? 18 : (compact ? 12 : 14))
        .frame(maxWidth: .infinity, minHeight: landscapeTablet ? 122 : (compact ? 92 : 102), alignment: .center)
        .background(shirtFillColor(for: shirtColorValue))
        .foregroundStyle(foreground)
    }

    @ViewBuilder
    private func playerCard(
        side: String,
        score: Int,
        scoreLabel: String,
        games: Int,
        currentSetGames: Int,
        sport: String,
        shirtColorValue: String,
        compact: Bool,
        landscapeTablet: Bool
    ) -> some View {
        let isTennisCard = sport.lowercased() == "tennis"

        VStack(spacing: compact ? 8 : 10) {
            Text(scoreLabel.isEmpty ? "\(score)" : scoreLabel)
                .font(.system(size: landscapeTablet ? 56 : (compact ? 40 : 46), weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, landscapeTablet ? 18 : (compact ? 10 : 12))
                .background(Color.white.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: landscapeTablet ? 22 : 18, style: .continuous)
                        .stroke(Color.white.opacity(0.24), lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: landscapeTablet ? 22 : 18, style: .continuous))

            Text(isTennisCard ? "Games: \(currentSetGames)" : "Games: \(games)")
                .font(landscapeTablet ? .subheadline.weight(.semibold) : (compact ? .footnote.weight(.semibold) : .subheadline.weight(.semibold)))
                .frame(maxWidth: .infinity, alignment: .center)

            if isTennisCard {
                Text("Sets: \(games)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal, landscapeTablet ? 14 : (compact ? 10 : 12))
        .padding(.vertical, landscapeTablet ? 18 : (compact ? 12 : 14))
        .frame(width: landscapeTablet ? 182 : (compact ? 118 : 128))
        .frame(minHeight: landscapeTablet ? 232 : (compact ? 148 : 164), alignment: .top)
        .background(shirtFillColor(for: shirtColorValue))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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

    private func shirtColorValue(for side: String, match: MatchDetail) -> String {
        if side == "player1" {
            return live?.player1ShirtColor ?? match.player1ShirtColor ?? "navy"
        }

        return live?.player2ShirtColor ?? match.player2ShirtColor ?? "white"
    }

    private func shirtFillColor(for value: String) -> Color {
        shirtColorOptions.first(where: { $0.value == value.lowercased() })?.fill ?? Color.rcktNavy
    }

    private func shirtForegroundColor(for value: String) -> Color {
        switch value.lowercased() {
        case "white", "yellow", "pink":
            return .black
        default:
            return .white
        }
    }

    @ViewBuilder
    private func statusPill(_ status: String, compact: Bool = false) -> some View {
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
                .frame(width: compact ? 10 : 12, height: compact ? 10 : 12)
            Text(status.capitalized)
                .font((compact ? Font.subheadline : Font.headline).weight(.semibold))
        }
        .padding(.horizontal, compact ? 12 : 14)
        .padding(.vertical, compact ? 8 : 10)
        .background(backgroundColor)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func scoreSheetMarker(
        label: String,
        isCurrentServe: Bool,
        accent: Color,
        compact: Bool,
        landscapeTablet: Bool
    ) -> some View {
        Text(label)
            .font(.system(size: landscapeTablet ? 20 : (compact ? 15 : 17), weight: .bold, design: .rounded))
            .frame(
                width: landscapeTablet ? 48 : (compact ? 34 : 38),
                height: landscapeTablet ? 44 : (compact ? 32 : 34)
            )
            .background(
                RoundedRectangle(cornerRadius: landscapeTablet ? 14 : 12, style: .continuous)
                    .fill(isCurrentServe ? accent : Color.rcktCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: landscapeTablet ? 14 : 12, style: .continuous)
                    .stroke(accent, lineWidth: 2)
            )
            .foregroundStyle(isCurrentServe ? Color.white : accent)
    }

    private func timelineAccent(for side: String) -> Color {
        side == "player1" ? .rcktPink : .rcktBlue
    }

    private func bottomDockReservedHeight(
        compactLayout: Bool,
        isTabletLandscape: Bool,
        bottomInset: CGFloat
    ) -> CGFloat {
        let contentHeight: CGFloat
        if isTabletLandscape {
            contentHeight = timerSkipLabel == nil ? 98 : 126
        } else if compactLayout {
            contentHeight = timerSkipLabel == nil ? 88 : 116
        } else {
            contentHeight = timerSkipLabel == nil ? 94 : 122
        }

        return contentHeight + bottomInset
    }

    @ViewBuilder
    private func controlButton(
        _ title: String,
        color: Color,
        isDisabled: Bool,
        compact: Bool,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(compact ? .subheadline.weight(.semibold) : .headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? 12 : 14)
                .background(color)
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.72 : 1)
    }

    @ViewBuilder
    private var matchSettingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Match Format")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Match Format", selection: $gameSettingsForm.bestOf) {
                    ForEach(bestOfOptions, id: \.self) { option in
                        Text("Best of \(option)").tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Game Format")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Game Format", selection: $gameSettingsForm.scoreType) {
                    ForEach(availableScoreTypeOptions, id: \.self) { option in
                        Text(isTennisMatch ? "First to \(option)" : "PAR-\(option)").tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            if canChoosePlayerShirtColors {
                shirtColorEditor(
                    title: "Player 1 Shirt",
                    selection: $gameSettingsForm.player1ShirtColor
                )
                shirtColorEditor(
                    title: "Player 2 Shirt",
                    selection: $gameSettingsForm.player2ShirtColor
                )
            }
        }
    }

    private var gameSettingsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        sheetSectionButton("Match Details", section: .details)
                        sheetSectionButton("Match Settings", section: .settings)
                    }

                    if selectedSheetSection == .details {
                        if let match {
                            matchDetailsContent(match)
                        } else {
                            ProgressView("Loading match…")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        matchSettingsContent
                    }

                    if let errorMessage {
                        dashboardLikeError(errorMessage)
                    }
                }
                .padding()
            }
            .navigationTitle("Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showGameSettingsSheet = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.bold))
                    }
                }
                if selectedSheetSection == .settings {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isMutating ? "Saving..." : "Save") {
                            Task { await saveGameSettings() }
                        }
                        .disabled(isMutating)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func sheetSectionButton(_ title: String, section: MatchSheetSection) -> some View {
        Button {
            selectedSheetSection = section
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedSheetSection == section ? Color.rcktBlue : Color(.secondarySystemBackground))
                .foregroundStyle(selectedSheetSection == section ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func shirtColorEditor(title: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                ForEach(shirtColorOptions) { option in
                    Button {
                        selection.wrappedValue = option.value
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(option.fill)
                                .frame(width: 18, height: 18)
                                .overlay(Circle().stroke(option.border, lineWidth: 1))
                            Text(option.label)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(selection.wrappedValue == option.value ? Color.rcktBlue.opacity(0.12) : Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(selection.wrappedValue == option.value ? Color.rcktBlue : Color.rcktBorder, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func dashboardLikeError(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var warmupOverlayMessage: String {
        switch timerPhase {
        case .warmupReady:
            return isTennisMatch
                ? "Start a single 5 minute warm-up, then confirm the opening server and receiver."
                : "Start 60 seconds on side 1, swap sides for another 60 seconds, then choose the first server."
        case .warmupSideTwo:
            return "Side 1 is complete. Players should change sides while the second warm-up runs."
        default:
            return isTennisMatch
                ? "Warm-up is running. Keep this screen open until the opening serve and return are confirmed."
                : "Warm-up is running. Keep this screen open until the first server is selected."
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

    private func loadDisplayAccessIfNeeded() async {
        guard !isPersonalAccount else {
            await MainActor.run {
                displayAccess = nil
            }
            return
        }

        do {
            let access = try await container.apiClient.getMatchDisplayAccess(matchID: matchID)
            await MainActor.run {
                displayAccess = access
            }
        } catch {
            await MainActor.run {
                displayAccess = nil
            }
        }
    }

    private func autoOpenSettingsIfNeeded() {
        guard openSettingsOnLoad, !settingsAutoloaded, match != nil else {
            return
        }

        settingsAutoloaded = true
        openGameSettings()
    }

    private func openGameSettings() {
        let currentMatch = match
        selectedSheetSection = .settings
        gameSettingsForm = MatchGameSettingsForm(
            scoreType: currentMatch?.scoreType ?? live?.scoreType ?? 15,
            bestOf: currentMatch?.bestOf ?? live?.bestOf ?? 5,
            player1ShirtColor: currentMatch?.player1ShirtColor
                ?? live?.player1ShirtColor
                ?? "navy",
            player2ShirtColor: currentMatch?.player2ShirtColor
                ?? live?.player2ShirtColor
                ?? "white"
        )
        showGameSettingsSheet = true
    }

    private func saveGameSettings() async {
        await performMutation {
            try await container.apiClient.updateMatchSettings(
                matchID: matchID,
                scoreType: gameSettingsForm.scoreType,
                bestOf: gameSettingsForm.bestOf,
                player1ShirtColor: canChoosePlayerShirtColors ? gameSettingsForm.player1ShirtColor : nil,
                player2ShirtColor: canChoosePlayerShirtColors ? gameSettingsForm.player2ShirtColor : nil
            )
        }

        await MainActor.run {
            if errorMessage == nil {
                showGameSettingsSheet = false
            }
        }
    }

    private func startScheduledMatchFromScorer() async {
        guard match?.status.lowercased() == "scheduled" else {
            return
        }

        await performMutation {
            try await container.apiClient.startScheduledMatch(matchID: matchID)
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
            timerSeconds = warmupDurationSeconds
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
            if isTennisMatch {
                timerPhase = .firstServer
                timerSeconds = 0
                timerRunning = false
            } else {
                timerPhase = .warmupSideTwo
                timerSeconds = warmupDurationSeconds
                timerRunning = true
            }
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
        timerSeconds = warmupDurationSeconds
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

    private func chooseTennisOpeningOrder(using match: MatchDetail) async {
        guard !isMutating,
              let serverParticipantID = selectedOpeningServerParticipantID,
              let receiverParticipantID = selectedOpeningReceiverParticipantID else {
            return
        }

        let serverSide = serverParticipantID.hasPrefix("team1") ? "player1" : "player2"
        let receiverSide = receiverParticipantID.hasPrefix("team1") ? "player1" : "player2"
        guard serverSide != receiverSide else {
            await MainActor.run {
                errorMessage = "The opening receiver must be on the opposite team."
            }
            return
        }

        let currentServer = tennisParticipantDisplayName(serverParticipantID, match: match)
        let currentReceiver = tennisParticipantDisplayName(receiverParticipantID, match: match)
        let serviceSide = "Right"
        let serveOrder = openingServeOrder(startingServerParticipantID: serverParticipantID)
        let receiverDeuceOrder = openingReceiverDeuceOrder(
            serverParticipantID: serverParticipantID,
            receiverParticipantID: receiverParticipantID
        )

        await performMutation {
            try await container.apiClient.selectFirstServer(
                matchID: matchID,
                currentServer: currentServer,
                currentServerSide: serverSide,
                serviceSide: serviceSide,
                currentServerParticipantID: serverParticipantID,
                currentReceiver: currentReceiver,
                currentReceiverSide: receiverSide,
                currentReceiverParticipantID: receiverParticipantID,
                serveOrder: serveOrder,
                receiverDeuceOrder: receiverDeuceOrder
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

    private func callLet(awardedTo side: String? = nil) async {
        guard !isMutating, !isMatchComplete, timerPhase == .matchLive else { return }
        await performMutation {
            try await container.apiClient.callLet(
                matchID: matchID,
                playerSide: side,
                note: side.map { "Let awarded to \($0)" } ?? "General let"
            )
        }
    }

    private func handlePendingActionSelection(for side: String) async {
        let action = pendingActionSelection
        pendingActionSelection = nil
        showPlayerActionSheet = false

        switch action {
        case .letAwarded:
            await callLet(awardedTo: side)
        case .strokeAgainst:
            let awardedSide = side == "player1" ? "player2" : "player1"
            await awardStroke(to: awardedSide)
        case nil:
            break
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

    private func handleMatchIdentityTask() async {
        await loadDisplayAccessIfNeeded()
        await MainActor.run {
            autoOpenSettingsIfNeeded()
        }
    }

    private func handleTimerBootstrapTask() {
        guard let match else {
            return
        }

        bootstrapTimerIfNeeded(for: match)
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

    private func tennisParticipantDisplayName(_ participantID: String, match: MatchDetail) -> String {
        let allParticipants = tennisTeamOneParticipants + tennisTeamTwoParticipants
        if let participant = allParticipants.first(where: { $0.id == participantID }) {
            return participant.displayName
        }

        switch participantID {
        case "team1_player1":
            return fullName(firstName: match.player1Name, surname: match.player1Surname)
        case "team2_player1":
            return fullName(firstName: match.player2Name, surname: match.player2Surname)
        default:
            return participantID
        }
    }

    private func openingReceiverCandidates(for serverParticipantID: String?, match: MatchDetail) -> [TennisParticipant] {
        guard let serverParticipantID else {
            if isTennisDoublesMatch {
                return []
            }
            return [
                TennisParticipant(id: "team2_player1", firstName: match.player2Name, surname: match.player2Surname, displayName: fullName(firstName: match.player2Name, surname: match.player2Surname)),
                TennisParticipant(id: "team1_player1", firstName: match.player1Name, surname: match.player1Surname, displayName: fullName(firstName: match.player1Name, surname: match.player1Surname)),
            ]
        }

        let serverIsTeamOne = serverParticipantID.hasPrefix("team1")
        if isTennisDoublesMatch {
            return serverIsTeamOne ? tennisTeamTwoParticipants : tennisTeamOneParticipants
        }

        if serverIsTeamOne {
            return [
                TennisParticipant(id: "team2_player1", firstName: match.player2Name, surname: match.player2Surname, displayName: fullName(firstName: match.player2Name, surname: match.player2Surname))
            ]
        }

        return [
            TennisParticipant(id: "team1_player1", firstName: match.player1Name, surname: match.player1Surname, displayName: fullName(firstName: match.player1Name, surname: match.player1Surname))
        ]
    }

    private func openingServeOrder(startingServerParticipantID: String) -> [String] {
        let teamOne = tennisTeamOneParticipants.map(\.id)
        let teamTwo = tennisTeamTwoParticipants.map(\.id)
        let serverIsTeamOne = startingServerParticipantID.hasPrefix("team1")
        let servingTeam = rotatedParticipantIDs(
            serverIsTeamOne ? teamOne : teamTwo,
            startingAt: startingServerParticipantID
        )
        let receivingTeam = serverIsTeamOne ? teamTwo : teamOne

        var order: [String] = []
        let maxCount = max(servingTeam.count, receivingTeam.count)
        for index in 0..<maxCount {
            if index < servingTeam.count {
                order.append(servingTeam[index])
            }
            if index < receivingTeam.count {
                order.append(receivingTeam[index])
            }
        }
        return order
    }

    private func openingReceiverDeuceOrder(
        serverParticipantID: String,
        receiverParticipantID: String
    ) -> [String: String] {
        let serverSide = serverParticipantID.hasPrefix("team1") ? "player1" : "player2"
        let receiverSide = receiverParticipantID.hasPrefix("team1") ? "player1" : "player2"

        var result: [String: String] = [:]
        result[receiverSide] = receiverParticipantID

        let defaultServerSideReceiver: String?
        if serverSide == "player1" {
            defaultServerSideReceiver = tennisTeamOneParticipants.first?.id
        } else {
            defaultServerSideReceiver = tennisTeamTwoParticipants.first?.id
        }
        if let defaultServerSideReceiver {
            result[serverSide] = defaultServerSideReceiver
        }

        return result
    }

    private func rotatedParticipantIDs(_ ids: [String], startingAt target: String) -> [String] {
        guard let index = ids.firstIndex(of: target) else {
            return ids
        }
        return Array(ids[index...] + ids[..<index])
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
        let minutes = String(format: "%02d", max(0, value) / 60)
        let seconds = String(format: "%02d", max(0, value) % 60)
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
                    if isTennisMatch {
                        phase = .firstServer
                        seconds = 0
                        running = false
                        remainingElapsed = 0
                        continue
                    }
                    phase = .warmupSideTwo
                    seconds = warmupDurationSeconds
                    continue
                }
                if remainingElapsed >= seconds {
                    remainingElapsed -= seconds
                    if isTennisMatch {
                        phase = .firstServer
                        seconds = 0
                        running = false
                        remainingElapsed = 0
                    } else {
                        phase = .warmupSideTwo
                        seconds = warmupDurationSeconds
                    }
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
    static let rcktPink = Color(red: 236 / 255, green: 94 / 255, blue: 168 / 255)
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
