import SwiftUI

enum MatchSport: String, CaseIterable, Hashable, Identifiable {
    case squash
    case racketball
    case tennis
    case padel
    case tableTennis = "table_tennis"
    case pickleball
    case badminton

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .squash:
            return "Squash"
        case .racketball:
            return "Racketball"
        case .tennis:
            return "Tennis"
        case .padel:
            return "Padel"
        case .tableTennis:
            return "Table Tennis"
        case .pickleball:
            return "Pickleball"
        case .badminton:
            return "Badminton"
        }
    }

    var summary: String {
        switch self {
        case .squash:
            return "Use the standard squash match setup flow."
        case .racketball:
            return "Use the shared squash and racketball setup flow."
        case .tennis:
            return "Use the shared racket-sport setup flow for tennis."
        case .padel:
            return "Use the shared racket-sport setup flow for padel."
        case .tableTennis:
            return "Use the shared racket-sport setup flow for table tennis."
        case .pickleball:
            return "Use the shared racket-sport setup flow for pickleball."
        case .badminton:
            return "Use the shared racket-sport setup flow for badminton."
        }
    }

    var navigationTitle: String {
        "Start \(displayName) Match"
    }

    var isImplementedToday: Bool {
        switch self {
        case .squash, .racketball, .tennis:
            return true
        case .padel, .tableTennis, .pickleball, .badminton:
            return false
        }
    }
}

private enum MatchSetupFocusField: Hashable {
    case player1Name
    case player1Surname
    case player1Country
    case player2Name
    case player2Surname
    case player2Country
    case player3Name
    case player3Surname
    case player4Name
    case player4Surname
    case referee
}

private enum MatchLookupTarget: Equatable {
    case player1
    case player2
    case player3
    case player4
    case referee
}

enum StartNewMatchResult {
    case openMatch(String)
    case scheduled(String?)
}

private struct ShirtColorOption: Identifiable {
    let id: String
    let label: String
    let swatch: Color
    let border: Color
    let foreground: Color
}

private struct MatchSetupFormState {
    var courtID = ""
    var courtName = ""
    var courtAlias = ""
    var isDoubles = false
    var player1Name = ""
    var player1Surname = ""
    var player1Country = ""
    var player1IsLeftHanded = false
    var player1ShirtColor = "navy"
    var player2Name = ""
    var player2Surname = ""
    var player2Country = ""
    var player2IsLeftHanded = false
    var player2ShirtColor = "white"
    var player3Name = ""
    var player3Surname = ""
    var player4Name = ""
    var player4Surname = ""
    var refereeName = ""
    var scoreType = 15
    var bestOf = 5
    var scheduleMatch = false
    var handicapEnabled = false
    var player1Band = ""
    var player2Band = ""
    var player1Offset = 0
    var player2Offset = 0

    var player1LookupQuery: String {
        [player1Name, player1Surname]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var player2LookupQuery: String {
        [player2Name, player2Surname]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var player3LookupQuery: String {
        [player3Name, player3Surname]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var player4LookupQuery: String {
        [player4Name, player4Surname]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct StartNewMatchFlowView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    let activeMatches: [MatchSummary]
    let onComplete: (StartNewMatchResult) -> Void

    private let sportGridColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var enabledSportIDs: Set<String> {
        Set(container.sessionStore.session?.normalizedEnabledSports ?? ["squash", "racketball", "tennis"])
    }

    private var availableSports: [MatchSport] {
        MatchSport.allCases.filter { $0.isImplementedToday && enabledSportIDs.contains($0.rawValue) }
    }

    var body: some View {
        ScrollView {
            VStack {
                LazyVGrid(columns: sportGridColumns, spacing: 14) {
                    ForEach(availableSports) { sport in
                        NavigationLink(value: sport) {
                            VStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.dashboardAccentPink.opacity(0.95))
                                        .frame(width: 54, height: 54)

                                    sportGlyph(for: sport, isAvailable: true)
                                }

                                Text(sport.displayName)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.85)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 148)
                            .padding(.horizontal, 10)
                            .background(
                                LinearGradient(
                                    colors: [Color.dashboardBrand, Color.dashboardBrandDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.dashboardBorder, lineWidth: 1)
                            )
                            .shadow(
                                color: Color.black.opacity(0.08),
                                radius: 10,
                                x: 0,
                                y: 6
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("startMatch.sport.\(sport.rawValue)")
                    }
                }
                .frame(maxWidth: 360)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        .navigationTitle("Choose Racket Sport")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: MatchSport.self) { sport in
            StartNewMatchView(
                selectedSport: sport,
                activeMatches: activeMatches,
                onComplete: onComplete
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") {
                    dismiss()
                }
                .accessibilityIdentifier("startMatch.closeButton")
            }
        }
    }

    @ViewBuilder
    private func sportGlyph(for sport: MatchSport, isAvailable: Bool) -> some View {
        let foreground = isAvailable ? Color.white : Color.secondary.opacity(0.72)

        switch sport {
        case .squash:
            ZStack {
                Circle()
                    .stroke(foreground, lineWidth: 2.5)
                    .frame(width: 20, height: 20)
                Circle()
                    .fill(foreground)
                    .frame(width: 5, height: 5)
                    .offset(x: 4, y: -4)
            }
        case .racketball:
            ZStack {
                Circle()
                    .fill(foreground)
                    .frame(width: 20, height: 20)
                Circle()
                    .fill((isAvailable ? Color.dashboardAccentPink : Color.secondary.opacity(0.18)))
                    .frame(width: 4, height: 4)
                    .offset(x: -4, y: -4)
                Circle()
                    .fill((isAvailable ? Color.dashboardAccentPink : Color.secondary.opacity(0.18)))
                    .frame(width: 4, height: 4)
                    .offset(x: 4, y: 4)
            }
        case .tennis, .padel:
            ZStack {
                Circle()
                    .stroke(foreground, lineWidth: 2.5)
                    .frame(width: 22, height: 22)
                Path { path in
                    path.move(to: CGPoint(x: 18, y: 10))
                    path.addQuadCurve(to: CGPoint(x: 18, y: 30), control: CGPoint(x: 10, y: 20))
                    path.move(to: CGPoint(x: 30, y: 10))
                    path.addQuadCurve(to: CGPoint(x: 30, y: 30), control: CGPoint(x: 22, y: 20))
                }
                .stroke(foreground, lineWidth: 2)
                .frame(width: 40, height: 40)
            }
        case .tableTennis:
            ZStack {
                Circle()
                    .fill(foreground)
                    .frame(width: 16, height: 16)
                    .offset(x: -2, y: -6)
                Capsule()
                    .fill(foreground)
                    .frame(width: 8, height: 20)
                    .offset(x: 6, y: 8)
            }
        case .pickleball:
            ZStack {
                Circle()
                    .stroke(foreground, lineWidth: 2.2)
                    .frame(width: 20, height: 20)
                ForEach([(-4.0), 0.0, 4.0], id: \.self) { y in
                    Circle()
                        .fill(foreground)
                        .frame(width: 3.5, height: 3.5)
                        .offset(x: -3, y: y)
                    Circle()
                        .fill(foreground)
                        .frame(width: 3.5, height: 3.5)
                        .offset(x: 3, y: y)
                }
            }
        case .badminton:
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Capsule().fill(foreground).frame(width: 4, height: 12).rotationEffect(.degrees(-20))
                    Capsule().fill(foreground).frame(width: 4, height: 12)
                    Capsule().fill(foreground).frame(width: 4, height: 12).rotationEffect(.degrees(20))
                }
                Circle()
                    .fill(foreground)
                    .frame(width: 9, height: 9)
            }
        }
    }
}

struct StartNewMatchView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: MatchSetupFocusField?

