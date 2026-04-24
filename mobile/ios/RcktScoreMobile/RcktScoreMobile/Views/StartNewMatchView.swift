import SwiftUI

private enum MatchSetupFocusField: Hashable {
    case player1Name
    case player1Surname
    case player1Country
    case player2Name
    case player2Surname
    case player2Country
    case referee
}

private enum MatchLookupTarget: Equatable {
    case player1
    case player2
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
}

struct StartNewMatchView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: MatchSetupFocusField?

    let activeMatches: [MatchSummary]
    let onComplete: (StartNewMatchResult) -> Void

    @State private var formState = MatchSetupFormState()
    @State private var availableCourts: [CourtSummary] = []
    @State private var playerSuggestions: [PlayerLookup] = []
    @State private var refereeSuggestions: [String] = []
    @State private var loadedOrganizationType: String?
    @State private var loadedOrganizationPlan: String?
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

    private var canChooseShirtColors: Bool {
        !isPersonalAccount || organizationPlan == "personal_plus"
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
        let hasPlayers = !formState.player1Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !formState.player2Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasCourt = isPersonalAccount || (!formState.courtID.isEmpty && !formState.courtName.isEmpty)
        let hasBands = !formState.handicapEnabled || (!formState.player1Band.isEmpty && !formState.player2Band.isEmpty)
        return hasPlayers && hasCourt && hasBands && personalActiveMatch == nil
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

                if !isPersonalAccount {
                    courtCard
                }

                formatCard

                if !isPersonalAccount {
                    refereeCard
                }

                if !isPersonalAccount && formState.handicapEnabled {
                    handicapCard
                }

                submitActions
            }
            .padding()
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
        .navigationTitle("Start New Match")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadSetup() }
        .onChange(of: formState.player1Name) { queueLookupIfNeeded() }
        .onChange(of: formState.player1Surname) { queueLookupIfNeeded() }
        .onChange(of: formState.player2Name) { queueLookupIfNeeded() }
        .onChange(of: formState.player2Surname) { queueLookupIfNeeded() }
        .onChange(of: formState.refereeName) { queueLookupIfNeeded() }
        .onChange(of: focusedField) { queueLookupIfNeeded() }
        .onChange(of: formState.courtID) { updateSelectedCourt() }
        .onChange(of: formState.scheduleMatch) { refreshSetupNotice() }
        .onDisappear { lookupTask?.cancel() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Match Setup")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Text(
                isPersonalAccount
                    ? "Enter both players and choose the match format before opening the live scoring screen."
                    : "Complete the court, player, and match format details before opening the live scoring screen."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

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

                    selectionCard(title: "Game Format", value: $formState.scoreType, options: [11, 15]) { value in
                        "PAR-\(value)"
                    }
                    .disabled(formState.handicapEnabled)
                    .opacity(formState.handicapEnabled ? 0.6 : 1)
                }

                if !isPersonalAccount {
                    Toggle(isOn: $formState.handicapEnabled) {
                        Text("Handicap Match")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(Color.dashboardBrand)
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

                    Toggle(isOn: $formState.scheduleMatch) {
                        Text("Schedule Match")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(Color.dashboardBrand)
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
            }
        }
    }

    private var activeLookupTarget: MatchLookupTarget? {
        switch focusedField {
        case .player1Name, .player1Surname:
            return .player1
        case .player2Name, .player2Surname:
            return .player2
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

                Toggle(isOn: isLeftHanded) {
                    Text("Lefty")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(Color.dashboardBrand)

                countryField(title: "Country", text: country, focus: countryFocus)

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

    private func shirtColorGrid(selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shirt Colour")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(shirtColorOptions) { option in
                    Button {
                        selection.wrappedValue = option.id
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(option.swatch)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Circle()
                                        .stroke(option.border, lineWidth: 1)
                                )

                            Text(option.label)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selection.wrappedValue == option.id ? option.foreground : .primary)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(selection.wrappedValue == option.id ? option.swatch : Color.dashboardInnerCardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(selection.wrappedValue == option.id ? option.border : Color.dashboardBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
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
        if isPersonalAccount {
            let personalCourt = availableCourts.first
            formState.courtID = personalCourt.map { String($0.id) } ?? ""
            formState.courtName = personalCourt?.courtName ?? "Personal Match"
            formState.courtAlias = personalCourt?.courtAlias ?? "Personal Match"
            formState.refereeName = ""
            formState.handicapEnabled = false
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
                    case .player1, .player2:
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

        let request = CreateMatchRequest(
            tenantID: String(session.organizationID),
            courtID: isPersonalAccount ? nil : formState.courtID,
            courtName: isPersonalAccount ? nil : formState.courtName,
            courtAlias: isPersonalAccount ? nil : formState.courtAlias,
            player1Name: formState.player1Name.trimmingCharacters(in: .whitespacesAndNewlines),
            player1Surname: formState.player1Surname.trimmingCharacters(in: .whitespacesAndNewlines),
            player1Country: formState.player1Country.trimmingCharacters(in: .whitespacesAndNewlines),
            player1Handedness: formState.player1IsLeftHanded ? "left" : "right",
            player1ShirtColor: canChooseShirtColors ? formState.player1ShirtColor : "navy",
            player2Name: formState.player2Name.trimmingCharacters(in: .whitespacesAndNewlines),
            player2Surname: formState.player2Surname.trimmingCharacters(in: .whitespacesAndNewlines),
            player2Country: formState.player2Country.trimmingCharacters(in: .whitespacesAndNewlines),
            player2Handedness: formState.player2IsLeftHanded ? "left" : "right",
            player2ShirtColor: canChooseShirtColors ? formState.player2ShirtColor : "white",
            refereeName: isPersonalAccount ? "" : formState.refereeName.trimmingCharacters(in: .whitespacesAndNewlines),
            scoreType: formState.scoreType,
            bestOf: formState.bestOf,
            handicapEnabled: isPersonalAccount ? false : formState.handicapEnabled,
            player1Band: isPersonalAccount ? "" : formState.player1Band,
            player2Band: isPersonalAccount ? "" : formState.player2Band,
            player1Offset: isPersonalAccount ? 0 : formState.player1Offset,
            player2Offset: isPersonalAccount ? 0 : formState.player2Offset,
            sport: "squash",
            status: shouldScheduleMatch ? "scheduled" : "active"
        )

        do {
            let match = try await container.apiClient.createMatch(request)
            await MainActor.run {
                isSubmitting = false
            }

            dismiss()
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
    static let dashboardAccentPink = Color(red: 236 / 255, green: 94 / 255, blue: 168 / 255)
    static let dashboardBackgroundStart = Color(red: 236 / 255, green: 245 / 255, blue: 255 / 255)
    static let dashboardBackgroundEnd = Color(red: 248 / 255, green: 251 / 255, blue: 255 / 255)
    static let dashboardCardBackground = Color.white.opacity(0.92)
    static let dashboardHeroBackground = Color.white.opacity(0.96)
    static let dashboardInnerCardBackground = Color(red: 243 / 255, green: 247 / 255, blue: 252 / 255)
    static let dashboardBorder = Color(red: 212 / 255, green: 224 / 255, blue: 241 / 255)
}
