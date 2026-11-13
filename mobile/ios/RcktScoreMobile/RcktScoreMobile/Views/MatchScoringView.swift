import Combine
import SwiftUI

private let defaultWarmupSeconds = 60
private let intervalSeconds = 90
private let tennisSetIntervalSeconds = 120
private let scoringTapDebounceMilliseconds = 150
private let matchTimerStorageKeyPrefix = "rcktscore.matchTimer"
private let squashScoreTypeOptions = [11, 15]
private let tennisScoreTypeOptions = [6]
private let bestOfOptions = [1, 3, 5]

private struct ShirtColorOption: Identifiable {
    let id: String
    let value: String
    let label: String
    let fill: Color
    let border: Color
}

private struct StrokeLetHexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.75))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.75))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25))
        path.closeSubpath()
        return path
    }
}

private struct ScoringShirtColorGridPicker: View {
    @Binding var selection: String
    let options: [ShirtColorOption]
    @State private var isPresented = false

    private var selected: ShirtColorOption {
        options.first(where: { $0.value == selection }) ?? options[0]
    }

    var body: some View {
        Button { isPresented = true } label: {
            Circle()
                .fill(selected.fill)
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(selected.border, lineWidth: 1.5))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(38), spacing: 8), count: 5), spacing: 10) {
                ForEach(options) { option in
                    Button {
                        selection = option.value
                        isPresented = false
                    } label: {
                        Circle()
                            .fill(option.fill)
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(option.border, lineWidth: 1.5))
                            .overlay {
                                if option.value == selection {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.heavy))
                                        .foregroundStyle(["white", "yellow", "pink"].contains(option.value) ? .black : .white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.label)
                }
            }
            .padding(14)
            .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("Shirt colour")
        .accessibilityValue(selected.label)
    }
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
    let intervalDurationSeconds: Int?
    let updatedAt: TimeInterval
}

private enum MatchActionSelection {
    case letAwarded
    case strokeAgainst
}