    let selectedSport: MatchSport
    let activeMatches: [MatchSummary]
    let onComplete: (StartNewMatchResult) -> Void

    @State private var formState = MatchSetupFormState()
    @State private var availableCourts: [CourtSummary] = []
    @State private var playerSuggestions: [PlayerLookup] = []
    @State private var refereeSuggestions: [String] = []
    @State private var loadedOrganizationType: String?
    @State private var loadedOrganizationPlan: String?
    @State private var loadedEnabledSports: [String] = []
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var setupNotice: String?
    @State private var lookupTask: Task<Void, Never>?

    private var session: UserSession? { container.sessionStore.session }

    private var organizationID: Int? { session?.organizationID }

    private var organizationType: String {
        if let loadedOrganizationType {
            return loadedOrganizationType.lowercased()
        }

        if session?.isPersonalAccount == true {
            return "personal"
        }

        return (session?.organizationType ?? "club").lowercased()
    }

    private var organizationPlan: String {
        if let loadedOrganizationPlan, !loadedOrganizationPlan.isEmpty {
            return loadedOrganizationPlan.lowercased()
        }

        if let plan = session?.plan, !plan.isEmpty {
            return plan.lowercased()
        }

        return organizationType == "personal" ? "personal_free" : "club_essentials"
    }

    private var isPersonalAccount: Bool { organizationType == "personal" }
    private var isTennisMatch: Bool { selectedSport == .tennis }
    private var showsTennisDoublesToggle: Bool { isTennisMatch }
    private var showsCountryFields: Bool { !(isTennisMatch && isPersonalAccount) }
    private var showsHandednessToggle: Bool { !isTennisMatch }

    private var canChooseShirtColors: Bool {
        !isPersonalAccount || organizationPlan == "personal_plus"
    }

    private var enabledSportIDs: Set<String> {
        let source = loadedEnabledSports.isEmpty
            ? (session?.normalizedEnabledSports ?? ["squash", "racketball", "tennis"])
            : loadedEnabledSports
        return Set(source.map { $0.lowercased() })
    }

    private var personalActiveMatch: MatchSummary? {
        isPersonalAccount ? activeMatches.first : nil
    }

    private var selectedCourt: CourtSummary? {
        availableCourts.first(where: { String($0.id) == formState.courtID })
    }

    private var activeCourtMatch: MatchSummary? {
        activeMatches.first(where: { ($0.courtName ?? "") == formState.courtName })
    }

    private var shouldScheduleMatch: Bool {
        !isPersonalAccount && (formState.scheduleMatch || activeCourtMatch != nil)
    }

