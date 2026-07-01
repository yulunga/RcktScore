import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.colorScheme) private var colorScheme

    @State private var activeMatches: [MatchSummary] = []
    @State private var scheduledMatches: [MatchSummary] = []
    @State private var recentMatches: [MatchSummary] = []
    @State private var organizationSummary: DashboardOrganizationSummary?
    @State private var organizationSettings: OrganizationSettings?
    @State private var isLoading = false
    @State private var isLoadingSettings = false
    @State private var errorMessage: String?
    @State private var settingsErrorMessage: String?
    @State private var settingsSuccessMessage: String?
    @State private var startingScheduledMatchID: String?
    @State private var navigationTarget: MatchRoute?
    @State private var activeSheet: DashboardSheet?
    @State private var dashboardNotice: String?
    @State private var selectedTab: DashboardTab = .home
    @State private var selectedSettingsSection: SettingsSection = .organization
    @State private var organizationDetailsDraft = OrganizationDetailsDraft()
    @State private var newOrganizationUserDraft = OrganizationUserDraft()
    @State private var organizationUserDrafts: [Int: OrganizationUserDraft] = [:]
    @State private var newCourtDraft = CourtDraft()
    @State private var courtDrafts: [Int: CourtDraft] = [:]
    @State private var savingSettingsKey: String?
    @State private var historySearch = ""
    @State private var feedbackName = ""
    @State private var feedbackEmail = ""
    @State private var feedbackCategory = "feedback"
    @State private var feedbackMessage = ""
    @State private var isSubmittingFeedback = false
    @State private var feedbackErrorMessage: String?
    @State private var feedbackSuccessMessage: String?
    @State private var resetEmail = ""
    @State private var isRequestingPasswordReset = false
    @State private var resetErrorMessage: String?
    @State private var resetMessage: String?

    private var session: UserSession? { container.sessionStore.session }
    private var isOnline: Bool { container.networkMonitor.isOnline }
    private var isPersonalAccount: Bool { session?.isPersonalAccount ?? false }
    private var isAdmin: Bool { session?.role.lowercased() == "admin" }
    private var headerPlanLine: String {
        session?.planDisplayName ?? (isPersonalAccount ? "Personal Free" : "Club Essentials")
    }
    private var headerUserLine: String {
        session?.email ?? session?.username ?? ""
    }
    private var homeActiveMatches: [MatchSummary] { Array(activeMatches.prefix(3)) }
    private var homeScheduledMatches: [MatchSummary] { Array(scheduledMatches.prefix(3)) }
    private var homeRecentMatches: [MatchSummary] { Array(recentMatches.prefix(3)) }
    private var filteredRecentMatches: [MatchSummary] {
        let query = historySearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return recentMatches
        }

        return recentMatches.filter { match in
            let fields = [
                match.player1Name,
                match.player1Surname ?? "",
                match.player2Name,
                match.player2Surname ?? "",
                historyWinnerLine(for: match),
                historyScoreLine(for: match),
                formattedMatchDate(for: match)
            ]
            .joined(separator: " ")
            .lowercased()

            return fields.contains(query)
        }
    }
    private var settingsPlanLine: String {
        organizationSummary?.plan.flatMap { planDisplayName(for: $0) } ?? headerPlanLine
    }
    private var settingsOrganizationName: String {
        organizationSummary?.name
            ?? session?.organizationName
            ?? "Organisation"
    }
    private var helpFooterText: String {
        isPersonalAccount
            ? "We will send your message to the Hit n Score support inbox."
            : "Your message will include your club context so support can help faster."
    }
    private var organizationSettingsUsers: [OrganizationUser] {
        organizationSettings?.users ?? []
    }
    private var organizationSettingsCourts: [CourtSummary] {
        organizationSettings?.courts ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    headerSection

                    if selectedTab == .home {
                        startNewMatchHero
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(Color.dashboardCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.dashboardBorder, lineWidth: 1)
                            )
                    }

                    tabContent
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 20)
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
            .safeAreaInset(edge: .bottom) {
                bottomNavigationBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $navigationTarget) { route in
                switch route.presentation {
                case .live(let openSettingsOnLoad):
                    MatchScoringView(matchID: route.id, openSettingsOnLoad: openSettingsOnLoad)
                case .historic:
                    HistoricMatchView(matchID: route.id)
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .newMatch:
                    NavigationStack {
                        StartNewMatchFlowView(activeMatches: activeMatches) { result in
                            handleStartNewMatchResult(result)
                        }
                        .environmentObject(container)
                    }
                    .presentationDetents([.large])
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) { EmptyView() }
            }
            .task {
                seedHelpDefaults()
                await loadDashboard()
            }
            .task(id: selectedTab) {
                seedHelpDefaults()
                if selectedTab == .settings {
                    await loadOrganizationSettingsIfNeeded()
                }
            }
            .refreshable { await loadDashboard() }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 82, height: 82)
                    .offset(y: -9)

                VStack(alignment: .leading, spacing: 3) {
                    (
                        Text("Hit")
                            .foregroundStyle(Color.dashboardBrand)
                        + Text("n")
                            .foregroundStyle(Color.dashboardAccentPink)
                        + Text("Score")
                            .foregroundStyle(Color.dashboardBrand)
                    )
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !headerUserLine.isEmpty {
                        Text(headerUserLine)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.dashboardInk.opacity(0.88))
                            .lineLimit(1)
                    }

                    Text(headerPlanLine)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)

                VStack(alignment: .trailing, spacing: 12) {
                    HStack(spacing: 10) {
                        Button {
                            dashboardNotice = "Notifications are not added yet."
                        } label: {
                            Image(systemName: "bell")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(Color.dashboardInk)
                        }
                        .buttonStyle(.plain)

                        Button("Logout") {
                            Task {
                                await container.logout()
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dashboardBrand)
                    }
                }
                .padding(.top, 8)
            }

            if let dashboardNotice {
                Text(dashboardNotice)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var startNewMatchHero: some View {
        Button {
            activeSheet = .newMatch
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(Color.dashboardBrand)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Start New Match")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color.dashboardBrand,
                        Color.dashboardBrandDeep
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(
                color: colorScheme == .dark ? .clear : Color.black.opacity(0.12),
                radius: 16,
                x: 0,
                y: 10
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            homeContent
        case .matches:
            matchesContent
        case .history:
            historyContent
        case .settings:
            settingsContent
        case .help:
            helpContent
        }
    }

    private var homeContent: some View {
        VStack(spacing: 18) {
            dashboardSection(
                title: "Active Matches",
                systemImage: "dot.radiowaves.left.and.right"
            ) {
                activeMatchesContent(matches: homeActiveMatches)
            }

            if !isPersonalAccount {
                dashboardSection(
                    title: "Scheduled Matches",
                    systemImage: "calendar.badge.clock"
                ) {
                    scheduledMatchesContent(matches: homeScheduledMatches)
                }
            }

            dashboardSection(
                title: "Recent Matches",
                systemImage: "clock"
            ) {
                recentMatchesContent(matches: homeRecentMatches)
            }
        }
    }

    private var matchesContent: some View {
        VStack(spacing: 18) {
            dashboardSection(
                title: "Matches",
                subtitle: isPersonalAccount
                    ? "Your live and upcoming matches in one place."
                    : "All active courts first, then scheduled matches below."
            ) {
                VStack(spacing: 18) {
                    matchesSubsection(title: "Active Matches", icon: "dot.radiowaves.left.and.right") {
                        activeMatchesContent(matches: activeMatches)
                    }

                    if !isPersonalAccount {
                        matchesSubsection(title: "Scheduled Matches", icon: "calendar.badge.clock") {
                            scheduledMatchesContent(matches: scheduledMatches)
                        }
                    }
                }
            }
        }
    }

    private var historyContent: some View {
        VStack(spacing: 18) {
            dashboardSection(
                title: "Recent Matches",
                systemImage: "clock",
                subtitle: "Search completed matches by player name, surname, or date."
            ) {
                if isOnline {
                    VStack(spacing: 14) {
                        dashboardTextField(
                            title: "Search history",
                            placeholder: "Search player or date",
                            text: $historySearch
                        )

                        recentMatchesContent(
                            matches: filteredRecentMatches,
                            emptyMessage: historySearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "No recent matches"
                                : "No completed matches match that search."
                        )
                    }
                } else {
                    offlineHistoricMatchesState
                }
            }
        }
    }

    private var settingsContent: some View {
        VStack(spacing: 18) {
            dashboardSection(
                title: "Settings",
                subtitle: isPersonalAccount
                    ? "Profile and plan details for this account."
                    : "Organisation, users, and courts for this club account."
            ) {
                if isLoadingSettings && organizationSettings == nil {
                    HStack {
                        ProgressView()
                        Spacer()
                    }
                } else {
                    VStack(spacing: 14) {
                        if let settingsErrorMessage {
                            dashboardInlineError(settingsErrorMessage)
                        }

                        if let settingsSuccessMessage {
                            dashboardInlineSuccess(settingsSuccessMessage)
                        }

                        if isPersonalAccount {
                            personalSettingsContent
                        } else {
                            clubSettingsContent
                        }
                    }
                }
            }
        }
    }

    private var personalSettingsContent: some View {
        VStack(spacing: 14) {
            settingsSummaryCard

            VStack(alignment: .leading, spacing: 12) {
                Text("Account")
                    .font(.headline.weight(.semibold))

                settingsValueRow(title: "Username", value: session?.username ?? "Not available")
                settingsValueRow(title: "Email", value: session?.email ?? "Not available")
                settingsValueRow(title: "Plan", value: headerPlanLine)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dashboardInnerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var clubSettingsContent: some View {
        VStack(spacing: 14) {
            settingsSummaryCard
            settingsSectionPicker

            if !isAdmin {
                Text("You are in view-only mode. Only organisation admins can save changes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            switch selectedSettingsSection {
            case .organization:
                organizationDetailsCard
            case .users:
                organizationUsersCard
            case .courts:
                organizationCourtsCard
            case .gameSettings:
                gameSettingsPlaceholderCard
            }
        }
    }

    private var settingsSectionPicker: some View {
        HStack(spacing: 10) {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    selectedSettingsSection = section
                } label: {
                    Text(section.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedSettingsSection == section ? .white : Color.dashboardBrand)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            selectedSettingsSection == section
                                ? Color.dashboardBrand
                                : Color.dashboardInputBackground
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    selectedSettingsSection == section ? Color.dashboardBrand : Color.dashboardBorder,
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var organizationDetailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Organisation Details")
                .font(.headline.weight(.semibold))

            dashboardTextField(
                title: "Club Name",
                placeholder: "Club name",
                text: $organizationDetailsDraft.organizationName
            )
            .disabled(!isAdmin)

            dashboardTextField(
                title: "Primary Contact",
                placeholder: "Primary contact",
                text: $organizationDetailsDraft.organizationContact
            )
            .disabled(!isAdmin)

            dashboardTextField(
                title: "Telephone",
                placeholder: "Telephone",
                text: $organizationDetailsDraft.organizationTelephone,
                keyboardType: .phonePad
            )
            .disabled(!isAdmin)

            dashboardTextField(
                title: "Email",
                placeholder: "club@example.com",
                text: $organizationDetailsDraft.organizationEmail,
                keyboardType: .emailAddress
            )
            .disabled(!isAdmin)

            dashboardTextField(
                title: "Website",
                placeholder: "https://example.com",
                text: $organizationDetailsDraft.organizationWebAddress,
                keyboardType: .URL
            )
            .disabled(!isAdmin)

            dashboardTextField(
                title: "Address",
                placeholder: "Address",
                text: $organizationDetailsDraft.organizationAddress
            )
            .disabled(!isAdmin)

            dashboardTextField(
                title: "Postcode",
                placeholder: "Postcode",
                text: $organizationDetailsDraft.organizationPostcode
            )
            .disabled(!isAdmin)

            Button(currentSettingsButtonTitle(for: "organization-save", defaultTitle: "Save Organisation Details")) {
                saveOrganizationDetails()
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.dashboardBrand)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .buttonStyle(.plain)
            .disabled(!isAdmin || savingSettingsKey != nil)
            .opacity((!isAdmin || savingSettingsKey != nil) ? 0.7 : 1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var organizationUsersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Organisation Users")
                .font(.headline.weight(.semibold))

            VStack(spacing: 12) {
                dashboardTextField(
                    title: "First Name",
                    placeholder: "First name",
                    text: $newOrganizationUserDraft.firstName
                )
                .disabled(!isAdmin)

                dashboardTextField(
                    title: "Surname",
                    placeholder: "Surname",
                    text: $newOrganizationUserDraft.surname
                )
                .disabled(!isAdmin)

                dashboardTextField(
                    title: "Email Address",
                    placeholder: "user@club.com",
                    text: $newOrganizationUserDraft.username,
                    keyboardType: .emailAddress
                )
                .disabled(!isAdmin)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    SecureField("Required for new users", text: $newOrganizationUserDraft.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.dashboardInputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.dashboardBorder, lineWidth: 1)
                        )
                }
                .disabled(!isAdmin)

                settingsRolePicker(selection: $newOrganizationUserDraft.role)
                    .disabled(!isAdmin)

                Button(currentSettingsButtonTitle(for: "user-create", defaultTitle: "Add User")) {
                    createOrganizationUser()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.dashboardBrand)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(!isAdmin || savingSettingsKey != nil)
                .opacity((!isAdmin || savingSettingsKey != nil) ? 0.7 : 1)
            }

            if organizationSettingsUsers.isEmpty {
                emptyState("No organisation users yet.")
            } else {
                ForEach(organizationSettingsUsers) { user in
                    organizationUserRow(user)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var organizationCourtsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Courts")
                .font(.headline.weight(.semibold))

            VStack(spacing: 12) {
                dashboardTextField(
                    title: "Court Name",
                    placeholder: "Court 1",
                    text: $newCourtDraft.courtName
                )
                .disabled(!isAdmin)

                dashboardTextField(
                    title: "Court Alias",
                    placeholder: "Show court name",
                    text: $newCourtDraft.courtAlias
                )
                .disabled(!isAdmin)

                Button(currentSettingsButtonTitle(for: "court-create", defaultTitle: "Add Court")) {
                    createCourt()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.dashboardBrand)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(!isAdmin || savingSettingsKey != nil)
                .opacity((!isAdmin || savingSettingsKey != nil) ? 0.7 : 1)
            }

            if organizationSettingsCourts.isEmpty {
                emptyState("No courts available yet.")
            } else {
                ForEach(organizationSettingsCourts) { court in
                    organizationCourtRow(court)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var gameSettingsPlaceholderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Game Setup")
                .font(.headline.weight(.semibold))

            Text("Operational club settings are available here. Live match format changes, shirt colours, and scheduled-match edits are now handled inside the native match screen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            settingsValueRow(title: "Plan", value: settingsPlanLine)
            settingsValueRow(title: "Organisation Type", value: (organizationSummary?.type ?? session?.organizationType ?? "club").capitalized)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func organizationUserRow(_ user: OrganizationUser) -> some View {
        let binding = Binding<OrganizationUserDraft>(
            get: { organizationUserDrafts[user.id] ?? OrganizationUserDraft(user: user) },
            set: { organizationUserDrafts[user.id] = $0 }
        )

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(userDisplayName(user))
                        .font(.subheadline.weight(.semibold))
                    Text(user.username)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    settingsBadge(title: user.role.capitalized)
                    Text(user.status.capitalized)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            dashboardTextField(title: "First Name", placeholder: "First name", text: binding.firstName)
                .disabled(!isAdmin)
            dashboardTextField(title: "Surname", placeholder: "Surname", text: binding.surname)
                .disabled(!isAdmin)
            dashboardTextField(title: "Email", placeholder: "Email", text: binding.username, keyboardType: .emailAddress)
                .disabled(!isAdmin)

            if user.canEditPassword {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    SecureField("Optional password change", text: binding.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.dashboardInputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.dashboardBorder, lineWidth: 1)
                        )
                }
                .disabled(!isAdmin)
            }

            settingsRolePicker(selection: binding.role)
                .disabled(!isAdmin)

            HStack(spacing: 10) {
                Button(currentSettingsButtonTitle(for: "user-save-\(user.id)", defaultTitle: "Save")) {
                    updateOrganizationUser(user)
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.dashboardBrand)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(!isAdmin || savingSettingsKey != nil)
                .opacity((!isAdmin || savingSettingsKey != nil) ? 0.7 : 1)

                Button(currentSettingsButtonTitle(for: "user-delete-\(user.id)", defaultTitle: "Delete")) {
                    deleteOrganizationUser(user)
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.12))
                .foregroundStyle(.red)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(!isAdmin || savingSettingsKey != nil)
                .opacity((!isAdmin || savingSettingsKey != nil) ? 0.7 : 1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.dashboardBorder, lineWidth: 1)
        )
    }

    private func organizationCourtRow(_ court: CourtSummary) -> some View {
        let binding = Binding<CourtDraft>(
            get: { courtDrafts[court.id] ?? CourtDraft(court: court) },
            set: { courtDrafts[court.id] = $0 }
        )

        return VStack(alignment: .leading, spacing: 12) {
            if let displayCode = court.displayCode, !displayCode.isEmpty {
                HStack {
                    Text("Display Code")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(displayCode)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.dashboardBrand)
                }
            }

            dashboardTextField(title: "Court Name", placeholder: "Court", text: binding.courtName)
                .disabled(!isAdmin)
            dashboardTextField(title: "Court Alias", placeholder: "Alias", text: binding.courtAlias)
                .disabled(!isAdmin)

            HStack(spacing: 10) {
                Button(currentSettingsButtonTitle(for: "court-save-\(court.id)", defaultTitle: "Save")) {
                    updateCourt(court)
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.dashboardBrand)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(!isAdmin || savingSettingsKey != nil)
                .opacity((!isAdmin || savingSettingsKey != nil) ? 0.7 : 1)

                Button(currentSettingsButtonTitle(for: "court-code-\(court.id)", defaultTitle: "New Display Code")) {
                    regenerateCourtDisplayCode(court)
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.dashboardInputBackground)
                .foregroundStyle(Color.dashboardBrand)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.dashboardBorder, lineWidth: 1))
                .buttonStyle(.plain)
                .disabled(!isAdmin || savingSettingsKey != nil)
                .opacity((!isAdmin || savingSettingsKey != nil) ? 0.7 : 1)

                Button(currentSettingsButtonTitle(for: "court-delete-\(court.id)", defaultTitle: "Delete")) {
                    deleteCourt(court)
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.12))
                .foregroundStyle(.red)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(!isAdmin || savingSettingsKey != nil)
                .opacity((!isAdmin || savingSettingsKey != nil) ? 0.7 : 1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.dashboardBorder, lineWidth: 1)
        )
    }

    private func settingsRolePicker(selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Role")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Role", selection: selection) {
                Text("User").tag("user")
                Text("Admin").tag("admin")
            }
            .pickerStyle(.segmented)
        }
    }

    private func settingsValueRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)

            Text(value.isEmpty ? "Not set" : value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var helpContent: some View {
        VStack(spacing: 18) {
            dashboardSection(
                title: "Need Help?",
                subtitle: "Send feedback or request a password reset without leaving the app."
            ) {
                VStack(spacing: 14) {
                    feedbackForm
                    resetForm
                }
            }
        }
    }

    private var bottomNavigationBar: some View {
        HStack(spacing: 0) {
            ForEach(DashboardTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22, weight: selectedTab == tab ? .semibold : .regular))

                        Text(tab.title)
                            .font(.caption.weight(selectedTab == tab ? .semibold : .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedTab == tab ? Color.dashboardBrand : Color.dashboardTabMuted)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .background(
            ZStack(alignment: .top) {
                Color.dashboardTabBarBackground
                Rectangle()
                    .fill(Color.dashboardBorder)
                    .frame(height: 1)
            }
            .ignoresSafeArea()
        )
    }

    @ViewBuilder
    private func activeMatchesContent(matches: [MatchSummary]) -> some View {
        if isLoading && matches.isEmpty {
            HStack {
                ProgressView()
                Spacer()
            }
        } else if matches.isEmpty {
            emptyState("No active matches")
        } else {
            VStack(spacing: 12) {
                ForEach(matches) { match in
                    Button {
                        navigationTarget = MatchRoute(id: match.id)
                    } label: {
                        activeMatchCard(match)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func scheduledMatchesContent(matches: [MatchSummary]) -> some View {
        if isLoading && matches.isEmpty {
            HStack {
                ProgressView()
                Spacer()
            }
        } else if matches.isEmpty {
            emptyState("No scheduled matches")
        } else {
            VStack(spacing: 12) {
                ForEach(matches) { match in
                    scheduledMatchCard(match) {
                        Task { await startScheduledMatch(match.id) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recentMatchesContent(matches: [MatchSummary], emptyMessage: String = "No recent matches") -> some View {
        if !isOnline {
            offlineHistoricMatchesState
        } else if isLoading && matches.isEmpty {
            HStack {
                ProgressView()
                Spacer()
            }
        } else if matches.isEmpty {
            emptyState(emptyMessage)
        } else {
            VStack(spacing: 12) {
                ForEach(matches) { match in
                    Button {
                        navigationTarget = MatchRoute(id: match.id, presentation: .historic)
                    } label: {
                        recentMatchCard(match)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func dashboardSection<Content: View>(
        title: String,
        systemImage: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.dashboardAccentPink)
                    }

                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                }

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.dashboardBorder, lineWidth: 1)
        )
        .shadow(
            color: colorScheme == .dark ? .clear : Color.black.opacity(0.04),
            radius: 12,
            x: 0,
            y: 8
        )
    }

    private func matchesSubsection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.dashboardBrand)
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            content()
        }
    }

    @ViewBuilder
    private func emptyState(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
    }

    private var offlineHistoricMatchesState: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.dashboardBrand)

            Text("Offline")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Historic matches are only available when the app is online.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private func activeMatchCard(_ match: MatchSummary) -> some View {
        let player1 = splitPlayerName(match.player1Name, surname: match.player1Surname)
        let player2 = splitPlayerName(match.player2Name, surname: match.player2Surname)
        let liveScore = currentScoreLine(for: match)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                if let courtName = match.courtName, !courtName.isEmpty {
                    Text(courtName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.dashboardActiveStatus)
                        .frame(width: 9, height: 9)
                    Text("In Progress")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.dashboardActiveStatus)
                }
            }

            HStack(alignment: .center, spacing: 12) {
                playerColumn(firstName: player1.firstName, surname: player1.surname, alignment: .leading)

                Spacer(minLength: 6)

                VStack(spacing: 4) {
                    Text(liveScore)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.dashboardBrand)

                    Text("Best of \(match.bestOf ?? match.state?.bestOf ?? 3)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 6)

                playerColumn(firstName: player2.firstName, surname: player2.surname, alignment: .trailing)

                Button {
                    navigationTarget = MatchRoute(id: match.id)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.dashboardBrand)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.92))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.dashboardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func scheduledMatchCard(_ match: MatchSummary, action: @escaping () -> Void) -> some View {
        let player1 = splitPlayerName(match.player1Name, surname: match.player1Surname)
        let player2 = splitPlayerName(match.player2Name, surname: match.player2Surname)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                if let courtName = match.courtName, !courtName.isEmpty {
                    Text(courtName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Ready to start")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dashboardBrand)
            }

            HStack(alignment: .center, spacing: 12) {
                playerColumn(firstName: player1.firstName, surname: player1.surname, alignment: .leading)

                Spacer(minLength: 4)

                VStack(spacing: 4) {
                    Text(match.courtName ?? "Court")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dashboardInk.opacity(0.64))
                    Text("Best of \(match.bestOf ?? 3)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                playerColumn(firstName: player2.firstName, surname: player2.surname, alignment: .trailing)

                VStack(spacing: 8) {
                    Button(startingScheduledMatchID == match.id ? "Starting..." : "Start") {
                        action()
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.dashboardBrand)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                    .disabled(startingScheduledMatchID != nil)
                    .opacity(startingScheduledMatchID != nil ? 0.7 : 1)

                    Button("Edit") {
                        navigationTarget = MatchRoute(id: match.id, presentation: .live(openSettingsOnLoad: true))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dashboardBrand)
                    .buttonStyle(.plain)
                }
            }

            if let updatedAt = match.updatedAt {
                Text("Scheduled \(formatDate(updatedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func recentMatchCard(_ match: MatchSummary) -> some View {
        let player1 = splitPlayerName(match.player1Name, surname: match.player1Surname)
        let player2 = splitPlayerName(match.player2Name, surname: match.player2Surname)
        let winnerSide = historyWinnerSide(for: match)

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                recentPlayersLine(
                    player1: player1.firstName,
                    player2: player2.firstName,
                    winnerSide: winnerSide
                )
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

                Text(formattedMatchDate(for: match))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(historyFinalScoreLine(for: match))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dashboardInk)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.dashboardBrand)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.92))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.dashboardBorder, lineWidth: 1))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func playerColumn(firstName: String, surname: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(firstName)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            if !surname.isEmpty {
                Text(surname)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    private var settingsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settingsOrganizationName)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                settingsBadge(title: settingsPlanLine)
                if let organizationType = organizationSummary?.type ?? session?.organizationType {
                    settingsBadge(title: organizationType.capitalized)
                }
            }

            HStack(spacing: 12) {
                settingsMetric(title: "Courts", value: String(organizationSummary?.courtCount ?? organizationSettings?.courts.count ?? 0))
                settingsMetric(title: "Users", value: String(organizationSummary?.userCount ?? organizationSettings?.users.count ?? 0))
                settingsMetric(title: "Role", value: session?.role.replacingOccurrences(of: "_", with: " ").capitalized ?? "User")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func settingsCourtsCard(_ courts: [CourtSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Courts")
                .font(.headline.weight(.semibold))

            ForEach(courts) { court in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(court.courtName)
                            .font(.subheadline.weight(.semibold))
                        Text(court.courtAlias)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("#\(court.id)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var feedbackForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ping Us")
                .font(.headline.weight(.semibold))

            dashboardTextField(title: "Name", placeholder: "Your name", text: $feedbackName)
            dashboardTextField(title: "Email", placeholder: "you@example.com", text: $feedbackEmail, keyboardType: .emailAddress)

            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Category", selection: $feedbackCategory) {
                    Text("Feedback").tag("feedback")
                    Text("Issue").tag("issue")
                    Text("Idea").tag("idea")
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Message")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextEditor(text: $feedbackMessage)
                    .frame(minHeight: 120)
                    .padding(10)
                    .background(Color.dashboardInputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.dashboardBorder, lineWidth: 1)
                    )
            }

            if let feedbackErrorMessage {
                dashboardInlineError(feedbackErrorMessage)
            }

            if let feedbackSuccessMessage {
                dashboardInlineSuccess(feedbackSuccessMessage)
            }

            Button(isSubmittingFeedback ? "Sending..." : "Send Feedback") {
                submitFeedback()
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.dashboardBrand)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .buttonStyle(.plain)
            .disabled(isSubmittingFeedback)
            .opacity(isSubmittingFeedback ? 0.75 : 1)

            Text(helpFooterText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var resetForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Password Reset")
                .font(.headline.weight(.semibold))

            dashboardTextField(title: "Account email", placeholder: "you@example.com", text: $resetEmail, keyboardType: .emailAddress)

            if let resetErrorMessage {
                dashboardInlineError(resetErrorMessage)
            }

            if let resetMessage {
                dashboardInlineSuccess(resetMessage)
            }

            Button(isRequestingPasswordReset ? "Sending..." : "Send Reset Link") {
                requestPasswordReset()
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.dashboardBrand.opacity(0.9))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .buttonStyle(.plain)
            .disabled(isRequestingPasswordReset)
            .opacity(isRequestingPasswordReset ? 0.75 : 1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardInnerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func dashboardTextField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text)
                .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                .autocorrectionDisabled(keyboardType == .emailAddress)
                .keyboardType(keyboardType)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.dashboardInputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.dashboardBorder, lineWidth: 1)
                )
        }
    }

    private func dashboardInlineError(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dashboardInlineSuccess(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(Color.green)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsBadge(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.dashboardInputBackground)
            .clipShape(Capsule())
    }

    private func settingsMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func syncSettingsDrafts(from settings: OrganizationSettings) {
        organizationDetailsDraft = OrganizationDetailsDraft(profile: settings.organization)
        organizationUserDrafts = Dictionary(
            uniqueKeysWithValues: settings.users.map { ($0.id, OrganizationUserDraft(user: $0)) }
        )
        courtDrafts = Dictionary(
            uniqueKeysWithValues: settings.courts.map { ($0.id, CourtDraft(court: $0)) }
        )
    }

    private func loadDashboard() async {
        guard let organizationID = container.sessionStore.session?.organizationID else {
            print("DASHBOARD LOAD: missing organization ID in session")
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            print("DASHBOARD LOAD: requesting organization ID \(organizationID)")
            let dashboard = try await container.apiClient.getDashboard(
                organizationID: organizationID,
                activeLimit: 200,
                recentLimit: 200
            )
            await MainActor.run {
                organizationSummary = dashboard.organization
                activeMatches = dashboard.activeMatches
                scheduledMatches = dashboard.scheduledMatches
                recentMatches = dashboard.recentMatches
                isLoading = false
                print(
                    "DASHBOARD LOAD: active=\(dashboard.activeMatches.count) " +
                    "scheduled=\(dashboard.scheduledMatches.count) " +
                    "recent=\(dashboard.recentMatches.count)"
                )
            }
        } catch {
            await MainActor.run {
                print("DASHBOARD LOAD ERROR:", error)
                errorMessage = (error as? APIErrorResponse)?.message ?? "Unable to fetch dashboard data."
                isLoading = false
            }
        }
    }

    private func loadOrganizationSettingsIfNeeded(force: Bool = false) async {
        guard let organizationID = container.sessionStore.session?.organizationID else {
            return
        }

        if organizationSettings != nil && !force {
            return
        }

        await MainActor.run {
            isLoadingSettings = true
            settingsErrorMessage = nil
        }

        do {
            let settings = try await container.apiClient.getOrganizationSettings(organizationID: organizationID)
            await MainActor.run {
                organizationSettings = settings
                syncSettingsDrafts(from: settings)
                isLoadingSettings = false
            }
        } catch {
            await MainActor.run {
                settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to load organisation settings."
                isLoadingSettings = false
            }
        }
    }

    private func currentSettingsButtonTitle(for key: String, defaultTitle: String) -> String {
        savingSettingsKey == key ? "Working..." : defaultTitle
    }

    private func saveOrganizationDetails() {
        guard let organizationID = session?.organizationID else {
            return
        }

        savingSettingsKey = "organization-save"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        Task {
            do {
                let settings = try await container.apiClient.updateOrganizationDetails(
                    organizationID: organizationID,
                    draft: organizationDetailsDraft
                )
                await MainActor.run {
                    organizationSettings = settings
                    syncSettingsDrafts(from: settings)
                    settingsSuccessMessage = "Organisation details updated."
                    savingSettingsKey = nil
                }
                await loadDashboard()
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to save organisation details."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func createOrganizationUser() {
        guard let organizationID = session?.organizationID else {
            return
        }

        let email = newOrganizationUserDraft.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidEmail(email) else {
            settingsErrorMessage = "Enter a valid email address for the user."
            settingsSuccessMessage = nil
            return
        }

        var draft = newOrganizationUserDraft
        draft.username = email

        savingSettingsKey = "user-create"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        Task {
            do {
                try await container.apiClient.createOrganizationUser(
                    organizationID: organizationID,
                    draft: draft
                )
                await loadOrganizationSettingsIfNeeded(force: true)
                await MainActor.run {
                    newOrganizationUserDraft = OrganizationUserDraft()
                    settingsSuccessMessage = "User added to organisation. Invitation email sent and access is pending approval."
                    savingSettingsKey = nil
                }
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to create organisation user."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func updateOrganizationUser(_ user: OrganizationUser) {
        guard let organizationID = session?.organizationID else {
            return
        }
        guard let draft = organizationUserDrafts[user.id] else {
            return
        }

        savingSettingsKey = "user-save-\(user.id)"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        Task {
            do {
                try await container.apiClient.updateOrganizationUser(
                    organizationID: organizationID,
                    userID: user.id,
                    draft: draft,
                    allowPasswordChange: user.canEditPassword
                )
                await loadOrganizationSettingsIfNeeded(force: true)
                await MainActor.run {
                    settingsSuccessMessage = "User updated."
                    savingSettingsKey = nil
                }
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to update the user."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func deleteOrganizationUser(_ user: OrganizationUser) {
        guard let organizationID = session?.organizationID else {
            return
        }

        savingSettingsKey = "user-delete-\(user.id)"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        Task {
            do {
                try await container.apiClient.deleteOrganizationUser(
                    organizationID: organizationID,
                    userID: user.id
                )
                await loadOrganizationSettingsIfNeeded(force: true)
                await MainActor.run {
                    settingsSuccessMessage = "User deleted."
                    savingSettingsKey = nil
                }
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to delete the user."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func createCourt() {
        guard let organizationID = session?.organizationID else {
            return
        }

        savingSettingsKey = "court-create"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        Task {
            do {
                try await container.apiClient.createCourt(
                    organizationID: organizationID,
                    draft: newCourtDraft
                )
                await loadOrganizationSettingsIfNeeded(force: true)
                await MainActor.run {
                    newCourtDraft = CourtDraft()
                    settingsSuccessMessage = "Court created."
                    savingSettingsKey = nil
                }
                await loadDashboard()
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to create the court."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func updateCourt(_ court: CourtSummary) {
        guard let organizationID = session?.organizationID else {
            return
        }
        guard let draft = courtDrafts[court.id] else {
            return
        }

        savingSettingsKey = "court-save-\(court.id)"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        Task {
            do {
                try await container.apiClient.updateCourt(
                    organizationID: organizationID,
                    courtID: court.id,
                    draft: draft
                )
                await loadOrganizationSettingsIfNeeded(force: true)
                await MainActor.run {
                    settingsSuccessMessage = "Court updated."
                    savingSettingsKey = nil
                }
                await loadDashboard()
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to update the court."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func deleteCourt(_ court: CourtSummary) {
        guard let organizationID = session?.organizationID else {
            return
        }

        savingSettingsKey = "court-delete-\(court.id)"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        Task {
            do {
                try await container.apiClient.deleteCourt(
                    organizationID: organizationID,
                    courtID: court.id
                )
                await loadOrganizationSettingsIfNeeded(force: true)
                await MainActor.run {
                    settingsSuccessMessage = "Court deleted."
                    savingSettingsKey = nil
                }
                await loadDashboard()
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to delete the court."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func regenerateCourtDisplayCode(_ court: CourtSummary) {
        guard let organizationID = session?.organizationID else {
            return
        }

        savingSettingsKey = "court-code-\(court.id)"
        settingsErrorMessage = nil
        settingsSuccessMessage = nil

        Task {
            do {
                let settings = try await container.apiClient.createCourtDisplayCode(
                    organizationID: organizationID,
                    courtID: court.id
                )
                await MainActor.run {
                    organizationSettings = settings
                    syncSettingsDrafts(from: settings)
                    settingsSuccessMessage = "Display code updated."
                    savingSettingsKey = nil
                }
            } catch {
                await MainActor.run {
                    settingsErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to update the display code."
                    savingSettingsKey = nil
                }
            }
        }
    }

    private func startScheduledMatch(_ matchID: String) async {
        await MainActor.run {
            startingScheduledMatchID = matchID
            errorMessage = nil
        }

        do {
            let activatedMatch = try await container.apiClient.startScheduledMatch(matchID: matchID)
            await MainActor.run {
                startingScheduledMatchID = nil
                navigationTarget = MatchRoute(id: activatedMatch.id)
            }
            await loadDashboard()
        } catch {
            await MainActor.run {
                startingScheduledMatchID = nil
                errorMessage = (error as? APIErrorResponse)?.message ?? "Unable to start the scheduled match."
            }
        }
    }

    private func handleStartNewMatchResult(_ result: StartNewMatchResult) {
        activeSheet = nil
        Task { await loadDashboard() }

        switch result {
        case .openMatch(let matchID):
            dashboardNotice = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                navigationTarget = MatchRoute(id: matchID)
            }
        case .scheduled(let notice):
            dashboardNotice = notice ?? "Match saved as scheduled."
        }
    }

    private func submitFeedback() {
        let name = feedbackName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = feedbackEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let message = feedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else {
            feedbackErrorMessage = "Your name is required."
            feedbackSuccessMessage = nil
            return
        }

        guard isValidEmail(email) else {
            feedbackErrorMessage = "A valid email address is required."
            feedbackSuccessMessage = nil
            return
        }

        guard message.count >= 5 else {
            feedbackErrorMessage = "Please provide more detail."
            feedbackSuccessMessage = nil
            return
        }

        isSubmittingFeedback = true
        feedbackErrorMessage = nil
        feedbackSuccessMessage = nil

        Task {
            do {
                try await container.apiClient.submitFeedback(
                    name: name,
                    email: email,
                    category: feedbackCategory,
                    message: message,
                    username: session?.username ?? "",
                    organizationName: session?.organizationName ?? "",
                    version: "RcktScore iOS",
                    build: AppConfig.buildID,
                    pageURL: "ios-app://dashboard/help"
                )
                await MainActor.run {
                    feedbackSuccessMessage = "Thanks. Your message has been sent."
                    feedbackErrorMessage = nil
                    feedbackMessage = ""
                    isSubmittingFeedback = false
                }
            } catch {
                await MainActor.run {
                    feedbackErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to send your message."
                    feedbackSuccessMessage = nil
                    isSubmittingFeedback = false
                }
            }
        }
    }

    private func requestPasswordReset() {
        let email = resetEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidEmail(email) else {
            resetErrorMessage = "Enter a valid email address."
            resetMessage = nil
            return
        }

        isRequestingPasswordReset = true
        resetErrorMessage = nil
        resetMessage = nil

        Task {
            do {
                try await container.apiClient.requestPasswordReset(email: email)
                await MainActor.run {
                    resetMessage = "If that email is registered, a password reset link has been sent."
                    resetErrorMessage = nil
                    isRequestingPasswordReset = false
                }
            } catch {
                await MainActor.run {
                    resetErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to request password reset right now."
                    resetMessage = nil
                    isRequestingPasswordReset = false
                }
            }
        }
    }

    private func seedHelpDefaults() {
        if feedbackName.isEmpty {
            feedbackName = session?.fullName ?? session?.username ?? ""
        }
        if feedbackEmail.isEmpty {
            feedbackEmail = session?.email ?? ""
        }
        if resetEmail.isEmpty {
            resetEmail = session?.email ?? ""
        }
    }

    private func matchDisplayName(for match: MatchSummary) -> String {
        let player1 = [match.player1Name, match.player1Surname]
            .compactMap { value in
                guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return value
            }
            .joined(separator: " ")

        let player2 = [match.player2Name, match.player2Surname]
            .compactMap { value in
                guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return value
            }
            .joined(separator: " ")

        return "\(player1) vs \(player2)"
    }

    private func userDisplayName(_ user: OrganizationUser) -> String {
        let name = [user.firstName, user.surname]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return name.isEmpty ? user.username : name
    }

    private func historyWinnerLine(for match: MatchSummary) -> String {
        match.winnerName ?? match.state?.winnerName ?? "Completed match"
    }

    private func historyWinnerSide(for match: MatchSummary) -> Int? {
        let player1Games = match.state?.player1GamesWon ?? 0
        let player2Games = match.state?.player2GamesWon ?? 0

        if player1Games > player2Games {
            return 1
        }
        if player2Games > player1Games {
            return 2
        }

        let winnerName = historyWinnerLine(for: match).lowercased()
        if winnerName == match.player1Name.lowercased() {
            return 1
        }
        if winnerName == match.player2Name.lowercased() {
            return 2
        }

        return nil
    }

    private func historyScoreLine(for match: MatchSummary) -> String {
        let player1Games = match.state?.player1GamesWon ?? 0
        let player2Games = match.state?.player2GamesWon ?? 0
        let completedGameScores = (match.state?.gameHistory ?? [])
            .map { "\($0.player1Score)-\($0.player2Score)" }
            .joined(separator: " | ")
        let fallbackScore = "\(match.state?.player1Score ?? 0)-\(match.state?.player2Score ?? 0)"
        let scoreSeries = completedGameScores.isEmpty ? fallbackScore : completedGameScores
        return "\(player1Games)-\(player2Games) [\(scoreSeries)]"
    }

    private func historyFinalScoreLine(for match: MatchSummary) -> String {
        let player1Games = match.state?.player1GamesWon ?? 0
        let player2Games = match.state?.player2GamesWon ?? 0
        return "\(player1Games)-\(player2Games)"
    }

    private func currentScoreLine(for match: MatchSummary) -> String {
        let player1Score = match.state?.player1Score ?? 0
        let player2Score = match.state?.player2Score ?? 0
        return "\(player1Score) - \(player2Score)"
    }

    private func splitPlayerName(_ firstName: String, surname: String?) -> (firstName: String, surname: String) {
        ((firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Player" : firstName), surname ?? "")
    }

    private func formattedMatchDate(for match: MatchSummary) -> String {
        if let completedAt = match.completedAt, !completedAt.isEmpty {
            return formatDateOnly(completedAt)
        }
        if let updatedAt = match.updatedAt, !updatedAt.isEmpty {
            return formatDateOnly(updatedAt)
        }
        return "Unknown date"
    }

    private func recentPlayersLine(player1: String, player2: String, winnerSide: Int?) -> some View {
        let player1Color = winnerSide == 1 ? Color.dashboardAccentPink : Color.dashboardInk
        let player2Color = winnerSide == 2 ? Color.dashboardAccentPink : Color.dashboardInk

        return HStack(spacing: 0) {
            Text(player1)
                .foregroundStyle(player1Color)
            Text(" vs ")
                .foregroundStyle(Color.secondary)
            Text(player2)
                .foregroundStyle(player2Color)
        }
    }

    private func formatDateOnly(_ value: String) -> String {
        guard let date = parsedISODate(value) else {
            return value
        }

        return DateFormatter.dashboardDateOnly.string(from: date)
    }

    private func formatDate(_ value: String) -> String {
        guard let date = parsedISODate(value) else {
            return value
        }

        return DateFormatter.dashboardSummary.string(from: date)
    }

    private func parsedISODate(_ value: String) -> Date? {
        if let date = ISO8601DateFormatter.dashboardWithFractionalSeconds.date(from: value) {
            return date
        }

        return ISO8601DateFormatter.dashboardStandard.date(from: value)
    }

    private func isValidEmail(_ value: String) -> Bool {
        let emailPattern = "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"
        return value.range(of: emailPattern, options: .regularExpression) != nil
    }

    private func planDisplayName(for plan: String) -> String {
        switch plan.lowercased() {
        case "personal_plus":
            return "Personal+"
        case "personal_free":
            return "Personal Free"
        case "club_pro":
            return "Club Pro"
        case "club_essentials":
            return "Club Essentials"
        default:
            return plan.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

private struct MatchRoute: Hashable, Identifiable {
    let id: String
    var presentation: MatchPresentation = .live(openSettingsOnLoad: false)
}

private enum MatchPresentation: Hashable {
    case live(openSettingsOnLoad: Bool)
    case historic
}

private enum DashboardSheet: Identifiable {
    case newMatch

    var id: String {
        switch self {
        case .newMatch:
            return "new-match"
        }
    }
}

private enum DashboardTab: String, CaseIterable, Identifiable {
    case home
    case matches
    case history
    case settings
    case help

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .matches:
            return "Matches"
        case .history:
            return "History"
        case .settings:
            return "Settings"
        case .help:
            return "Need Help"
        }
    }

    var icon: String {
        switch self {
        case .home:
            return "house.fill"
        case .matches:
            return "calendar.badge.clock"
        case .history:
            return "clock"
        case .settings:
            return "gearshape"
        case .help:
            return "questionmark.circle"
        }
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case organization
    case users
    case courts
    case gameSettings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .organization:
            return "Organisation"
        case .users:
            return "Users"
        case .courts:
            return "Courts"
        case .gameSettings:
            return "Game Setup"
        }
    }
}

private extension DateFormatter {
    static let dashboardSummary: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let dashboardDateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private extension ISO8601DateFormatter {
    static let dashboardWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let dashboardStandard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private extension Color {
    static let dashboardBrand = Color(red: 18 / 255, green: 116 / 255, blue: 208 / 255)
    static let dashboardBrandDeep = Color(red: 15 / 255, green: 87 / 255, blue: 194 / 255)
    static let dashboardAccentPink = Color(red: 236 / 255, green: 94 / 255, blue: 168 / 255)
    static let dashboardInk = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.white
                : UIColor(red: 20 / 255, green: 31 / 255, blue: 45 / 255, alpha: 1)
        }
    )
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
    static let dashboardHeroBackground = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 20 / 255, green: 31 / 255, blue: 45 / 255, alpha: 1)
                : UIColor(red: 248 / 255, green: 251 / 255, blue: 255 / 255, alpha: 1)
        }
    )
    static let dashboardTabBarBackground = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 12 / 255, green: 20 / 255, blue: 29 / 255, alpha: 0.98)
                : UIColor.white.withAlphaComponent(0.98)
        }
    )
    static let dashboardTabMuted = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.systemGray3
                : UIColor(red: 76 / 255, green: 92 / 255, blue: 120 / 255, alpha: 1)
        }
    )
    static let dashboardCardBackground = Color(UIColor.secondarySystemGroupedBackground)
    static let dashboardInnerCardBackground = Color(UIColor.tertiarySystemGroupedBackground)
    static let dashboardInputBackground = Color(UIColor.systemBackground)
    static let dashboardMutedStatus = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.systemGray3
                : UIColor.systemGray2
        }
    )
    static let dashboardActiveStatus = Color(red: 82 / 255, green: 205 / 255, blue: 120 / 255)
    static let dashboardCompletedStatus = Color(red: 196 / 255, green: 68 / 255, blue: 92 / 255)
    static let dashboardBorder = Color(
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