struct MatchScoringView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass

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
    @State private var previousTennisGameCompletionSignature: String?
    @State private var activeIntervalDurationSeconds = intervalSeconds
    @State private var durationSyncedMatchID: String?
    @State private var settingsAutoloaded = false
    @State private var selectedOpeningServerParticipantID: String?
    @State private var selectedOpeningReceiverParticipantID: String?
    @State private var showActionMenu = false
    @State private var pendingActionSelection: MatchActionSelection?
    @State private var showEndMatchConfirmation = false
    @State private var showEventTimeline = false
    @State private var showStrokeLetHelp = false
    @State private var showTakeOverConfirmation = false
    @AppStorage("hitnscore.strokeLetHelpEnabled") private var strokeLetHelpEnabled = false

    private let timerTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var live: MatchState? {
        container.offlineMatchStore.projectedState(matchID: matchID) ?? match?.state
    }
    private var isOnline: Bool { container.networkMonitor.isOnline }
    private var canManageMatches: Bool { container.sessionStore.session?.canManageMatches ?? false }
    private var canScoreThisMatch: Bool {
        canManageMatches && match?.scoringAccess?.canScore != false
    }
    private var canTakeOverScoring: Bool {
        match?.scoringAccess?.canTakeOver == true
    }
    private var isTennisMatch: Bool {
        ["tennis", "padel"].contains((match?.sport ?? "").lowercased())
            || (live?.scoreDisplayMode ?? "").lowercased() == "tennis"
    }
    private var isPadelMatch: Bool {
        (match?.sport ?? "").lowercased() == "padel"
    }
    private var isTennisDoublesMatch: Bool {
        isTennisMatch && (live?.teamFormat ?? "").lowercased() == "doubles"
    }
    private var warmupDurationSeconds: Int {
        if isTennisMatch { return 300 }
        if (match?.sport ?? "").lowercased() == "racketball" { return 150 }
        return 120
    }
    private var latestTennisGameCompletionEvent: MatchEvent? {
        live?.events.last(where: { $0.payload?.tennisGameCompleted == true })
    }
    private var latestTennisGameCompletionSignature: String? {
        guard let payload = latestTennisGameCompletionEvent?.payload,
              let setNumber = payload.gameNumber,
              let gameNumber = payload.completedGameNumber else {
            return nil
        }

        return [
            String(setNumber),
            String(gameNumber),
            String(payload.completedGamePlayer1Games ?? 0),
            String(payload.completedGamePlayer2Games ?? 0),
            payload.setCompleted == true ? "set" : "game",
        ].joined(separator: ":")
    }
    private var intervalObservationSignature: String {
        "\(live?.gameHistory.count ?? 0)|\(latestTennisGameCompletionSignature ?? "none")"
    }
    private var isPersonalAccount: Bool { container.sessionStore.session?.isPersonalAccount ?? false }
    private var isPersonalPlus: Bool {
        let session = container.sessionStore.session
        if (session?.plan ?? "").lowercased() == "personal_plus" { return true }
        return session?.availableMemberships?.contains {
            ($0.plan ?? "").lowercased() == "personal_plus"
        } ?? false
    }
    private var canUseRemoteMatchViewing: Bool {
        isPersonalAccount && isPersonalPlus
    }
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
    private var viewerCode: String {
        displayAccess?.viewerCode ?? ""
    }

    private var isMatchComplete: Bool {
        live?.matchComplete == true || match?.status.lowercased() == "completed"
    }

    private var isScheduledMatch: Bool {
        match?.status.lowercased() == "scheduled"
    }

    private var undoLocked: Bool {
        guard isMatchComplete, let completedAt = parseISODate(match?.completedAt) else {
            return false
        }

        return Date().timeIntervalSince(completedAt) > 300
    }

    private var canToggleCurrentServeSide: Bool {
        guard !isTennisMatch, !isScheduledMatch else {
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
            return isTennisMatch
                ? (isTennisDoublesMatch ? "Serve & Receive" : "Opening Server")
                : "First Server"
        case .interval:
            if isTennisMatch {
                return activeIntervalDurationSeconds == tennisSetIntervalSeconds
                    ? "Set Break - 120s"
                    : "Changeover - 90s"
            }
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
                ? "Warm-up runs for 5 minutes before the opening server is confirmed."
                : "Warm-up runs for 60 seconds on each side of the court."
        case .firstServer:
            return isTennisMatch
                ? (isTennisDoublesMatch
                    ? "Choose the opening server and receiver to begin the live match clock."
                    : "Choose the opening server to begin the live match clock.")
                : "Choose the opening server to begin the live match clock."
        case .interval:
            if isTennisMatch {
                return activeIntervalDurationSeconds == tennisSetIntervalSeconds
                    ? "120 second break between sets."
                    : "90 second changeover after this odd-numbered game."
            }
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

    private var intervalOverlayTitle: String {
        guard isTennisMatch else { return "Game Break" }
        return activeIntervalDurationSeconds == tennisSetIntervalSeconds
            ? "Set Break"
            : "Changeover"
    }

    private var intervalOverlayMessage: String {
        guard isTennisMatch else {
            return "90 second interval between games. Tap the clock to pause or resume if needed."
        }
        return activeIntervalDurationSeconds == tennisSetIntervalSeconds
            ? "120 second break between sets. Tap the clock to pause or resume if needed."
            : "90 second changeover after this odd-numbered game. Tap the clock to pause or resume if needed."
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

    private var isPhoneLandscapeLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .phone && verticalSizeClass == .compact
    }

    private var isWarmupCountdownWarning: Bool {
        timerRunning
            && (timerPhase == .warmupSideOne || timerPhase == .warmupSideTwo)
            && timerSeconds <= 10
            && timerSeconds > 0
    }

    private var pointRailEntries: [RacketPointRailEntry] {
        guard let match else { return [] }
        let currentGameNumber = live?.currentGameNumber ?? 1
        var historyEntries: [RacketPointRailEntry] = []
        var lastPlayer1Score = match.player1Offset
        var lastPlayer2Score = match.player2Offset
        var lastServerSide = "player1"
        var lastServiceSide = match.player2Handedness?.lowercased() == "left" ? "Left" : "Right"

        for event in live?.events ?? [] {
            if event.eventType == "match_started" {
                lastPlayer1Score = event.payload?.player1Score ?? lastPlayer1Score
                lastPlayer2Score = event.payload?.player2Score ?? lastPlayer2Score
                lastServerSide = event.payload?.currentServerSide ?? lastServerSide
                lastServiceSide = event.payload?.serviceSide ?? lastServiceSide
            } else if ["score_point", "stroke"].contains(event.eventType) {
                let winnerSide = event.payload?.scorer ?? event.payload?.playerSide
                let serverSide = event.payload?.currentServerSide ?? winnerSide
                let serviceSideLabel = String(event.payload?.serviceSide?.prefix(1) ?? "").uppercased()
                let winnerScore: String

                if winnerSide == "player1" {
                    winnerScore = String(event.payload?.gameResult?.player1Score ?? event.payload?.player1Score ?? 0)
                } else {
                    winnerScore = String(event.payload?.gameResult?.player2Score ?? event.payload?.player2Score ?? 0)
                }

                if event.payload?.gameNumber == currentGameNumber {
                    if event.eventType == "stroke" {
                        historyEntries.append(
                            RacketPointRailEntry(
                                id: "\(event.id)-decision",
                                serverSide: serverSide,
                                displaySide: winnerSide ?? serverSide ?? "player1",
                                displaySideLabel: "",
                                displayScore: "",
                                isCurrentServe: false,
                                actionLabel: "Stroke"
                            )
                        )
                    }
                    historyEntries.append(
                        RacketPointRailEntry(
                            id: event.id,
                            serverSide: serverSide,
                            displaySide: winnerSide ?? serverSide ?? "player1",
                            displaySideLabel: serviceSideLabel.isEmpty ? "-" : serviceSideLabel,
                            displayScore: winnerScore,
                            isCurrentServe: false,
                            actionLabel: nil
                        )
                    )
                }

                lastPlayer1Score = event.payload?.player1Score ?? lastPlayer1Score
                lastPlayer2Score = event.payload?.player2Score ?? lastPlayer2Score
                lastServerSide = serverSide ?? lastServerSide
                lastServiceSide = event.payload?.serviceSide ?? lastServiceSide
            } else if event.eventType == "let" {
                let requestingSide = event.payload?.playerSide ?? lastServerSide
                let serverSide = event.payload?.currentServerSide ?? lastServerSide
                let serviceSide = event.payload?.serviceSide ?? lastServiceSide
                let player1Score = event.payload?.player1Score ?? lastPlayer1Score
                let player2Score = event.payload?.player2Score ?? lastPlayer2Score
                let gameNumber = event.payload?.gameNumber ?? currentGameNumber

                if gameNumber == currentGameNumber {
                    historyEntries.append(
                        RacketPointRailEntry(
                            id: "\(event.id)-decision",
                            serverSide: serverSide,
                            displaySide: requestingSide,
                            displaySideLabel: "",
                            displayScore: "",
                            isCurrentServe: false,
                            actionLabel: "Let"
                        )
                    )
                    historyEntries.append(
                        RacketPointRailEntry(
                            id: "\(event.id)-resume",
                            serverSide: serverSide,
                            displaySide: serverSide,
                            displaySideLabel: String(serviceSide.prefix(1)).uppercased(),
                            displayScore: serverSide == "player1" ? String(player1Score) : String(player2Score),
                            isCurrentServe: false,
                            actionLabel: nil
                        )
                    )
                }
            } else if event.eventType == "serve_side" {
                let side = event.payload?.side ?? event.payload?.serviceSide ?? "Right"
                historyEntries = RacketPointRailReducer.replacingLatestServiceSide(
                    in: historyEntries,
                    sideLabel: String(side.prefix(1)).uppercased(),
                    eventID: event.id
                )
                lastServiceSide = side
            } else if event.eventType == "server" {
                lastServerSide = event.payload?.currentServerSide ?? lastServerSide
                lastServiceSide = event.payload?.serviceSide ?? lastServiceSide
            }
        }

        let currentScore: String
        if live?.currentServerSide == "player2" {
            currentScore = String(live?.player2Score ?? 0)
        } else {
            currentScore = String(live?.player1Score ?? 0)
        }

        let currentServe = RacketPointRailEntry(
            id: "current-serve-\(match.id)-\(live?.currentServerSide ?? "player1")-\(live?.serviceSide ?? "Right")",
            serverSide: live?.currentServerSide,
            displaySide: live?.currentServerSide ?? "player1",
            displaySideLabel: String(live?.serviceSide?.prefix(1) ?? "").uppercased(),
            displayScore: currentScore,
            isCurrentServe: true,
            actionLabel: nil
        )

        return RacketPointRailReducer.reconcile(
            history: historyEntries,
            currentServe: currentServe
        )
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
            Image(systemName: "chevron.left")
            .font(.headline.weight(.bold))
            .frame(width: 40, height: 40)
            .background(Color.rcktBlue.opacity(0.12))
            .foregroundStyle(Color.rcktBlue)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
        .accessibilityIdentifier("scoring.backButton")
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
            Image(systemName: "gearshape.fill")
                .font(.headline.weight(.bold))
                .frame(width: 44, height: 44)
                .background(Color.rcktBlue.opacity(0.12))
                .foregroundStyle(Color.rcktBlue)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isMutating || match == nil || !canScoreThisMatch)
        .opacity((isMutating || match == nil || !canScoreThisMatch) ? 0.72 : 1)
        .accessibilityLabel("Game Settings")
        .accessibilityIdentifier("scoring.gameSettingsButton")
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

    private var scorerLockBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(canTakeOverScoring ? "Another scorer controls this match" : "Match scoring is locked")
                .font(.headline.weight(.bold))
            Text(canTakeOverScoring
                ? "As a club administrator, you can transfer scoring control to this account. The previous scorer will be locked out."
                : "Another club scorer is controlling this match. You can view the score, but scoring controls are disabled.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if canTakeOverScoring {
                Button(isMutating ? "Taking over…" : "Take Over Scoring") {
                    showTakeOverConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(isMutating || !isOnline)
                .confirmationDialog(
                    "Take over this match?",
                    isPresented: $showTakeOverConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Take Over Scoring", role: .destructive) {
                        Task { await takeOverScoring() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The current scorer will immediately lose permission to change this match.")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rcktBlue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.rcktBlue.opacity(0.35)))
        .accessibilityIdentifier("scoring.scorerLockBanner")
    }

    private var playerOneActionLabel: String {
        fullName(firstName: match?.player1Name ?? "Player 1", surname: match?.player1Surname)
    }

    private var playerTwoActionLabel: String {
        fullName(firstName: match?.player2Name ?? "Player 2", surname: match?.player2Surname)
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

    private var matchActionSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(showStrokeLetHelp ? "Stroke / Let Help" : (pendingActionSelection == nil ? "Match Actions" : actionDialogTitle))
                            .font(.title2.weight(.bold))
                        Text("\(playerOneActionLabel) vs \(playerTwoActionLabel)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Button {
                        if showStrokeLetHelp {
                            showStrokeLetHelp = false
                        } else {
                            pendingActionSelection = nil
                            showActionMenu = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.bold))
                            .frame(width: 40, height: 40)
                            .background(Color.rcktBlue.opacity(0.12))
                            .foregroundStyle(Color.rcktBlue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showStrokeLetHelp ? "Back to match actions" : "Close match actions")
                }

                if showStrokeLetHelp {
                    strokeLetHelpGuide
                } else if pendingActionSelection == nil {
                    if !isTennisMatch {
                        matchActionButton(title: "Stroke", systemImage: "hand.raised.fill") {
                            pendingActionSelection = .strokeAgainst
                        }
                        .accessibilityIdentifier("scoring.action.stroke")
                        .disabled(isMutating || !canScoreThisMatch || timerPhase != .matchLive || isMatchComplete)

                        matchActionButton(title: "Let", systemImage: "pause.circle.fill") {
                            pendingActionSelection = .letAwarded
                        }
                        .accessibilityIdentifier("scoring.action.let")
                        .disabled(isMutating || !canScoreThisMatch || timerPhase != .matchLive || isMatchComplete)
                    }

                    if strokeLetHelpEnabled && (isPersonalPlus || !isPersonalAccount) {
                        matchActionButton(title: "ST/L Help", systemImage: "questionmark.diamond.fill") {
                            showStrokeLetHelp = true
                        }
                        .accessibilityIdentifier("scoring.action.strokeLetHelp")
                    }

                    matchActionButton(title: "Undo Last Action", systemImage: "arrow.uturn.backward.circle.fill") {
                        showActionMenu = false
                        Task { await undoLastAction() }
                    }
                    .accessibilityIdentifier("scoring.action.undo")
                    .disabled(isMutating || !canScoreThisMatch || undoLocked)

                    matchActionButton(
                        title: "End Match Early",
                        systemImage: "xmark.octagon.fill",
                        foreground: .rcktDanger,
                        border: .rcktDanger
                    ) {
                        showActionMenu = false
                        showEndMatchConfirmation = true
                    }
                    .accessibilityIdentifier("scoring.action.endEarly")
                    .disabled(isMutating || !canScoreThisMatch || isMatchComplete)
                } else {
                    Text("Choose the player")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    matchActionButton(
                        title: playerActionButtonLabel(playerOneActionLabel),
                        systemImage: "person.fill"
                    ) {
                        Task { await handlePendingActionSelection(for: "player1") }
                    }
                    .accessibilityIdentifier("scoring.playerAction.player1")

                    matchActionButton(
                        title: playerActionButtonLabel(playerTwoActionLabel),
                        systemImage: "person.fill"
                    ) {
                        Task { await handlePendingActionSelection(for: "player2") }
                    }
                    .accessibilityIdentifier("scoring.playerAction.player2")

                    Button {
                        pendingActionSelection = nil
                    } label: {
                        Label("Back to Match Actions", systemImage: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.rcktBlue)
                    .accessibilityIdentifier("scoring.playerAction.cancel")
                }

                Spacer(minLength: 0)
            }
            .padding(22)
            .background(Color.rcktCardBackground)
        }
        .presentationDetents(showStrokeLetHelp ? [.large] : [.medium])
        .presentationDragIndicator(.visible)
    }

    private var strokeLetHelpGuide: some View {
        ScrollView {
            VStack(spacing: 0) {
                strokeLetFlowRow(
                    question: "Was there any interference?",
                    detail: "Direct access, full view, freedom to hit and freedom to play?",
                    noResult: "No Let",
                    shape: .hexagon
                )
                strokeLetDownConnector()
                strokeLetFlowRow(
                    question: "Did the player make every effort to get there and could they have made a good return?",
                    detail: nil,
                    noResult: "No Let",
                    shape: .hexagon
                )
                strokeLetDownConnector()
                strokeLetFlowRow(
                    question: "Did the opponent make every effort to clear the ball?",
                    detail: nil,
                    noResult: "Stroke",
                    shape: .rectangle
                )
                strokeLetDownConnector()
                strokeLetFlowRow(
                    question: "Was the player in a position to make the winning return?",
                    detail: nil,
                    noResult: "Yes Let",
                    shape: .capsule
                )
                strokeLetDownConnector()
                strokeLetResult("Stroke", shape: .rectangle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 52)
                    .padding(.bottom, 16)

                Button {
                    showStrokeLetHelp = false
                } label: {
                    Label("Back to Match Actions", systemImage: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.bordered)
                .tint(Color.rcktBlue)
            }
        }
    }

    private enum StrokeLetResultShape { case hexagon, rectangle, capsule }

    private func strokeLetFlowRow(
        question: String,
        detail: String?,
        noResult: String,
        shape: StrokeLetResultShape
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(question)
                    .font(.subheadline.weight(.bold))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 1) {
                Text("NO")
                    .font(.caption2.weight(.bold))
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.secondary)

            strokeLetResult(noResult, shape: shape)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func strokeLetDownConnector() -> some View {
        VStack(spacing: 0) {
            Text("YES")
                .font(.caption2.weight(.bold))
            Image(systemName: "arrow.down")
                .font(.headline.weight(.bold))
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 86)
        .frame(height: 40)
    }

    @ViewBuilder
    private func strokeLetResult(_ title: String, shape: StrokeLetResultShape) -> some View {
        let content = Text(title)
            .font(.caption.weight(.bold))
            .frame(width: 82, height: 52)
            .foregroundStyle(.primary)

        switch shape {
        case .hexagon:
            content.overlay(StrokeLetHexagon().stroke(Color.primary, lineWidth: 2))
        case .rectangle:
            content.overlay(Rectangle().stroke(Color.primary, lineWidth: 2))
        case .capsule:
            content.overlay(Capsule().stroke(Color.primary, lineWidth: 2))
        }
    }

    private func matchActionButton(
        title: String,
        systemImage: String,
        foreground: Color = .primary,
        border: Color = .rcktPink,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(border)
                    .frame(width: 26)
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(foreground)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(border, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func playerActionButtonLabel(_ playerName: String) -> String {
        switch pendingActionSelection {
        case .letAwarded:
            return "Award Let to \(playerName)"
        case .strokeAgainst:
            return "Stroke Against \(playerName)"
        case nil:
            return playerName
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
            ShirtColorOption(id: "pink", value: "pink", label: "Pink", fill: Color.rcktPink, border: Color(red: 217/255, green: 70/255, blue: 143/255))
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
            VStack(spacing: isPhoneLandscapeLayout ? 6 : (compactLayout ? 12 : 16)) {
                scorerHeaderBar

                if isLoading && match == nil {
                    ProgressView("Loading match…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if match?.scoringAccess?.locked == true && !canScoreThisMatch {
                    scorerLockBanner
                }

                if let match {
                    if isTabletLandscape {
                        landscapeScoringLayout(match)
                    } else if isMatchComplete {
                        completedMatchCard(match, compact: compactLayout)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        scoreboardCard(
                            match,
                            compact: compactLayout,
                            showsInlineControls: false,
                            expandsVertically: true
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        Spacer(minLength: 0)
                    }

                    if !isTabletLandscape, let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, isPhoneLandscapeLayout ? 8 : (compactLayout ? 12 : 16))
            .padding(.top, isPhoneLandscapeLayout ? 4 : (compactLayout ? 10 : 14))
            .padding(.bottom, bottomDockReservedHeight)

            if showWarmupOverlay && canScoreThisMatch {
                overlayBackdrop {
                    warmupOverlay
                }
            }

            if showIntervalOverlay && canScoreThisMatch {
                overlayBackdrop {
                    intervalOverlay
                }
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let compactLayout = geometry.size.width < 600 || geometry.size.height < 760
            let isTabletLandscape = UIDevice.current.userInterfaceIdiom == .pad && geometry.size.width > geometry.size.height
            let bottomDockInset = isTabletLandscape ? 2.0 : 6.0
            let bottomDockHeight = bottomDockReservedHeight(
                compactLayout: compactLayout,
                isTabletLandscape: isTabletLandscape,
                bottomInset: bottomDockInset
            )
            scoringCanvas(
                compactLayout: compactLayout,
                isTabletLandscape: isTabletLandscape,
                bottomDockReservedHeight: bottomDockHeight
            )
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let _ = match, !showWarmupOverlay, !showIntervalOverlay {
                dockInsetContent
            }
        }
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
        .onChange(of: intervalObservationSignature) {
            syncIntervalState()
            syncTennisBreakState()
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
        .onChange(of: isOnline) { _, online in
            guard online else { return }
            Task {
                await container.offlineMatchStore.sync(
                    using: container.apiClient,
                    session: container.sessionStore.session
                )
                if let cached = container.offlineMatchStore.cachedMatch(
                    matchID: matchID,
                    session: container.sessionStore.session
                ) {
                    match = cached
                }
            }
        }
        .onReceive(timerTicker) { _ in
            advanceTimerTick()
        }
        .sheet(isPresented: $showGameSettingsSheet) {
            gameSettingsSheet
        }
        .sheet(isPresented: $showActionMenu, onDismiss: {
            pendingActionSelection = nil
        }) {
            matchActionSheet
        }
        .alert("End Match Early?", isPresented: $showEndMatchConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("End Match", role: .destructive) {
                Task { await endMatchEarly() }
            }
        } message: {
            Text("Are you sure you want to end this match? You can cancel and resume scoring.")
        }
    }

    @ViewBuilder
    private var dockInsetContent: some View {
        let screenBounds = UIScreen.main.bounds
        let compactLayout = min(screenBounds.width, screenBounds.height) < 760
        let isTabletLandscape = UIDevice.current.userInterfaceIdiom == .pad && screenBounds.width > screenBounds.height

        bottomScoringDock(
            compactLayout: compactLayout,
            isTabletLandscape: isTabletLandscape
        )
        .disabled(!canScoreThisMatch && !isMatchComplete)
        .padding(.horizontal, compactLayout ? 8 : 14)
        .padding(.top, 2)
        .padding(.bottom, isTabletLandscape ? 2 : 4)
    }

    @ViewBuilder
    private func landscapeScoringLayout(_ match: MatchDetail) -> some View {
        VStack(spacing: 14) {
            if isMatchComplete {
                completedMatchCard(match, compact: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                scoreboardCard(
                    match,
                    compact: false,
                    landscapeTablet: true,
                    expandsVertically: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

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

    private func completedMatchCard(_ match: MatchDetail, compact: Bool) -> some View {
        VStack(spacing: compact ? 14 : 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: compact ? 44 : 54, weight: .semibold))
                .foregroundStyle(Color.rcktActive)

            Text("Match Complete")
                .font(compact ? .title2.weight(.bold) : .title.weight(.bold))

            if let winnerName = live?.winnerName, !winnerName.isEmpty {
                Text("\(winnerName) won")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.rcktBlue)
            }

            HStack(spacing: 12) {
                completedMatchMetric(
                    title: fullName(firstName: match.player1Name, surname: match.player1Surname),
                    value: "\(live?.player1GamesWon ?? 0)"
                )
                completedMatchMetric(
                    title: fullName(firstName: match.player2Name, surname: match.player2Surname),
                    value: "\(live?.player2GamesWon ?? 0)"
                )
            }

            matchHistoryStrip

            if displayedTimerSeconds > 0 {
                Text("Match time \(formatSeconds(displayedTimerSeconds))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if isPersonalPlus {
                let metrics = completedMatchActionMetrics
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        completedServeMetric(
                            playerName: shortDisplayName(firstName: match.player1Name, surname: match.player1Surname),
                            won: metrics.player1ServeWon,
                            lost: metrics.player1ServeLost
                        )
                        completedServeMetric(
                            playerName: shortDisplayName(firstName: match.player2Name, surname: match.player2Surname),
                            won: metrics.player2ServeWon,
                            lost: metrics.player2ServeLost
                        )
                    }
                    Text("Strokes \(metrics.strokes)  •  Lets \(metrics.lets)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                dismiss()
            } label: {
                Text("Return to Matches")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.rcktBlue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("scoring.completed.returnButton")
        }
        .padding(compact ? 18 : 24)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Color.rcktCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.rcktBorder, lineWidth: 1)
        )
    }

    private var completedMatchActionMetrics: (
        player1ServeWon: Int,
        player1ServeLost: Int,
        player2ServeWon: Int,
        player2ServeLost: Int,
        strokes: Int,
        lets: Int
    ) {
        var p1Won = 0
        var p1Lost = 0
        var p2Won = 0
        var p2Lost = 0
        var strokes = 0
        var lets = 0

        for event in live?.events ?? [] {
            if event.eventType == "stroke" { strokes += 1 }
            if event.eventType == "let" { lets += 1 }
            guard ["score_point", "stroke"].contains(event.eventType) else { continue }
            let scorer = event.payload?.scorer ?? event.payload?.playerSide
            let server = event.payload?.pointServerSide ?? event.payload?.currentServerSide
            if server == "player1" {
                if scorer == "player1" { p1Won += 1 } else { p1Lost += 1 }
            } else if server == "player2" {
                if scorer == "player2" { p2Won += 1 } else { p2Lost += 1 }
            }
        }

        return (p1Won, p1Lost, p2Won, p2Lost, strokes, lets)
    }

    private func shortDisplayName(firstName: String, surname: String?) -> String {
        let surnameInitial = surname?.trimmingCharacters(in: .whitespacesAndNewlines).first
        return surnameInitial.map { "\(firstName) \($0)" } ?? firstName
    }

    private func completedServeMetric(playerName: String, won: Int, lost: Int) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(playerName)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)

            HStack(spacing: 6) {
                Text("Serves Won")
                Spacer(minLength: 4)
                Text("\(won)")
                    .fontWeight(.bold)
                    .foregroundStyle(Color.rcktBlue)
            }

            HStack(spacing: 6) {
                Text("Serves Lost")
                Spacer(minLength: 4)
                Text("\(lost)")
                    .fontWeight(.bold)
                    .foregroundStyle(Color.rcktBlue)
            }
        }
        .font(.caption)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func completedMatchMetric(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(value)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.rcktBlue)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func scoreboardCard(
        _ match: MatchDetail,
        compact: Bool,
        showsInlineControls: Bool = false,
        landscapeTablet: Bool = false,
        expandsVertically: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: isPhoneLandscapeLayout ? 4 : (compact ? 10 : 12)) {
            if !isTennisMatch {
                scoreSummaryBanner(match, compact: compact)
            }

            if isScheduledMatch {
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
                    .disabled(isMutating || !canScoreThisMatch)
                    .opacity((isMutating || !canScoreThisMatch) ? 0.72 : 1)
                    .accessibilityIdentifier("scoring.startScheduledMatchButton")

                    Spacer()
                }
                .padding(.horizontal, compact ? 12 : 16)
            }

            if isTennisMatch, let live {
                TennisScoringPresentation(
                    match: match,
                    state: live,
                    compact: compact,
                    landscapeTablet: landscapeTablet,
                    scoringDisabled: isMutating || !canScoreThisMatch || isMatchComplete || isScheduledMatch || timerPhase != .matchLive,
                    onScore: { side in Task { await addPoint(for: side) } },
                    onChooseReceiverCourt: { side in Task { await chooseNoAdReceiverCourt(side) } }
                )
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                    playerHeaderStrip(
                        side: "player1",
                        firstName: match.player1Name,
                        surname: match.player1Surname,
                        isServing: live?.currentServerSide == "player1",
                        serviceSide: live?.serviceSide ?? "Right",
                        shirtColorValue: shirtColorValue(for: "player1", match: match),
                        compact: compact,
                        landscapeTablet: landscapeTablet
                    )

                    playerHeaderStrip(
                        side: "player2",
                        firstName: match.player2Name,
                        surname: match.player2Surname,
                        isServing: live?.currentServerSide == "player2",
                        serviceSide: live?.serviceSide ?? "Right",
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
                        shirtColorValue: shirtColorValue(for: "player1", match: match),
                        compact: compact,
                        landscapeTablet: landscapeTablet
                    )

                    Spacer(minLength: landscapeTablet ? 16 : (compact ? 0 : 8))

                    pointRail(compact: compact, landscapeTablet: landscapeTablet)

                    Spacer(minLength: landscapeTablet ? 16 : (compact ? 0 : 8))

                    playerCard(
                        side: "player2",
                        score: live?.player2Score ?? 0,
                        scoreLabel: displayScoreLabel(for: "player2"),
                        games: live?.player2GamesWon ?? 0,
                        shirtColorValue: shirtColorValue(for: "player2", match: match),
                        compact: compact,
                        landscapeTablet: landscapeTablet
                    )
                    }
                    .padding(.horizontal, landscapeTablet ? 12 : (compact ? 2 : 8))
                    .padding(.top, landscapeTablet ? 16 : (isPhoneLandscapeLayout ? 4 : (compact ? 6 : 12)))
                    .padding(.bottom, landscapeTablet ? 18 : (isPhoneLandscapeLayout ? 4 : (compact ? 12 : 14)))
                }
            }

            if expandsVertically {
                Spacer(minLength: 0)
            }

            matchHistoryStrip
                .padding(.horizontal, compact ? 12 : 16)
        }
        .padding(.top, isPhoneLandscapeLayout ? 4 : (compact ? 8 : 10))
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
            if !isOnline || container.offlineMatchStore.pendingActionCount > 0 {
                HStack(spacing: 7) {
                    Image(systemName: isOnline ? "arrow.triangle.2.circlepath" : "wifi.slash")
                    Text(isOnline
                         ? "Synchronising \(container.offlineMatchStore.pendingActionCount) saved action(s)…"
                         : "Offline — actions will sync automatically.")
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(isOnline ? Color.rcktBlue : Color.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .accessibilityIdentifier("scoring.offlineStatus")
            }

            bottomTimerActionBar(compactLayout: compactLayout, isTabletLandscape: isTabletLandscape)

            if let timerSkipLabel {
                Button(timerSkipLabel) {
                    handleSkipTimedPhase()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.rcktBlue)
                .disabled(isMatchComplete)
                .accessibilityIdentifier("scoring.timerSkipButton")
            }
        }
        .padding(.horizontal, compactLayout ? 6 : 8)
        .padding(.top, compactLayout ? 4 : 6)
        .padding(.bottom, compactLayout ? 4 : 6)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.12)
                        : Color.white.opacity(0.72),
                    lineWidth: 1
                )
        )
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.18) : Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
    }

    private func bottomTimerControl(compactLayout: Bool, isTabletLandscape: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                handleToggleTimer()
            } label: {
                HStack(spacing: 8) {
                    if timerPhase == .matchLive && !timerRunning {
                        Image(systemName: "pause.fill")
                    }
                    Text(timerPhase == .warmupReady ? "Start Warm-Up" : formatSeconds(displayedTimerSeconds))
                }
                    .font(.system(size: isTabletLandscape ? 26 : (compactLayout ? 20 : 22), weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isTabletLandscape ? 13 : (compactLayout ? 11 : 12))
                    .background(timerChipBackgroundColor)
                    .foregroundStyle(timerChipForegroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isMatchComplete || isScheduledMatch || timerPhase == .firstServer)
            .opacity((isMatchComplete || isScheduledMatch || timerPhase == .firstServer) ? 0.8 : 1)
            .accessibilityIdentifier("scoring.timerButton")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compactLayout ? 4 : 6)
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
            .padding(.vertical, isTabletLandscape ? 15 : (compactLayout ? 13 : 14))
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.42))
            )
            .foregroundStyle(colorScheme == .dark ? .white : Color.rcktSlate)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.78), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(width: isTabletLandscape ? 170 : (compactLayout ? 116 : 132))
        .disabled(isScheduledMatch)
        .opacity(isScheduledMatch ? 0.72 : 1)
        .accessibilityIdentifier("scoring.actionButton")
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
            VStack(alignment: .leading, spacing: isPhoneLandscapeLayout ? 10 : 18) {
                Text(
                    isTennisMatch
                        ? (isTennisDoublesMatch ? "Serve & Receive" : "Opening Server")
                        : "First Server"
                )
                    .font(isPhoneLandscapeLayout ? .headline.weight(.bold) : .title2.weight(.bold))

                Text(
                    isTennisMatch
                        ? (isTennisDoublesMatch
                            ? "Choose the opening server and the opening receiver. The match begins after this selection."
                            : "Choose the opening server. The other player will receive automatically.")
                        : "Choose which player starts serving. The match begins after this selection."
                )
                    .font(isPhoneLandscapeLayout ? .caption : .body)
                    .foregroundStyle(.secondary)

                if isTennisMatch {
                    tennisOpeningSelectionOverlay(match)
                } else {
                    if isPhoneLandscapeLayout {
                        HStack(spacing: 12) {
                            firstServerButton(
                                fullName(firstName: match.player1Name, surname: match.player1Surname),
                                side: "player1",
                                color: .rcktBlue,
                                match: match
                            )
                            firstServerButton(
                                fullName(firstName: match.player2Name, surname: match.player2Surname),
                                side: "player2",
                                color: .rcktSlate,
                                match: match
                            )
                        }

                    } else {
                        VStack(spacing: 12) {
                            firstServerButton(
                                fullName(firstName: match.player1Name, surname: match.player1Surname),
                                side: "player1",
                                color: .rcktBlue,
                                match: match
                            )
                            firstServerButton(
                                fullName(firstName: match.player2Name, surname: match.player2Surname),
                                side: "player2",
                                color: .rcktSlate,
                                match: match
                            )
                        }
                    }
                }
            }
            .padding(isPhoneLandscapeLayout ? 16 : 24)
            .frame(maxWidth: isPhoneLandscapeLayout ? 520 : 420, alignment: .leading)
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
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            startWarmupOverlayButton
                            skipWarmupOverlayButton
                        }

                        VStack(spacing: 12) {
                            startWarmupOverlayButton
                            skipWarmupOverlayButton
                        }
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
                            .foregroundStyle(timerChipForegroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("scoring.warmup.timerButton")

                    Button("Skip Warm-Up") {
                        handleSkipTimedPhase()
                    }
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.rcktSlate)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityIdentifier("scoring.warmup.skipTimedButton")
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

    private func firstServerButton(
        _ title: String,
        side: String,
        color: Color,
        match: MatchDetail
    ) -> some View {
        Button {
            Task { await chooseFirstServer(side, using: match) }
        } label: {
            Text(title)
                .font((isPhoneLandscapeLayout ? Font.subheadline : Font.headline).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.vertical, isPhoneLandscapeLayout ? 11 : 16)
                .background(color)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isMutating)
        .accessibilityIdentifier("scoring.firstServer.\(side)")
    }

    private var startWarmupOverlayButton: some View {
        Button {
            handleStartWarmup()
        } label: {
            Text("Start Warm-Up")
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.rcktBlue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("scoring.warmup.startButton")
    }

    private var skipWarmupOverlayButton: some View {
        Button {
            handleSkipWarmup()
        } label: {
            Text("Skip Warm-Up")
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.rcktSlate)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("scoring.warmup.skipButton")
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
                    isSelected: selectedOpeningServerParticipantID == participant.id,
                    identifier: "scoring.tennisOpening.server.\(participant.id)"
                ) {
                    selectedOpeningServerParticipantID = participant.id
                    let updatedReceivers = openingReceiverCandidates(for: participant.id, match: match)
                    if isTennisDoublesMatch {
                        if let selectedReceiver = selectedOpeningReceiverParticipantID,
                           !updatedReceivers.map(\.id).contains(selectedReceiver) {
                            selectedOpeningReceiverParticipantID = nil
                        }
                    } else {
                        selectedOpeningReceiverParticipantID = updatedReceivers.first?.id
                    }
                }
            }

            if isTennisDoublesMatch {
                Text("Opening Receiver")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.top, 4)

                ForEach(receivingParticipants, id: \.id) { participant in
                    selectionOverlayButton(
                        title: participant.displayName,
                        isSelected: selectedOpeningReceiverParticipantID == participant.id,
                        identifier: "scoring.tennisOpening.receiver.\(participant.id)"
                    ) {
                        selectedOpeningReceiverParticipantID = participant.id
                    }
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
            .accessibilityIdentifier("scoring.tennisOpening.beginMatchButton")
        }
    }

    private func selectionOverlayButton(
        title: String,
        isSelected: Bool,
        identifier: String? = nil,
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
        .accessibilityIdentifier(identifier ?? title)
    }

    private var intervalOverlay: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(intervalOverlayTitle)
                .font(.title2.weight(.bold))

            Text(intervalOverlayMessage)
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
                    .foregroundStyle(timerChipForegroundColor)
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
            .accessibilityIdentifier("scoring.interval.skipButton")
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
        let laneWidth: CGFloat = {
            if landscapeTablet {
                return 122
            }
            if isTabletPortrait {
                return 96
            }
            return isPhoneLandscapeLayout ? 58 : (compact ? 64 : 92)
        }()
        let railHeight: CGFloat = {
            if landscapeTablet {
                return 360
            }
            if isTabletPortrait {
                return 520
            }
            return isPhoneLandscapeLayout ? 122 : (compact ? 360 : 420)
        }()

        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: landscapeTablet ? 14 : (isPhoneLandscapeLayout ? 5 : (compact ? 10 : 12))) {
                    ForEach(pointRailEntries) { entry in
                        HStack(spacing: landscapeTablet ? 16 : 10) {
                            pointRailLane(
                                entry: entry,
                                targetSide: "player1",
                                laneWidth: laneWidth,
                                compact: compact,
                                landscapeTablet: landscapeTablet
                            )

                            Rectangle()
                                .fill(Color.rcktBorder.opacity(0.9))
                                .frame(width: 1)
                                .padding(.vertical, 4)

                            pointRailLane(
                                entry: entry,
                                targetSide: "player2",
                                laneWidth: laneWidth,
                                compact: compact,
                                landscapeTablet: landscapeTablet
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .id(entry.id)
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier("scoring.pointRail.\(entry.displaySide).\(entry.displayScore)")
                        .accessibilityLabel(
                            entry.actionLabel
                                ?? "\(entry.displaySideLabel)\(entry.displayScore)"
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .frame(
                width: (laneWidth * 2) + (landscapeTablet ? 17 : 11),
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
    private func pointRailLane(
        entry: RacketPointRailEntry,
        targetSide: String,
        laneWidth: CGFloat,
        compact: Bool,
        landscapeTablet: Bool
    ) -> some View {
        Group {
            if entry.displaySide == targetSide {
                if let actionLabel = entry.actionLabel {
                    Text(actionLabel)
                        .font(.system(
                            size: landscapeTablet ? 16 : (compact ? 11 : 13),
                            weight: .heavy,
                            design: .rounded
                        ))
                        .foregroundStyle(Color.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(
                            width: max(56, laneWidth - 4),
                            height: landscapeTablet ? 44 : (compact ? 30 : 34)
                        )
                        .background(Color(red: 1.0, green: 0.82, blue: 0.0))
                        .clipShape(RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous)
                                .stroke(Color(red: 0.86, green: 0.64, blue: 0.0), lineWidth: 1.5)
                        )
                        .frame(width: laneWidth, alignment: targetSide == "player1" ? .trailing : .leading)
                } else {
                    HStack(spacing: landscapeTablet ? 10 : (compact ? 4 : 8)) {
                        scoreSheetMarker(
                            label: entry.displaySideLabel,
                            isCurrentServe: entry.isCurrentServe,
                            accent: timelineAccent(for: targetSide),
                            compact: compact,
                            landscapeTablet: landscapeTablet
                        )
                        scoreSheetMarker(
                            label: entry.displayScore,
                            isCurrentServe: entry.isCurrentServe,
                            accent: timelineAccent(for: targetSide),
                            compact: compact,
                            landscapeTablet: landscapeTablet
                        )
                    }
                    .frame(width: laneWidth, alignment: targetSide == "player1" ? .trailing : .leading)
                }
            } else {
                Color.clear
                    .frame(width: laneWidth, height: landscapeTablet ? 44 : (compact ? 30 : 34))
            }
        }
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
        .padding(.vertical, isPhoneLandscapeLayout ? 6 : (compact ? 10 : 12))
        .background(Color.rcktBlue.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, compact ? 4 : 6)
    }

    private func scoreSummaryText(for match: MatchDetail) -> String {
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
            HStack(spacing: 6) {
                ForEach(gameHistory) { game in
                    VStack(spacing: 3) {
                        Text("\(game.player1Score)-\(game.player2Score)")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(initials(for: game.winnerName))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
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
                if !isTennisMatch {
                    detailItem("Game Format", value: "PAR-\(live?.scoreType ?? match.scoreType)")
                }
                detailItem("Court Alias", value: match.courtAlias ?? "Not set")
            }

            if isTennisMatch {
                HStack(spacing: 12) {
                    detailItem("No-Ad", value: live?.tennisNoAdScoring == true ? "Enabled" : "Off")
                    detailItem("Final-set Match Tiebreak", value: live?.tennisFinalSetMatchTiebreak == true ? "Enabled" : "Off")
                }
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

            if isPersonalAccount {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Remote Match Viewing")
                        .font(.headline)
                    if canUseRemoteMatchViewing {
                        Text("Share this match-specific code so another user can follow the score remotely.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        detailItem("Match Viewing Code", value: viewerCode.isEmpty ? "Not available" : viewerCode)
                    } else {
                        Text("Remote match viewing is available with Personal Plus.")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.rcktBlue)
                        Text("Upgrade from Settings → Subscription to create a private viewing code.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showEventTimeline.toggle()
                    }
                } label: {
                    HStack {
                        Text("Event Timeline")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: showEventTimeline ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.rcktBlue)
                    }
                }
                .buttonStyle(.plain)

                if showEventTimeline && (live?.events.isEmpty ?? true) {
                    Text("No events yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if showEventTimeline {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(Array((live?.events ?? []).reversed())) { event in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(liveTimelineTitle(event, match: match))
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
        side: String,
        firstName: String,
        surname: String?,
        isServing: Bool,
        serviceSide: String,
        shirtColorValue: String,
        compact: Bool,
        landscapeTablet: Bool
    ) -> some View {
        let foreground = shirtForegroundColor(for: shirtColorValue)
        VStack(spacing: isPhoneLandscapeLayout ? 3 : (compact ? 8 : 10)) {
            Text(scoringDisplayName(side: side, firstName: firstName, surname: surname))
                .font(.system(size: landscapeTablet ? 24 : (isPhoneLandscapeLayout ? 16 : (compact ? 19 : 21)), weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            HStack {
                Spacer(minLength: 0)
                if isServing {
                    Button {
                        Task { await toggleServeSide(current: serviceSide) }
                    } label: {
                        Text(serviceSide)
                            .font(.subheadline.weight(.semibold))
                            .frame(minWidth: compact ? 62 : 68)
                            .padding(.horizontal, compact ? 10 : 12)
                            .padding(.vertical, isPhoneLandscapeLayout ? 4 : (compact ? 7 : 8))
                            .background(.white)
                            .foregroundStyle(.black)
                            .overlay(
                                Capsule()
                                    .stroke(Color.rcktCompleted, lineWidth: 2)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isMutating || !canScoreThisMatch || isMatchComplete || !canToggleCurrentServeSide)
                    .opacity(canToggleCurrentServeSide ? 1 : 0.72)
                    .accessibilityIdentifier("scoring.serveSide.\(side)")
                } else {
                    Capsule()
                        .fill(Color.clear)
                        .frame(width: compact ? 62 : 68, height: compact ? 34 : 36)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, compact ? 14 : 16)
        .padding(.vertical, landscapeTablet ? 18 : (isPhoneLandscapeLayout ? 5 : (compact ? 12 : 14)))
        .frame(maxWidth: .infinity, minHeight: landscapeTablet ? 122 : (isPhoneLandscapeLayout ? 62 : (compact ? 92 : 102)), alignment: .center)
        .background(shirtFillColor(for: shirtColorValue))
        .foregroundStyle(foreground)
    }

    @ViewBuilder
    private func playerCard(
        side: String,
        score: Int,
        scoreLabel: String,
        games: Int,
        shirtColorValue: String,
        compact: Bool,
        landscapeTablet: Bool
    ) -> some View {
        let foreground = shirtForegroundColor(for: shirtColorValue)
        let usesDarkForeground = isLightShirtColor(shirtColorValue)
        let displayedScore = scoreLabel.isEmpty ? String(score) : scoreLabel
        let scoreFontSize: CGFloat = landscapeTablet ? 112 : (isPhoneLandscapeLayout ? 62 : (compact ? 88 : 96))

        VStack(spacing: compact ? 8 : 10) {
            playerScoreDisplay(
                displayedScore,
                fontSize: scoreFontSize,
                usesDarkForeground: usesDarkForeground,
                compact: compact,
                landscapeTablet: landscapeTablet
            )

            Text("Games: \(games)")
                .font(landscapeTablet ? .subheadline.weight(.semibold) : (compact ? .footnote.weight(.semibold) : .subheadline.weight(.semibold)))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, landscapeTablet ? 14 : (compact ? 6 : 12))
        .padding(.vertical, landscapeTablet ? 18 : (isPhoneLandscapeLayout ? 6 : (compact ? 12 : 14)))
        .frame(width: landscapeTablet ? 182 : (isPhoneLandscapeLayout ? 112 : (compact ? 94 : 128)))
        .frame(minHeight: landscapeTablet ? 232 : (isPhoneLandscapeLayout ? 112 : (compact ? 158 : 170)), alignment: .top)
        .background(shirtFillColor(for: shirtColorValue))
        .foregroundStyle(foreground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(usesDarkForeground ? Color.black.opacity(0.18) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            Task { await addPoint(for: side) }
        }
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("scoring.scoreCard.\(side)")
        .accessibilityLabel(side == "player1" ? "Player 1 score" : "Player 2 score")
        .accessibilityValue(scoreLabel.isEmpty ? "\(score)" : scoreLabel)
    }

    private func playerScoreDisplay(
        _ score: String,
        fontSize: CGFloat,
        usesDarkForeground: Bool,
        compact: Bool,
        landscapeTablet: Bool
    ) -> some View {
        let cornerRadius: CGFloat = landscapeTablet ? 22 : 18
        let verticalPadding: CGFloat = landscapeTablet ? 18 : (isPhoneLandscapeLayout ? 5 : (compact ? 10 : 12))
        let insetFill = usesDarkForeground ? Color.black.opacity(0.06) : Color.white.opacity(0.18)
        let insetStroke = usesDarkForeground ? Color.black.opacity(0.20) : Color.white.opacity(0.24)

        return Text(score)
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.58)
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .background(insetFill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(insetStroke, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
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
        isLightShirtColor(value) ? .black : .white
    }

    private func isLightShirtColor(_ value: String) -> Bool {
        ["white", "yellow", "pink"].contains(value.lowercased())
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
            .font(.system(size: landscapeTablet ? 16 : (compact ? 11 : 14), weight: .bold, design: .rounded))
            .frame(
                width: landscapeTablet ? 48 : (compact ? 28 : 38),
                height: landscapeTablet ? 44 : (compact ? 30 : 34)
            )
            .background(
                RoundedRectangle(cornerRadius: landscapeTablet ? 14 : 12, style: .continuous)
                    .fill(isCurrentServe ? accent.opacity(0.14) : Color.rcktCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: landscapeTablet ? 14 : 12, style: .continuous)
                    .stroke(accent, lineWidth: isCurrentServe ? 3 : 2)
            )
            .foregroundStyle(accent)
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
            contentHeight = timerSkipLabel == nil ? 72 : 98
        } else if compactLayout {
            contentHeight = timerSkipLabel == nil ? 74 : 102
        } else {
            contentHeight = timerSkipLabel == nil ? 80 : 108
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
            if !isTennisMatch {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Game Format")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("Game Format", selection: $gameSettingsForm.scoreType) {
                        ForEach(availableScoreTypeOptions, id: \.self) { option in
                            Text("PAR-\(option)").tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            if canChoosePlayerShirtColors {
                shirtColorEditor(
                    title: playerShirtLabel(for: "player1"),
                    selection: $gameSettingsForm.player1ShirtColor
                )
                shirtColorEditor(
                    title: playerShirtLabel(for: "player2"),
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
        HStack(spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            ScoringShirtColorGridPicker(selection: selection, options: shirtColorOptions)
                .accessibilityLabel("\(title) colour")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func playerShirtLabel(for side: String) -> String {
        guard let match else {
            return side == "player2" ? "Player 2 Shirt" : "Player 1 Shirt"
        }

        let name = side == "player2"
            ? fullName(firstName: match.player2Name, surname: match.player2Surname)
            : fullName(firstName: match.player1Name, surname: match.player1Surname)
        return "\(name) Shirt"
    }

    private func shirtColorMenuIcon(for option: ShirtColorOption) -> Image {
        let size = CGSize(width: 18, height: 18)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let circleRect = CGRect(x: 1, y: 1, width: 16, height: 16)
            UIColor(option.fill).setFill()
            context.cgContext.fillEllipse(in: circleRect)
            UIColor(option.border).setStroke()
            context.cgContext.setLineWidth(1)
            context.cgContext.strokeEllipse(in: circleRect)
        }

        return Image(uiImage: image).renderingMode(.original)
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
                ? "Start a single 5 minute warm-up, then confirm the opening server."
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
            return timerRunning ? Color.rcktTimerRunning : Color.rcktDanger
        }

        return timerRunning ? Color.rcktBlue : Color.rcktSlate
    }

    private var timerChipForegroundColor: Color {
        timerPhase == .matchLive && timerRunning ? Color.rcktNavy : .white
    }

    private func loadMatch() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        if !isOnline {
            let cached = container.offlineMatchStore.cachedMatch(
                matchID: matchID,
                session: container.sessionStore.session
            )
            await MainActor.run {
                match = cached
                errorMessage = cached == nil ? "This match has not been saved on this device and cannot be opened offline." : nil
                isLoading = false
            }
            return
        }

        await container.offlineMatchStore.sync(
            using: container.apiClient,
            session: container.sessionStore.session
        )

        do {
            let fetched = try await container.apiClient.getMatch(matchID: matchID)
            await MainActor.run {
                match = fetched
                if let session = container.sessionStore.session {
                    container.offlineMatchStore.cache(fetched, session: session)
                }
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
        guard isOnline else {
            await MainActor.run {
                displayAccess = nil
            }
            return
        }

        // Personal Free matches must not request or expose a remote-viewing
        // code. Club matches still load display access for their scoreboard.
        if isPersonalAccount && !isPersonalPlus {
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
        await performQueuedMutation {
            container.offlineMatchStore.enqueue(
                kind: .matchSettings,
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
        guard canScoreThisMatch else {
            errorMessage = "Another club scorer currently controls this match."
            return
        }
        guard match?.status.lowercased() == "scheduled" else {
            return
        }

        guard isOnline else {
            errorMessage = "Connect to the internet to start a scheduled match."
            return
        }

        await performMutation {
            try await container.apiClient.startScheduledMatch(matchID: matchID)
        }

        guard let updatedMatch = match,
              updatedMatch.status.lowercased() != "scheduled" else {
            return
        }

        bootstrappedMatchID = nil
        bootstrapTimerIfNeeded(for: updatedMatch)
    }

    private func takeOverScoring() async {
        guard canTakeOverScoring, isOnline, !isMutating else { return }
        await performMutation {
            try await container.apiClient.takeOverMatchScoring(matchID: matchID)
        }
    }

    private func bootstrapTimerIfNeeded(for match: MatchDetail) {
        guard bootstrappedMatchID != match.id else {
            return
        }

        bootstrappedMatchID = match.id
        previousGameHistoryCount = live?.gameHistory.count ?? 0
        previousTennisGameCompletionSignature = latestTennisGameCompletionSignature
        durationSyncedMatchID = nil

        if match.status.lowercased() == "scheduled" {
            clearStoredTimerState(matchID: match.id)
            timerPhase = .matchLive
            timerSeconds = 0
            matchDurationSeconds = 0
            timerRunning = false
            return
        }

        if let storedState = readStoredTimerState(matchID: match.id) {
            let optionalTimerPhase = [
                MatchTimerPhase.warmupReady,
                .warmupSideOne,
                .warmupSideTwo,
                .interval
            ].contains(storedState.phase)
            if live?.tennisTimedBreaks == true || !optionalTimerPhase {
                let advancedState = advanceTimerSnapshot(storedState)
                timerPhase = advancedState.phase
                timerSeconds = advancedState.seconds
                matchDurationSeconds = advancedState.matchDurationSeconds
                activeIntervalDurationSeconds = advancedState.intervalDurationSeconds ?? intervalSeconds
                timerRunning = advancedState.running
                return
            }
            clearStoredTimerState(matchID: match.id)
        }

        if isMatchComplete {
            let duration = max(recordedMatchDurationSeconds, 0)
            timerPhase = .matchLive
            timerSeconds = duration
            matchDurationSeconds = duration
            timerRunning = false
            return
        }

        if isFreshMatch(match), live?.tennisTimedBreaks == true {
            timerPhase = .warmupReady
            timerSeconds = warmupDurationSeconds
            matchDurationSeconds = 0
            timerRunning = false
            return
        }

        if isFreshMatch(match) {
            timerPhase = .firstServer
            timerSeconds = 0
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

            if !isTennisMatch && !isMatchComplete && live?.tennisTimedBreaks == true {
                timerPhase = .interval
                timerSeconds = intervalSeconds
                activeIntervalDurationSeconds = intervalSeconds
                timerRunning = true
            }
            return
        }

        previousGameHistoryCount = currentCount
    }

    private func syncTennisBreakState() {
        guard let match, bootstrappedMatchID == match.id, isTennisMatch else {
            return
        }

        let signature = latestTennisGameCompletionSignature
        guard signature != previousTennisGameCompletionSignature else {
            return
        }
        previousTennisGameCompletionSignature = signature

        guard !isMatchComplete,
              let payload = latestTennisGameCompletionEvent?.payload,
              let completedGameNumber = payload.completedGameNumber else {
            return
        }

        guard let duration = TennisBreakRules.durationSeconds(
            enabled: live?.tennisTimedBreaks == true,
            completedGameNumber: completedGameNumber,
            setCompleted: payload.setCompleted == true
        ) else {
            return
        }

        timerPhase = .interval
        timerSeconds = duration
        activeIntervalDurationSeconds = duration
        timerRunning = true
    }

    private func syncCompletedMatchTimer() {
        guard let match else {
            return
        }

        if !isMatchComplete {
            let wasDurationSynced = durationSyncedMatchID == match.id
            durationSyncedMatchID = nil
            if wasDurationSynced {
                timerPhase = .matchLive
                timerSeconds = matchDurationSeconds
                timerRunning = true
            }
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

        if match.status.lowercased() == "scheduled" {
            clearStoredTimerState(matchID: match.id)
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
            intervalDurationSeconds: timerPhase == .interval ? activeIntervalDurationSeconds : nil,
            updatedAt: Date().timeIntervalSince1970
        )
        writeStoredTimerState(snapshot, matchID: match.id)
    }

    private func advanceTimerTick() {
        guard timerRunning, match?.status.lowercased() != "scheduled" else {
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

        await performQueuedMutation {
            container.offlineMatchStore.enqueue(
                kind: .server,
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

        await performQueuedMutation {
            container.offlineMatchStore.enqueue(
                kind: .server,
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
        guard canScoreThisMatch, !isMutating, !isMatchComplete, !isScheduledMatch, timerPhase == .matchLive else { return }
        guard !(isPadelMatch
            && live?.tennisNoAdScoring == true
            && live?.isTieBreak == false
            && live?.player1Score == 3
            && live?.player2Score == 3
            && live?.noAdDecidingSide == nil) else { return }
        resumeMatchTimerForDecision()
        await performQueuedMutation {
            container.offlineMatchStore.enqueue(kind: .scorePoint, matchID: matchID, scorer: side)
        }
    }

    private func chooseNoAdReceiverCourt(_ side: String) async {
        guard canScoreThisMatch, !isMutating, !isMatchComplete, !isScheduledMatch, timerPhase == .matchLive else { return }
        await performQueuedMutation {
            container.offlineMatchStore.enqueue(
                kind: .receiverChoice,
                matchID: matchID,
                side: side
            )
        }
    }

    private func awardStroke(to side: String) async {
        guard canScoreThisMatch, !isMutating, !isMatchComplete, !isScheduledMatch, timerPhase == .matchLive else { return }
        resumeMatchTimerForDecision()
        await performQueuedMutation {
            container.offlineMatchStore.enqueue(kind: .stroke, matchID: matchID, playerSide: side)
        }
    }

    private func callLet(awardedTo side: String? = nil) async {
        guard canScoreThisMatch, !isMutating, !isMatchComplete, !isScheduledMatch, timerPhase == .matchLive else { return }
        resumeMatchTimerForDecision()
        await performQueuedMutation {
            container.offlineMatchStore.enqueue(
                kind: .letCall,
                matchID: matchID,
                playerSide: side,
                note: side.map { "Let awarded to \($0)" } ?? "General let"
            )
        }
    }

    private func resumeMatchTimerForDecision() {
        guard timerPhase == .matchLive, !timerRunning, !isMatchComplete else { return }
        timerRunning = true
        persistTimerState()
    }

    private func handlePendingActionSelection(for side: String) async {
        let action = pendingActionSelection
        pendingActionSelection = nil
        showActionMenu = false

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
        guard canScoreThisMatch, !isMutating, !isMatchComplete, !isScheduledMatch, timerPhase == .matchLive else { return }
        let nextSide = current.lowercased() == "left" ? "Right" : "Left"
        await performQueuedMutation {
            container.offlineMatchStore.enqueue(kind: .serveSide, matchID: matchID, side: nextSide)
        }
    }

    private func undoLastAction() async {
        guard canScoreThisMatch, !isMutating, !undoLocked else { return }
        if container.offlineMatchStore.undoLastQueuedAction(matchID: matchID) {
            errorMessage = nil
            return
        }

        guard isOnline else {
            errorMessage = "Only actions scored on this device while offline can be undone until you reconnect."
            return
        }

        await performQueuedMutation {
            container.offlineMatchStore.enqueue(kind: .undo, matchID: matchID)
        }
    }

    private func endMatchEarly() async {
        guard canScoreThisMatch, !isMutating, !isMatchComplete, !isScheduledMatch else { return }

        let finalDuration = max(0, resolveMatchDurationSeconds())
        timerRunning = false
        timerSeconds = finalDuration
        matchDurationSeconds = finalDuration

        await performQueuedMutation {
            container.offlineMatchStore.enqueue(
                kind: .endMatch,
                matchID: matchID,
                note: "Ended by operator",
                matchDurationSeconds: finalDuration
            )
        }
    }

    private func recordMatchDuration(_ durationSeconds: Int) async {
        await performQueuedMutation {
            container.offlineMatchStore.enqueue(
                kind: .timer,
                matchID: matchID,
                matchDurationSeconds: durationSeconds
            )
        }
    }

    private func handleMatchIdentityTask() async {
        warmScoringAPIsIfNeeded()
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

    private func performQueuedMutation(_ enqueue: () -> Bool) async {
        isMutating = true
        errorMessage = nil

        guard enqueue() else {
            errorMessage = "This match is not available for offline scoring on this device."
            isMutating = false
            return
        }

        // The offline store has already projected the optimistic state and
        // persists every action in order. Do not keep score controls locked
        // while a cold Lambda or database connection catches up.
        synchroniseQueuedMutationsInBackground()

        try? await Task.sleep(for: .milliseconds(scoringTapDebounceMilliseconds))
        isMutating = false
    }

    private func synchroniseQueuedMutationsInBackground() {
        guard isOnline else {
            return
        }

        Task {
            await container.offlineMatchStore.sync(
                using: container.apiClient,
                session: container.sessionStore.session
            )

            if let cached = container.offlineMatchStore.cachedMatch(
                matchID: matchID,
                session: container.sessionStore.session
            ) {
                match = cached
            }

            // Reconcile interval state directly after the server response
            // settles. The onChange observer remains useful for
            // external/offline updates, but a fast online sync can coalesce
            // those renders and otherwise miss the completed-game transition.
            syncIntervalState()
            syncTennisBreakState()

            if container.offlineMatchStore.pendingActionCount > 0 {
                errorMessage = container.offlineMatchStore.lastSyncErrorMessage
                    ?? container.offlineMatchStore.syncMessage
                    ?? "Scoring changes are still waiting to synchronise."
            }
        }
    }

    private func warmScoringAPIsIfNeeded() {
        guard let match,
              isOnline,
              canScoreThisMatch,
              match.status.lowercased() != "completed" else {
            return
        }

        Task {
            await container.apiClient.warmScoringAPIs(matchID: matchID)
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
                if let session = container.sessionStore.session {
                    container.offlineMatchStore.cache(updatedMatch, session: session)
                }
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
        let player1Start = match.handicapEnabled ? match.player1Offset : 0
        let player2Start = match.handicapEnabled ? match.player2Offset : 0

        return (state?.currentGameNumber ?? 1) == 1
            && (state?.player1Score ?? player1Start) == player1Start
            && (state?.player2Score ?? player2Start) == player2Start
            && (state?.gameHistory ?? []).isEmpty
            && events.count <= 1
    }

    private func fullName(firstName: String, surname: String?) -> String {
        guard let surname, !surname.isEmpty else {
            return firstName
        }

        return "\(firstName) \(surname)"
    }

    private func liveTimelineTitle(_ event: MatchEvent, match: MatchDetail) -> String {
        let side = event.payload?.playerSide ?? event.payload?.scorer
        let playerName = side == "player2"
            ? scoringDisplayName(side: "player2", firstName: match.player2Name, surname: match.player2Surname)
            : scoringDisplayName(side: "player1", firstName: match.player1Name, surname: match.player1Surname)
        switch event.eventType {
        case "stroke": return "S to \(playerName)"
        case "let": return "L to \(playerName)"
        default: return event.summary ?? event.eventType.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func scoringDisplayName(side: String, firstName: String, surname: String?) -> String {
        guard let match,
              match.player1Name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(
                match.player2Name.trimmingCharacters(in: .whitespacesAndNewlines)
              ) == .orderedSame,
              let initial = surname?.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return firstName
        }
        return "\(firstName) \(String(initial).uppercased())."
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
            intervalDurationSeconds: snapshot.intervalDurationSeconds,
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
    static let rcktTimerRunning = Color(red: 178 / 255, green: 235 / 255, blue: 193 / 255)
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