    private var canSubmit: Bool {
        let hasPrimaryPlayers = !formState.player1Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !formState.player2Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasDoublesPlayers = !formState.isDoubles
            || (
                !formState.player3Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !formState.player4Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        let hasCourt = isPersonalAccount || (!formState.courtID.isEmpty && !formState.courtName.isEmpty)
        let hasBands = !formState.handicapEnabled || (!formState.player1Band.isEmpty && !formState.player2Band.isEmpty)
        return hasPrimaryPlayers && hasDoublesPlayers && hasCourt && hasBands && personalActiveMatch == nil && enabledSportIDs.contains(selectedSport.rawValue)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                introCard

                if let errorMessage {
                    noticeCard(errorMessage, tint: .red)
                }

                if let setupNotice, !setupNotice.isEmpty {
                    noticeCard(setupNotice, tint: Color.dashboardBrand)
                }

                if showsTennisDoublesToggle {
                    matchTypeCard
                }

                if isTennisMatch && formState.isDoubles {
                    doublesTeamCard(
                        title: "Doubles Team 1",
                        primaryPlayerTitle: "Player 1",
                        secondaryPlayerTitle: "Player 2",
                        primaryFirstName: $formState.player1Name,
                        primarySurname: $formState.player1Surname,
                        secondaryFirstName: $formState.player2Name,
                        secondarySurname: $formState.player2Surname,
                        shirtColor: $formState.player1ShirtColor,
                        primaryNameFocus: .player1Name,
                        primarySurnameFocus: .player1Surname,
                        secondaryNameFocus: .player2Name,
                        secondarySurnameFocus: .player2Surname
                    )

                    doublesTeamCard(
                        title: "Doubles Team 2",
                        primaryPlayerTitle: "Player 3",
                        secondaryPlayerTitle: "Player 4",
                        primaryFirstName: $formState.player3Name,
                        primarySurname: $formState.player3Surname,
                        secondaryFirstName: $formState.player4Name,
                        secondarySurname: $formState.player4Surname,
                        shirtColor: $formState.player2ShirtColor,
                        primaryNameFocus: .player3Name,
                        primarySurnameFocus: .player3Surname,
                        secondaryNameFocus: .player4Name,
                        secondarySurnameFocus: .player4Surname
                    )
                } else {
                    playerCard(
                        title: "Player 1",
                        firstName: $formState.player1Name,
                        surname: $formState.player1Surname,
                        country: $formState.player1Country,
                        isLeftHanded: $formState.player1IsLeftHanded,
                        shirtColor: $formState.player1ShirtColor,
                        nameFocus: .player1Name,
                        surnameFocus: .player1Surname,
                        countryFocus: .player1Country,
                        suggestions: activeLookupTarget == .player1 ? playerSuggestions : []
                    ) { suggestion in
                        applyPlayerSuggestion(.player1, suggestion: suggestion)
                    }

                    playerCard(
                        title: "Player 2",
                        firstName: $formState.player2Name,
                        surname: $formState.player2Surname,
                        country: $formState.player2Country,
                        isLeftHanded: $formState.player2IsLeftHanded,
                        shirtColor: $formState.player2ShirtColor,
                        nameFocus: .player2Name,
                        surnameFocus: .player2Surname,
                        countryFocus: .player2Country,
                        suggestions: activeLookupTarget == .player2 ? playerSuggestions : []
                    ) { suggestion in
                        applyPlayerSuggestion(.player2, suggestion: suggestion)
                    }
                }

                if !isPersonalAccount {
                    courtCard
                }

                formatCard

                if !isPersonalAccount {
                    refereeCard
                }

                if formState.handicapEnabled {
                    handicapCard
                }

                submitActions
            }
            .frame(maxWidth: 460)
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
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
        .navigationTitle(selectedSport.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadSetup() }
        .onChange(of: formState.player1Name) { queueLookupIfNeeded() }
        .onChange(of: formState.player1Surname) { queueLookupIfNeeded() }
        .onChange(of: formState.player2Name) { queueLookupIfNeeded() }
        .onChange(of: formState.player2Surname) { queueLookupIfNeeded() }
        .onChange(of: formState.player3Name) { queueLookupIfNeeded() }
        .onChange(of: formState.player3Surname) { queueLookupIfNeeded() }
        .onChange(of: formState.player4Name) { queueLookupIfNeeded() }
        .onChange(of: formState.player4Surname) { queueLookupIfNeeded() }
        .onChange(of: formState.refereeName) { queueLookupIfNeeded() }
        .onChange(of: focusedField) { queueLookupIfNeeded() }
        .onChange(of: formState.courtID) { updateSelectedCourt() }
        .onChange(of: formState.scheduleMatch) { refreshSetupNotice() }
        .onDisappear { lookupTask?.cancel() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") {
                    dismiss()
                }
                .accessibilityIdentifier("startMatch.setup.closeButton")
            }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !isTennisMatch {
                Text(selectedSport.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dashboardBrand)
            }

            Text("Match Setup")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            if !isTennisMatch {
                Text(
                    isPersonalAccount
                        ? "Enter both players and choose the match format before opening the live scoring screen."
                        : "Complete the court, player, and match format details before opening the live scoring screen."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if !canChooseShirtColors {
                Text("Shirt colours are available on Personal+ and club plans.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.dashboardAccentPink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.dashboardHeroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.dashboardBorder, lineWidth: 1)
        )
    }

    private var matchTypeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                toggleOptionButton(title: "Singles", isSelected: !formState.isDoubles) {
                    formState.isDoubles = false
                }
                .accessibilityIdentifier("startMatch.matchType.singles")

                toggleOptionButton(title: "Doubles", isSelected: formState.isDoubles) {
                    formState.isDoubles = true
                }
                .accessibilityIdentifier("startMatch.matchType.doubles")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.dashboardCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.dashboardBorder, lineWidth: 1)
        )
    }

    private var courtCard: some View {
        cardSection(title: "Court") {
            VStack(alignment: .leading, spacing: 14) {
                if isLoading && availableCourts.isEmpty {
                    ProgressView("Loading courts...")
                        .tint(Color.dashboardBrand)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Court")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Picker("Court", selection: $formState.courtID) {
                            Text("Select a court").tag("")
                            ForEach(availableCourts) { court in
                                Text(court.courtName).tag(String(court.id))
                            }
                        }
                        .accessibilityIdentifier("startMatch.courtPicker")
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.dashboardInnerCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    if !formState.courtAlias.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Court Alias")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(formState.courtAlias)
                                .font(.body.weight(.medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.dashboardInnerCardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    private var formatCard: some View {
        cardSection(title: "Format") {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    selectionCard(title: "Match Format", value: $formState.bestOf, options: [1, 3, 5]) { value in
                        "Best of \(value)"
                    }

                    selectionCard(title: "Game Format", value: $formState.scoreType, options: isTennisMatch ? [4, 6] : [11, 15]) { value in
                        if isTennisMatch {
                            return "First to \(value)"
                        }
                        return "PAR-\(value)"
                    }
                    .disabled(formState.handicapEnabled)
                    .opacity(formState.handicapEnabled ? 0.6 : 1)
                }

                if !isTennisMatch {
                    Toggle(isOn: $formState.handicapEnabled) {
                        Text("Handicap Match")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(Color.dashboardBrand)
                    .accessibilityIdentifier("startMatch.handicapToggle")
                    .onChange(of: formState.handicapEnabled) {
                        if formState.handicapEnabled {
                            formState.scoreType = 15
                        } else {
                            formState.player1Band = ""
                            formState.player2Band = ""
                            formState.player1Offset = 0
                            formState.player2Offset = 0
                        }
                        refreshSetupNotice()
                    }

                    if !isPersonalAccount {
                        Toggle(isOn: $formState.scheduleMatch) {
                            Text("Schedule Match")
                                .font(.subheadline.weight(.semibold))
                        }
                        .tint(Color.dashboardBrand)
                        .accessibilityIdentifier("startMatch.scheduleToggle")
                    }
                } else if !isPersonalAccount {
                    Toggle(isOn: $formState.scheduleMatch) {
                        Text("Schedule Match")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(Color.dashboardBrand)
                    .accessibilityIdentifier("startMatch.scheduleToggle")
                }
            }
        }
    }

    private var refereeCard: some View {
        cardSection(title: "Referee") {
            VStack(alignment: .leading, spacing: 12) {
                labeledField(
                    title: "Referee",
                    placeholder: "Match official",
                    text: $formState.refereeName,
                    focus: .referee
                )

                if activeLookupTarget == .referee && !refereeSuggestions.isEmpty {
                    suggestionList(refereeSuggestions, id: \.self) { suggestion in
                        Button {
                            formState.refereeName = suggestion
                            refereeSuggestions = []
                            focusedField = nil
                        } label: {
                            Text(suggestion)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var handicapCard: some View {
        cardSection(title: "Handicap Setup") {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    bandPicker(title: "Player 1 Band", selection: $formState.player1Band)
                    bandPicker(title: "Player 2 Band", selection: $formState.player2Band)
                }

                HStack(spacing: 12) {
                    readonlyValue(title: "Player 1 Offset", value: "\(formState.player1Offset)")
                    readonlyValue(title: "Player 2 Offset", value: "\(formState.player2Offset)")
                }

                Text(handicapSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: formState.player1Band) { updateHandicapOffsets() }
            .onChange(of: formState.player2Band) { updateHandicapOffsets() }
        }
    }

    private var submitActions: some View {
        VStack(spacing: 12) {
            Button {
                Task { await submitMatch() }
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Start Match")
                            .font(.headline.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.dashboardBrand)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting || !canSubmit)
            .opacity(isSubmitting || !canSubmit ? 0.7 : 1)
            .accessibilityIdentifier("startMatch.startButton")

            if let personalActiveMatch {
                Button("Resume Active Match") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onComplete(.openMatch(personalActiveMatch.id))
                    }
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.dashboardBrand)
                .accessibilityIdentifier("startMatch.resumeActiveMatchButton")
            }
        }
    }

    private var activeLookupTarget: MatchLookupTarget? {
        switch focusedField {
        case .player1Name, .player1Surname:
            return .player1
        case .player2Name, .player2Surname:
            return .player2
        case .player3Name, .player3Surname:
            return .player3
        case .player4Name, .player4Surname:
            return .player4
        case .referee:
            return .referee
        default:
            return nil
        }
    }

    private var handicapSummary: String {
        guard !formState.player1Band.isEmpty, !formState.player2Band.isEmpty else {
            return "Select both bands to see the starting offset for each player."
        }

        return "\(formState.player1Band) vs \(formState.player2Band): Player 1 starts \(formState.player1Offset), Player 2 starts \(formState.player2Offset)."
    }

    @ViewBuilder
    private func playerCard(
        title: String,
        firstName: Binding<String>,
        surname: Binding<String>,
        country: Binding<String>,
        isLeftHanded: Binding<Bool>,
        shirtColor: Binding<String>,
        nameFocus: MatchSetupFocusField,
        surnameFocus: MatchSetupFocusField,
        countryFocus: MatchSetupFocusField,
        suggestions: [PlayerLookup],
        applySuggestion: @escaping (PlayerLookup) -> Void
    ) -> some View {
        cardSection(title: title) {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    labeledField(title: "First Name *", placeholder: "First name", text: firstName, focus: nameFocus)
                    labeledField(title: "Surname", placeholder: "Surname", text: surname, focus: surnameFocus)
                }

                if showsHandednessToggle {
                    Toggle(isOn: isLeftHanded) {
                        Text("Lefty")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(Color.dashboardBrand)
                }

                if showsCountryFields {
                    countryField(title: "Country", text: country, focus: countryFocus)
                }

                if !suggestions.isEmpty {
                    suggestionList(suggestions, id: \.id) { suggestion in
                        Button {
                            applySuggestion(suggestion)
                        } label: {
                            Text(suggestion.displayName)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if canChooseShirtColors {
                    shirtColorGrid(selection: shirtColor)
                }
            }
        }
    }

    private func doublesTeamCard(
        title: String,
        primaryPlayerTitle: String,
        secondaryPlayerTitle: String,
        primaryFirstName: Binding<String>,
        primarySurname: Binding<String>,
        secondaryFirstName: Binding<String>,
        secondarySurname: Binding<String>,
        shirtColor: Binding<String>,
        primaryNameFocus: MatchSetupFocusField,
        primarySurnameFocus: MatchSetupFocusField,
        secondaryNameFocus: MatchSetupFocusField,
        secondarySurnameFocus: MatchSetupFocusField
    ) -> some View {
        cardSection(title: title) {
            VStack(spacing: 14) {
                doublesPlayerFields(
                    title: primaryPlayerTitle,
                    firstName: primaryFirstName,
                    surname: primarySurname,
                    nameFocus: primaryNameFocus,
                    surnameFocus: primarySurnameFocus
                )

                doublesPlayerFields(
                    title: secondaryPlayerTitle,
                    firstName: secondaryFirstName,
                    surname: secondarySurname,
                    nameFocus: secondaryNameFocus,
                    surnameFocus: secondarySurnameFocus
                )

                if canChooseShirtColors {
                    shirtColorGrid(selection: shirtColor)
                }
            }
        }
    }

    private func cardSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.dashboardCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.dashboardBorder, lineWidth: 1)
        )
    }

    private func noticeCard(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.dashboardCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
    }

    private func labeledField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        focus: MatchSetupFocusField
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.dashboardInnerCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .focused($focusedField, equals: focus)
                .accessibilityIdentifier(accessibilityIdentifier(for: focus))
        }
    }

    private func countryField(
        title: String,
        text: Binding<String>,
        focus: MatchSetupFocusField
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Search country", text: text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.dashboardInnerCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .focused($focusedField, equals: focus)
                .accessibilityIdentifier(accessibilityIdentifier(for: focus))

            if focusedField == focus && !filteredCountries(for: text.wrappedValue).isEmpty {
                suggestionList(filteredCountries(for: text.wrappedValue), id: \.self) { countryOption in
                    Button {
                        text.wrappedValue = countryOption
                        focusedField = nil
                    } label: {
                        Text(countryOption)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func suggestionList<Data: RandomAccessCollection, ID: Hashable, Row: View>(
        _ values: Data,
        id: KeyPath<Data.Element, ID>,
        @ViewBuilder row: @escaping (Data.Element) -> Row
    ) -> some View {
        let entries = Array(values)

        return VStack(spacing: 0) {
            ForEach(entries, id: id) { value in
                row(value)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                if value[keyPath: id] != entries.last?[keyPath: id] {
                    Divider()
                }
            }
        }
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func doublesPlayerFields(
        title: String,
        firstName: Binding<String>,
        surname: Binding<String>,
        nameFocus: MatchSetupFocusField,
        surnameFocus: MatchSetupFocusField
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                labeledField(title: "First Name *", placeholder: "First name", text: firstName, focus: nameFocus)
                labeledField(title: "Surname", placeholder: "Surname", text: surname, focus: surnameFocus)
            }
        }
    }

    private func shirtColorGrid(selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shirt Colour")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 40, maximum: 52), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(shirtColorOptions) { option in
                    Button {
                        selection.wrappedValue = option.id
                    } label: {
                        ZStack {
                            Circle()
                                .fill(option.swatch)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Circle()
                                        .stroke(selection.wrappedValue == option.id ? option.border : option.border.opacity(0.5), lineWidth: 2)
                                )

                            if selection.wrappedValue == option.id {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(option.foreground)
                            }
                        }
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(selection.wrappedValue == option.id ? option.swatch.opacity(0.18) : Color.dashboardInnerCardBackground)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.label)
                    .accessibilityIdentifier("startMatch.shirtColor.\(option.id)")
                }
            }
        }
    }

    private func selectionCard(
        title: String,
        value: Binding<Int>,
        options: [Int],
        label: @escaping (Int) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker(title, selection: value) {
                ForEach(options, id: \.self) { option in
                    Text(label(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.dashboardInnerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggleOptionButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.dashboardBrand : Color.dashboardInnerCardBackground)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isSelected ? Color.dashboardBrand : Color.dashboardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func accessibilityIdentifier(for focus: MatchSetupFocusField) -> String {
        switch focus {
        case .player1Name:
            return "startMatch.player1.firstNameField"
        case .player1Surname:
            return "startMatch.player1.surnameField"
        case .player1Country:
            return "startMatch.player1.countryField"
        case .player2Name:
            return "startMatch.player2.firstNameField"
        case .player2Surname:
            return "startMatch.player2.surnameField"
        case .player2Country:
            return "startMatch.player2.countryField"
        case .player3Name:
            return "startMatch.player3.firstNameField"
        case .player3Surname:
            return "startMatch.player3.surnameField"
        case .player4Name:
            return "startMatch.player4.firstNameField"
        case .player4Surname:
            return "startMatch.player4.surnameField"
        case .referee:
            return "startMatch.refereeField"
        }
    }

    private func bandPicker(title: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker(title, selection: selection) {
                Text("Select band").tag("")
                ForEach(handicapBands, id: \.self) { band in
                    Text(band).tag(band)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.dashboardInnerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func readonlyValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.dashboardInnerCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadSetup() async {
        guard let organizationID else {
            await MainActor.run {
                errorMessage = "No active session was found."
            }
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let settings = try await container.apiClient.getOrganizationSettings(organizationID: organizationID)
            await MainActor.run {
                availableCourts = settings.courts
                loadedOrganizationType = settings.organization.organizationType
                loadedOrganizationPlan = settings.organization.plan
                loadedEnabledSports = settings.organization.enabledSports
                if !settings.organization.enabledSports.map({ $0.lowercased() }).contains(selectedSport.rawValue) {
                    errorMessage = "\(selectedSport.displayName) is not enabled for this account or club."
                }
                applyOrganizationDefaults()
                refreshSetupNotice()
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIErrorResponse)?.message ?? "Unable to load match setup."
                isLoading = false
            }
        }
    }

    private func applyOrganizationDefaults() {
        if isTennisMatch {
            formState.scoreType = [4, 6].contains(formState.scoreType) ? formState.scoreType : 6
            formState.bestOf = [1, 3, 5].contains(formState.bestOf) ? formState.bestOf : 3
            formState.handicapEnabled = false
            formState.player1Band = ""
            formState.player2Band = ""
            formState.player1Offset = 0
            formState.player2Offset = 0
        }

        if isPersonalAccount {
            let personalCourt = availableCourts.first
            formState.courtID = personalCourt.map { String($0.id) } ?? ""
            formState.courtName = personalCourt?.courtName ?? "Personal Match"
            formState.courtAlias = personalCourt?.courtAlias ?? "Personal Match"
            formState.refereeName = ""
            formState.scheduleMatch = false
            return
        }

        if formState.courtID.isEmpty, let firstCourt = availableCourts.first {
            formState.courtID = String(firstCourt.id)
            formState.courtName = firstCourt.courtName
            formState.courtAlias = firstCourt.courtAlias
        }
    }

    private func updateSelectedCourt() {
        guard let selectedCourt else {
            formState.courtName = ""
            formState.courtAlias = ""
            refreshSetupNotice()
            return
        }

        formState.courtName = selectedCourt.courtName
        formState.courtAlias = selectedCourt.courtAlias
        refreshSetupNotice()
    }

    private func refreshSetupNotice() {
        if isPersonalAccount {
            setupNotice = personalActiveMatch == nil
                ? nil
                : "You already have an active match running. End it before starting a new personal match."
            return
        }

        if activeCourtMatch != nil, !formState.courtName.isEmpty {
            setupNotice = "There is an active game currently on \(formState.courtName). The new match will be created as a scheduled match ready to start later."
            return
        }

        setupNotice = nil
    }

    private func queueLookupIfNeeded() {
        lookupTask?.cancel()

        guard let organizationID, let activeLookupTarget else {
            playerSuggestions = []
            refereeSuggestions = []
            return
        }

        let query: String
        switch activeLookupTarget {
        case .player1:
            query = formState.player1LookupQuery
        case .player2:
            query = formState.player2LookupQuery
        case .player3:
            query = formState.player3LookupQuery
        case .player4:
            query = formState.player4LookupQuery
        case .referee:
            query = formState.refereeName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard query.count >= 2 else {
            playerSuggestions = []
            refereeSuggestions = []
            return
        }

        lookupTask = Task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }

            do {
                let lookups = try await container.apiClient.searchMatchSetupLookup(
                    organizationID: organizationID,
                    query: query
                )
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    switch activeLookupTarget {
                    case .player1, .player2, .player3, .player4:
                        playerSuggestions = lookups.players
                        refereeSuggestions = []
                    case .referee:
                        refereeSuggestions = lookups.referees
                        playerSuggestions = []
                    }
                }
            } catch {
                await MainActor.run {
                    playerSuggestions = []
                    refereeSuggestions = []
                }
            }
        }
    }

    private func applyPlayerSuggestion(_ target: MatchLookupTarget, suggestion: PlayerLookup) {
        switch target {
        case .player1:
            formState.player1Name = suggestion.firstName
            formState.player1Surname = suggestion.surname
        case .player2:
            formState.player2Name = suggestion.firstName
            formState.player2Surname = suggestion.surname
        case .player3:
            formState.player3Name = suggestion.firstName
            formState.player3Surname = suggestion.surname
        case .player4:
            formState.player4Name = suggestion.firstName
            formState.player4Surname = suggestion.surname
        case .referee:
            break
        }

        playerSuggestions = []
        focusedField = nil
    }

    private func updateHandicapOffsets() {
        guard
            !formState.player1Band.isEmpty,
            !formState.player2Band.isEmpty,
            let player1Value = handicapMatrix[formState.player1Band]?[formState.player2Band],
            let player2Value = handicapMatrix[formState.player2Band]?[formState.player1Band]
        else {
            formState.player1Offset = 0
            formState.player2Offset = 0
            return
        }

        formState.player1Offset = player1Value
        formState.player2Offset = player2Value
    }

    private func filteredCountries(for query: String) -> [String] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return Array(countryOptions.prefix(8))
        }

        return countryOptions
            .filter { $0.localizedCaseInsensitiveContains(trimmedQuery) }
            .prefix(8)
            .map { $0 }
    }

    private func submitMatch() async {
        guard let session else {
            await MainActor.run {
                errorMessage = "No active session was found."
            }
            return
        }

        guard canSubmit else {
            return
        }

        await MainActor.run {
            isSubmitting = true
            errorMessage = nil
        }

        let player1Name = tennisPayloadName(
            primaryName: formState.player1Name,
            primarySurname: formState.player1Surname,
            secondaryName: formState.player2Name,
            secondarySurname: formState.player2Surname,
            isTeam: isTennisMatch && formState.isDoubles
        )
        let player2Name = tennisPayloadName(
            primaryName: formState.isDoubles ? formState.player3Name : formState.player2Name,
            primarySurname: formState.isDoubles ? formState.player3Surname : formState.player2Surname,
            secondaryName: formState.player4Name,
            secondarySurname: formState.player4Surname,
            isTeam: isTennisMatch && formState.isDoubles
        )

        let request = CreateMatchRequest(
            tenantID: String(session.organizationID),
            courtID: isPersonalAccount ? nil : formState.courtID,
            courtName: isPersonalAccount ? nil : formState.courtName,
            courtAlias: isPersonalAccount ? nil : formState.courtAlias,
            player1Name: player1Name,
            player1Surname: isTennisMatch && formState.isDoubles ? "" : formState.player1Surname.trimmingCharacters(in: .whitespacesAndNewlines),
            player1Country: showsCountryFields ? formState.player1Country.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            player1Handedness: formState.player1IsLeftHanded ? "left" : "right",
            player1ShirtColor: canChooseShirtColors ? formState.player1ShirtColor : "navy",
            player2Name: player2Name,
            player2Surname: isTennisMatch && formState.isDoubles ? "" : formState.player2Surname.trimmingCharacters(in: .whitespacesAndNewlines),
            player2Country: showsCountryFields ? formState.player2Country.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            player2Handedness: formState.player2IsLeftHanded ? "left" : "right",
            player2ShirtColor: canChooseShirtColors ? formState.player2ShirtColor : "white",
            refereeName: isPersonalAccount ? "" : formState.refereeName.trimmingCharacters(in: .whitespacesAndNewlines),
            scoreType: formState.scoreType,
            bestOf: formState.bestOf,
            handicapEnabled: formState.handicapEnabled,
            player1Band: formState.player1Band,
            player2Band: formState.player2Band,
            player1Offset: formState.player1Offset,
            player2Offset: formState.player2Offset,
            sport: selectedSport.rawValue,
            status: shouldScheduleMatch ? "scheduled" : "active",
            teamFormat: isTennisMatch ? (formState.isDoubles ? "doubles" : "singles") : nil,
            team1Player1Name: isTennisMatch ? formState.player1Name.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            team1Player1Surname: isTennisMatch ? formState.player1Surname.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            team1Player2Name: (isTennisMatch && formState.isDoubles) ? formState.player2Name.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            team1Player2Surname: (isTennisMatch && formState.isDoubles) ? formState.player2Surname.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            team2Player1Name: isTennisMatch ? (formState.isDoubles ? formState.player3Name.trimmingCharacters(in: .whitespacesAndNewlines) : formState.player2Name.trimmingCharacters(in: .whitespacesAndNewlines)) : nil,
            team2Player1Surname: isTennisMatch ? (formState.isDoubles ? formState.player3Surname.trimmingCharacters(in: .whitespacesAndNewlines) : formState.player2Surname.trimmingCharacters(in: .whitespacesAndNewlines)) : nil,
            team2Player2Name: (isTennisMatch && formState.isDoubles) ? formState.player4Name.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            team2Player2Surname: (isTennisMatch && formState.isDoubles) ? formState.player4Surname.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        )

        do {
            let match = try await container.apiClient.createMatch(request)
            await MainActor.run {
                isSubmitting = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if match.status == "scheduled" || match.autoScheduled == true {
                    onComplete(.scheduled(match.autoScheduleReason))
                } else {
                    onComplete(.openMatch(match.id))
                }
            }
        } catch {
            await MainActor.run {
                isSubmitting = false
                errorMessage = (error as? APIErrorResponse)?.message ?? "Unable to create the match."
            }
        }
    }

    private var shirtColorOptions: [ShirtColorOption] {
        [
            ShirtColorOption(id: "navy", label: "Navy", swatch: Color(red: 18 / 255, green: 60 / 255, blue: 105 / 255), border: Color(red: 18 / 255, green: 60 / 255, blue: 105 / 255), foreground: .white),
            ShirtColorOption(id: "blue", label: "Blue", swatch: Color(red: 18 / 255, green: 116 / 255, blue: 208 / 255), border: Color(red: 18 / 255, green: 116 / 255, blue: 208 / 255), foreground: .white),
            ShirtColorOption(id: "red", label: "Red", swatch: Color(red: 214 / 255, green: 69 / 255, blue: 69 / 255), border: Color(red: 214 / 255, green: 69 / 255, blue: 69 / 255), foreground: .white),
            ShirtColorOption(id: "green", label: "Green", swatch: Color(red: 47 / 255, green: 133 / 255, blue: 90 / 255), border: Color(red: 47 / 255, green: 133 / 255, blue: 90 / 255), foreground: .white),
            ShirtColorOption(id: "black", label: "Black", swatch: Color(red: 31 / 255, green: 41 / 255, blue: 51 / 255), border: Color(red: 31 / 255, green: 41 / 255, blue: 51 / 255), foreground: .white),
            ShirtColorOption(id: "white", label: "White", swatch: .white, border: Color(red: 188 / 255, green: 204 / 255, blue: 220 / 255), foreground: Color(red: 16 / 255, green: 42 / 255, blue: 67 / 255)),
            ShirtColorOption(id: "yellow", label: "Yellow", swatch: Color(red: 247 / 255, green: 209 / 255, blue: 84 / 255), border: Color(red: 227 / 255, green: 185 / 255, blue: 36 / 255), foreground: Color(red: 16 / 255, green: 42 / 255, blue: 67 / 255)),
            ShirtColorOption(id: "orange", label: "Orange", swatch: Color(red: 217 / 255, green: 130 / 255, blue: 43 / 255), border: Color(red: 217 / 255, green: 130 / 255, blue: 43 / 255), foreground: .white),
            ShirtColorOption(id: "purple", label: "Purple", swatch: Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255), border: Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255), foreground: .white),
            ShirtColorOption(id: "pink", label: "Pink", swatch: Color(red: 217 / 255, green: 70 / 255, blue: 143 / 255), border: Color(red: 217 / 255, green: 70 / 255, blue: 143 / 255), foreground: .white)
        ]
    }

    private func tennisPayloadName(
        primaryName: String,
        primarySurname: String,
        secondaryName: String,
        secondarySurname: String,
        isTeam: Bool
    ) -> String {
        let primary = displayName(firstName: primaryName, surname: primarySurname)
        guard isTeam else {
            return primary
        }

        let secondary = displayName(firstName: secondaryName, surname: secondarySurname)
        return [primary, secondary]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }

    private func displayName(firstName: String, surname: String) -> String {
        [firstName, surname]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var handicapBands: [String] {
        ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M"]
    }

    private var handicapMatrix: [String: [String: Int]] {
        [
            "A": ["A": 0, "B": -1, "C": -2, "D": -3, "E": -4, "F": -5, "G": -6, "H": -6, "I": -7, "J": -8, "K": -8, "L": -9, "M": -10],
            "B": ["A": 1, "B": 0, "C": -1, "D": -2, "E": -3, "F": -4, "G": -5, "H": -6, "I": -6, "J": -7, "K": -8, "L": -8, "M": -9],
            "C": ["A": 2, "B": 1, "C": 0, "D": -1, "E": -2, "F": -3, "G": -4, "H": -5, "I": -6, "J": -6, "K": -7, "L": -8, "M": -8],
            "D": ["A": 3, "B": 2, "C": 1, "D": 0, "E": -1, "F": -2, "G": -3, "H": -4, "I": -5, "J": -6, "K": -6, "L": -7, "M": -8],
            "E": ["A": 4, "B": 3, "C": 2, "D": 1, "E": 0, "F": -1, "G": -2, "H": -3, "I": -4, "J": -5, "K": -6, "L": -6, "M": -7],
            "F": ["A": 5, "B": 4, "C": 3, "D": 2, "E": 1, "F": 0, "G": -1, "H": -2, "I": -3, "J": -4, "K": -5, "L": -6, "M": -6],
            "G": ["A": 6, "B": 5, "C": 4, "D": 3, "E": 2, "F": 1, "G": 0, "H": -1, "I": -2, "J": -3, "K": -4, "L": -5, "M": -6],
            "H": ["A": 6, "B": 6, "C": 5, "D": 4, "E": 3, "F": 2, "G": 1, "H": 0, "I": -1, "J": -2, "K": -3, "L": -4, "M": -5],
            "I": ["A": 7, "B": 6, "C": 6, "D": 5, "E": 4, "F": 3, "G": 2, "H": 1, "I": 0, "J": -1, "K": -2, "L": -3, "M": -4],
            "J": ["A": 8, "B": 7, "C": 6, "D": 6, "E": 5, "F": 4, "G": 3, "H": 2, "I": 1, "J": 0, "K": -1, "L": -2, "M": -3],
            "K": ["A": 8, "B": 8, "C": 7, "D": 6, "E": 6, "F": 5, "G": 4, "H": 3, "I": 2, "J": 1, "K": 0, "L": -1, "M": -2],
            "L": ["A": 9, "B": 8, "C": 8, "D": 7, "E": 6, "F": 6, "G": 5, "H": 4, "I": 3, "J": 2, "K": 1, "L": 0, "M": -1],
            "M": ["A": 10, "B": 9, "C": 8, "D": 8, "E": 7, "F": 6, "G": 6, "H": 5, "I": 4, "J": 3, "K": 2, "L": 1, "M": 0]
        ]
    }

    private var countryOptions: [String] {
        [
            "Afghanistan", "Albania", "Algeria", "Andorra", "Angola", "Antigua and Barbuda", "Argentina",
            "Armenia", "Australia", "Austria", "Azerbaijan", "Bahamas", "Bahrain", "Bangladesh", "Barbados",
            "Belarus", "Belgium", "Belize", "Benin", "Bhutan", "Bolivia", "Bosnia and Herzegovina",
            "Botswana", "Brazil", "Brunei", "Bulgaria", "Burkina Faso", "Burundi", "Cabo Verde", "Cambodia",
            "Cameroon", "Canada", "Central African Republic", "Chad", "Chile", "China", "Colombia", "Comoros",
            "Congo", "Costa Rica", "Croatia", "Cuba", "Cyprus", "Czechia", "Denmark", "Djibouti", "Dominica",
            "Dominican Republic", "DR Congo", "Ecuador", "Egypt", "El Salvador", "Equatorial Guinea", "Eritrea",
            "Estonia", "Eswatini", "Ethiopia", "Fiji", "Finland", "France", "Gabon", "Gambia", "Georgia",
            "Germany", "Ghana", "Greece", "Grenada", "Guatemala", "Guinea", "Guinea-Bissau", "Guyana", "Haiti",
            "Honduras", "Hungary", "Iceland", "India", "Indonesia", "Iran", "Iraq", "Ireland", "Israel", "Italy",
            "Ivory Coast", "Jamaica", "Japan", "Jordan", "Kazakhstan", "Kenya", "Kiribati", "Kuwait",
            "Kyrgyzstan", "Laos", "Latvia", "Lebanon", "Lesotho", "Liberia", "Libya", "Liechtenstein",
            "Lithuania", "Luxembourg", "Madagascar", "Malawi", "Malaysia", "Maldives", "Mali", "Malta",
            "Marshall Islands", "Mauritania", "Mauritius", "Mexico", "Micronesia", "Moldova", "Monaco",
            "Mongolia", "Montenegro", "Morocco", "Mozambique", "Myanmar", "Namibia", "Nauru", "Nepal",
            "Netherlands", "New Zealand", "Nicaragua", "Niger", "Nigeria", "North Korea", "North Macedonia",
            "Norway", "Oman", "Pakistan", "Palau", "Palestine", "Panama", "Papua New Guinea", "Paraguay", "Peru",
            "Philippines", "Poland", "Portugal", "Qatar", "Romania", "Russia", "Rwanda", "Saint Kitts and Nevis",
            "Saint Lucia", "Saint Vincent and the Grenadines", "Samoa", "San Marino", "Sao Tome and Principe",
            "Saudi Arabia", "Senegal", "Serbia", "Seychelles", "Sierra Leone", "Singapore", "Slovakia", "Slovenia",
            "Solomon Islands", "Somalia", "South Africa", "South Korea", "South Sudan", "Spain", "Sri Lanka",
            "Sudan", "Suriname", "Sweden", "Switzerland", "Syria", "Taiwan", "Tajikistan", "Tanzania", "Thailand",
            "Timor-Leste", "Togo", "Tonga", "Trinidad and Tobago", "Tunisia", "Turkey", "Turkmenistan", "Tuvalu",
            "Uganda", "Ukraine", "United Arab Emirates", "United Kingdom", "United States", "Uruguay", "Uzbekistan",
            "Vanuatu", "Vatican City", "Venezuela", "Vietnam", "Yemen", "Zambia", "Zimbabwe"
        ]
    }
}

private extension Color {
    static let dashboardBrand = Color(red: 18 / 255, green: 116 / 255, blue: 208 / 255)
    static let dashboardBrandDeep = Color(red: 15 / 255, green: 87 / 255, blue: 194 / 255)
    static let dashboardAccentPink = Color(red: 236 / 255, green: 94 / 255, blue: 168 / 255)
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
    static let dashboardCardBackground = Color(UIColor.secondarySystemGroupedBackground)
    static let dashboardHeroBackground = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 20 / 255, green: 31 / 255, blue: 45 / 255, alpha: 1)
                : UIColor(red: 248 / 255, green: 251 / 255, blue: 255 / 255, alpha: 1)
        }
    )
    static let dashboardInnerCardBackground = Color(UIColor.tertiarySystemGroupedBackground)
    static let dashboardBorder = Color(
        UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor.white.withAlphaComponent(0.08)
            }

            return UIColor(red: 217 / 255, green: 226 / 255, blue: 236 / 255, alpha: 1)
        }
    )
}
