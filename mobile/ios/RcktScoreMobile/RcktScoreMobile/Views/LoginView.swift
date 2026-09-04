import SwiftUI
import Combine

private enum LoginOverlayMode: Equatable {
    case registerInterest
    case helpOptions
    case pingUs
    case passwordReset
    case sessionConflict
    case organizationSelection
}

private enum LoginFocusField: Hashable {
    case username
    case password
}

private let feedbackCategories = [
    "General Feedback",
    "Bug / Something not working",
    "Feature Request",
    "UI / Design Suggestion",
    "Performance Issue",
    "Other"
]

private let interestInactivityTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

struct LoginView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.colorScheme) private var colorScheme

    @State private var username = ""
    @State private var password = ""
    @State private var showsPassword = false
    @State private var isLoading = false
    @State private var isBiometricLoading = false
    @State private var errorMessage: String?
    @State private var overlayMode: LoginOverlayMode?
    @State private var sessionConflictMessage = ""
    @State private var pendingOrganizationSelection: OrganizationSelectionPayload?

    @State private var interestFirstName = ""
    @State private var interestSurname = ""
    @State private var interestEmail = ""
    @State private var interestUseType = "personal"
    @State private var interestClubName = ""
    @State private var interestHumanLeft = Int.random(in: 2...9)
    @State private var interestHumanRight = Int.random(in: 2...9)
    @State private var interestHumanAnswer = ""
    @State private var interestLastActivityAt = Date()
    @State private var interestMessage: String?
    @State private var interestErrorMessage: String?
    @State private var isSubmittingInterest = false

    @State private var feedbackName = ""
    @State private var feedbackEmail = ""
    @State private var feedbackCategory = feedbackCategories[0]
    @State private var feedbackMessage = ""
    @State private var feedbackSuccessMessage: String?
    @State private var feedbackErrorMessage: String?
    @State private var isSubmittingFeedback = false

    @State private var resetEmail = ""
    @State private var resetMessage: String?
    @State private var resetErrorMessage: String?
    @State private var isRequestingPasswordReset = false
    @FocusState private var focusedField: LoginFocusField?

    private var isOverlayBusy: Bool {
        isSubmittingInterest || isSubmittingFeedback || isRequestingPasswordReset
    }

    private var isOnline: Bool {
        container.networkMonitor.isOnline
    }

    var body: some View {
        ZStack {
            backgroundGradient

            VStack {
                Spacer(minLength: 40)

                loginCard

                Spacer()
            }
            .padding(24)

            if let overlayMode {
                overlayBackdrop(for: overlayMode)
            }
        }
        .onReceive(interestInactivityTimer) { _ in
            guard overlayMode == .registerInterest, !isSubmittingInterest else {
                return
            }

            if Date().timeIntervalSince(interestLastActivityAt) >= 30 {
                closeRegisterInterestOverlay()
            }
        }
        .onChange(of: interestFirstName) { trackInterestActivity() }
        .onChange(of: interestSurname) { trackInterestActivity() }
        .onChange(of: interestEmail) { trackInterestActivity() }
        .onChange(of: interestUseType) { trackInterestActivity() }
        .onChange(of: interestClubName) { trackInterestActivity() }
        .onChange(of: interestHumanAnswer) { trackInterestActivity() }
        .task {
            guard container.sessionStore.takeAutomaticBiometricSignInRequest() else {
                return
            }
            await biometricSignIn()
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.loginBackgroundStart,
                Color.loginBackgroundEnd
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            loginBranding
            loginFields

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            signInButton

            if container.sessionStore.canRestoreBiometricSession {
                biometricSignInButton
            }

            if let biometricError = container.sessionStore.biometricErrorMessage {
                Text(biometricError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("login.biometricErrorMessage")
            }

            if !isOnline {
                Label(
                    "You are offline. Connect to the internet to sign in. Previously saved sessions can be reopened with Face ID or Touch ID until they expire.",
                    systemImage: "wifi.slash"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("login.offlineMessage")
            } else if let sessionExpiryMessage = container.sessionStore.sessionExpiryMessage {
                Text(sessionExpiryMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("login.sessionExpiryMessage")
            }

            loginLinks
        }
        .padding(24)
        .frame(maxWidth: 420)
        .background(Color.loginCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.loginBorder, lineWidth: 1)
        )
        .shadow(
            color: colorScheme == .dark ? .clear : Color.black.opacity(0.08),
            radius: 24,
            x: 0,
            y: 14
        )
    }

    private var loginBranding: some View {
        VStack(alignment: .center, spacing: 12) {
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 132, height: 132)

            (
                Text("Hit ")
                    .foregroundStyle(Color.loginBrandBlue)
                + Text("n")
                    .foregroundStyle(Color.loginBrandPink)
                + Text(" Score")
                    .foregroundStyle(Color.loginBrandBlue)
            )
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .frame(maxWidth: .infinity)
        }
    }

    private var loginFields: some View {
        VStack(spacing: 14) {
            styledField(title: "Username") {
                TextField("Enter username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($focusedField, equals: .username)
                    .accessibilityIdentifier("login.usernameField")
            }

            styledField(title: "Password") {
                HStack(spacing: 10) {
                    Group {
                        if showsPassword {
                            TextField("Enter password", text: $password)
                        } else {
                            SecureField("Enter password", text: $password)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($focusedField, equals: .password)
                    .accessibilityIdentifier("login.passwordField")

                    Button {
                        togglePasswordVisibility()
                    } label: {
                        Image(systemName: showsPassword ? "eye.slash" : "eye")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showsPassword ? "Hide password" : "Show password")
                    .accessibilityIdentifier("login.passwordVisibilityButton")
                }
            }
        }
    }

    private var signInButton: some View {
        Button {
            submit()
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Sign in")
                        .font(.headline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.loginAction)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLoading || username.isEmpty || password.isEmpty || !isOnline)
        .opacity(isLoading || username.isEmpty || password.isEmpty || !isOnline ? 0.72 : 1)
        .accessibilityIdentifier("login.signInButton")
    }

    private var biometricSignInButton: some View {
        Button {
            Task {
                await biometricSignIn()
            }
        } label: {
            HStack(spacing: 10) {
                if isBiometricLoading {
                    ProgressView()
                        .tint(Color.loginAction)
                } else {
                    Image(systemName: container.sessionStore.biometricType == .faceID ? "faceid" : "touchid")
                }
                Text("Sign in with \(container.sessionStore.biometricDisplayName)")
                    .font(.headline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(Color.loginAction)
            .background(Color.loginAction.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.loginAction.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isBiometricLoading)
        .accessibilityIdentifier("login.biometricSignInButton")
    }

    @MainActor
    private func biometricSignIn() async {
        guard !isBiometricLoading else { return }
        isBiometricLoading = true
        _ = await container.sessionStore.restoreSavedSessionWithBiometrics()
        isBiometricLoading = false
    }

    private var loginLinks: some View {
        HStack(spacing: 10) {
            Spacer()

            Button("Want In") {
                openRegisterInterest()
            }
            .buttonStyle(.plain)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.loginAction)
            .accessibilityIdentifier("login.wantInButton")

            Text("|")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Button("Need Help") {
                openNeedHelp()
            }
            .buttonStyle(.plain)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.loginBrandPink)
            .accessibilityIdentifier("login.needHelpButton")

            Spacer()
        }
        .padding(.top, 14)
    }

    @ViewBuilder
    private func styledField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.loginBorder, lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func overlayBackdrop(for mode: LoginOverlayMode) -> some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isOverlayBusy && mode != .organizationSelection {
                        overlayMode = nil
                    }
                }

            ScrollView(showsIndicators: false) {
                VStack {
                    switch mode {
                    case .registerInterest:
                        registerInterestCard
                    case .helpOptions:
                        helpOptionsCard
                    case .pingUs:
                        pingUsCard
                    case .passwordReset:
                        passwordResetCard
                    case .sessionConflict:
                        sessionConflictCard
                    case .organizationSelection:
                        organizationSelectionCard
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }
        }
    }

    private var registerInterestCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            overlayHeader("Join Hit n Score")

            Text("Welcome to Hit n Score — the racket-sport scoring app.\n\nCreate a free personal account to start scoring matches. Registered users can access additional features, with the option to upgrade for more advanced tools.\n\nLooking for a multi-user account for a racket club? Club accounts are currently set up with our team. Register your interest and we’ll be in touch.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            styledField(title: "Name") {
                TextField("First name", text: $interestFirstName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
            }

            styledField(title: "Surname") {
                TextField("Surname", text: $interestSurname)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
            }

            styledField(title: "Email address") {
                TextField("you@email.com", text: $interestEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled(true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("App Use")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("App Use", selection: $interestUseType) {
                    Text("Personal").tag("personal")
                    Text("Club").tag("club")
                }
                .pickerStyle(.segmented)
            }

            if interestUseType == "club" {
                styledField(title: "Club name") {
                    TextField("Club name", text: $interestClubName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)
                }
            }

            styledField(title: "Human check: what is \(interestHumanLeft) + \(interestHumanRight)?") {
                TextField("Enter answer", text: $interestHumanAnswer)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled(true)
            }

            if let interestErrorMessage {
                Text(interestErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let interestMessage {
                Text(interestMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.loginAction)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                overlaySecondaryButton("Cancel") {
                    overlayMode = nil
                }
                .disabled(isSubmittingInterest)

                overlayPrimaryButton(
                    title: isSubmittingInterest
                        ? "Sending..."
                        : (interestUseType == "personal" ? "Create Personal Account" : "Register Club Interest"),
                    showProgress: isSubmittingInterest
                ) {
                    submitRegisterInterest()
                }
                .disabled(isSubmittingInterest)
            }
        }
        .padding(24)
        .frame(maxWidth: 380, alignment: .leading)
        .background(Color.loginCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.loginBorder, lineWidth: 1)
        )
    }

    private var helpOptionsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            overlayHeader("Need Help?")

            Text("Choose an option below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            overlayPrimaryButton(title: "Ping Us") {
                feedbackName = ""
                feedbackEmail = username.contains("@") ? username : ""
                feedbackCategory = feedbackCategories[0]
                feedbackMessage = ""
                feedbackSuccessMessage = nil
                feedbackErrorMessage = nil
                overlayMode = .pingUs
            }

            overlaySecondaryButton("Password Reset") {
                resetEmail = username.contains("@") ? username : ""
                resetErrorMessage = nil
                resetMessage = nil
                overlayMode = .passwordReset
            }
        }
        .padding(24)
        .frame(maxWidth: 360, alignment: .leading)
        .background(Color.loginCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.loginBorder, lineWidth: 1)
        )
    }

    private var pingUsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            overlayHeader("Ping Us")

            Text("Tell us what is working, what is broken, or what you want to improve.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            styledField(title: "Your name") {
                TextField("Your name", text: $feedbackName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
            }

            styledField(title: "Your email") {
                TextField("you@email.com", text: $feedbackEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled(true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Subject")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Subject", selection: $feedbackCategory) {
                    ForEach(feedbackCategories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.loginBorder, lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Tell us more")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextEditor(text: $feedbackMessage)
                    .frame(minHeight: 120)
                    .padding(10)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.loginBorder, lineWidth: 1)
                    )
            }

            if let feedbackErrorMessage {
                Text(feedbackErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let feedbackSuccessMessage {
                Text(feedbackSuccessMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.loginAction)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                overlaySecondaryButton("Back") {
                    overlayMode = .helpOptions
                }
                .disabled(isSubmittingFeedback)

                overlayPrimaryButton(
                    title: isSubmittingFeedback ? "Sending..." : "Send",
                    showProgress: isSubmittingFeedback
                ) {
                    submitFeedback()
                }
                .disabled(isSubmittingFeedback)
            }
        }
        .padding(24)
        .frame(maxWidth: 380, alignment: .leading)
        .background(Color.loginCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.loginBorder, lineWidth: 1)
        )
    }

    private var passwordResetCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            overlayHeader("Password Reset")

            Text("Enter the email address used for your account. If it is registered, we will send a reset link.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            styledField(title: "Account email") {
                TextField("you@club.com", text: $resetEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled(true)
            }

            if let resetErrorMessage {
                Text(resetErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let resetMessage {
                Text(resetMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.loginAction)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                overlaySecondaryButton("Back") {
                    overlayMode = .helpOptions
                }
                .disabled(isRequestingPasswordReset)

                overlayPrimaryButton(
                    title: isRequestingPasswordReset ? "Sending..." : "Send Reset Email",
                    showProgress: isRequestingPasswordReset
                ) {
                    requestPasswordReset()
                }
                .disabled(isRequestingPasswordReset)
            }
        }
        .padding(24)
        .frame(maxWidth: 380, alignment: .leading)
        .background(Color.loginCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.loginBorder, lineWidth: 1)
        )
    }

    private var sessionConflictCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            overlayHeader("Already Signed In")

            Text(sessionConflictMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                overlaySecondaryButton("Cancel") {
                    overlayMode = nil
                }
                .disabled(isLoading)

                overlayPrimaryButton(title: isLoading ? "Signing in..." : "Log Out Other Mobile Session", showProgress: isLoading) {
                    submit(forceLogoutOther: true)
                }
                .disabled(isLoading)
            }
        }
        .padding(24)
        .frame(maxWidth: 380, alignment: .leading)
        .background(Color.loginCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.loginBorder, lineWidth: 1)
        )
    }

    private var organizationSelectionCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            overlayHeader("Choose Account")

            Text("This email is linked to more than one club or account. Choose where you want to sign in.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(pendingOrganizationSelection?.memberships ?? []) { membership in
                    Button {
                        completeOrganizationSelection(membership)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(membership.organizationName)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Text(membership.plan.map { displayPlanName($0) } ?? displayPlanName(membership.organizationType == "personal" ? "personal_free" : "club_essentials"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 12)

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.loginAction)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.loginBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: 420)
        .background(Color.loginCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.loginBorder, lineWidth: 1)
        )
    }

    private func overlayHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.title3.weight(.bold))
            Spacer()
            overlayCloseButton
        }
    }

    private var overlayCloseButton: some View {
        Button {
            if !isOverlayBusy {
                overlayMode = nil
            }
        } label: {
            Text("×")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.loginAction)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }

    private func overlayPrimaryButton(title: String, showProgress: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if showProgress {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.headline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.loginAction)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func overlaySecondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.loginAction.opacity(0.12))
                .foregroundStyle(Color.loginAction)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.loginAction.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func togglePasswordVisibility() {
        let shouldRestorePasswordFocus = focusedField == .password
        focusedField = nil
        showsPassword.toggle()

        guard shouldRestorePasswordFocus else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focusedField = .password
        }
    }

    private func submit(forceLogoutOther: Bool = false) {
        guard isOnline else {
            errorMessage = "Connect to the internet to sign in."
            return
        }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await container.apiClient.login(
                    username: username,
                    password: password,
                    forceLogoutOther: forceLogoutOther
                )
                await MainActor.run {
                    switch result {
                    case .session(let session):
                        container.sessionStore.save(session)
                        overlayMode = nil
                    case .organizationSelection(let selection):
                        pendingOrganizationSelection = selection
                        overlayMode = .organizationSelection
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    if let apiError = error as? APIErrorResponse, apiError.code == "ACTIVE_SESSION_EXISTS" {
                        sessionConflictMessage = apiError.message
                        overlayMode = .sessionConflict
                        errorMessage = nil
                    } else {
                        errorMessage = (error as? APIErrorResponse)?.message ?? "Unable to sign in."
                    }
                    isLoading = false
                }
            }
        }
    }

    private func completeOrganizationSelection(_ membership: UserMembership) {
        guard let selection = pendingOrganizationSelection else {
            return
        }

        let chosenSession = UserSession(
            id: membership.id,
            username: membership.username,
            role: membership.role,
            sessionToken: selection.sessionToken,
            sessionExpiresAt: selection.sessionExpiresAt,
            organizationID: membership.organizationID,
            organizationName: membership.organizationName,
            organizationType: membership.organizationType,
            plan: membership.plan,
            enabledSports: membership.enabledSports,
            firstName: membership.firstName,
            surname: membership.surname,
            fullName: membership.fullName,
            email: membership.email,
            country: membership.country,
            telephone: membership.telephone,
            availableMemberships: selection.memberships
        )

        container.sessionStore.save(chosenSession)
        pendingOrganizationSelection = nil
        overlayMode = nil
    }

    private func displayPlanName(_ plan: String) -> String {
        switch plan.lowercased() {
        case "personal_plus":
            return "Personal+"
        case "personal_free":
            return "Personal"
        case "club_pro":
            return "Club Pro"
        case "club_essentials":
            return "Club Essentials"
        default:
            return plan.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func openRegisterInterest() {
        interestFirstName = ""
        interestSurname = ""
        interestEmail = username.contains("@") ? username : ""
        interestUseType = "personal"
        interestClubName = ""
        refreshInterestHumanCheck()
        interestHumanAnswer = ""
        interestLastActivityAt = Date()
        interestMessage = nil
        interestErrorMessage = nil
        overlayMode = .registerInterest
    }

    private func openNeedHelp() {
        resetErrorMessage = nil
        resetMessage = nil
        feedbackSuccessMessage = nil
        feedbackErrorMessage = nil
        overlayMode = .helpOptions
    }

    private func submitRegisterInterest() {
        let email = interestEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let firstName = interestFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let surname = interestSurname.trimmingCharacters(in: .whitespacesAndNewlines)
        let clubName = interestClubName.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedUseType = interestUseType

        guard !firstName.isEmpty else {
            interestErrorMessage = "Name is required."
            interestMessage = nil
            return
        }

        guard !surname.isEmpty else {
            interestErrorMessage = "Surname is required."
            interestMessage = nil
            return
        }

        guard isValidEmail(email) else {
            interestErrorMessage = "A valid email address is required."
            interestMessage = nil
            return
        }

        if requestedUseType == "club" && clubName.isEmpty {
            interestErrorMessage = "Club name is required for club use."
            interestMessage = nil
            return
        }

        guard interestHumanAnswer.trimmingCharacters(in: .whitespacesAndNewlines) == String(interestHumanLeft + interestHumanRight) else {
            interestErrorMessage = "Human check answer is incorrect."
            interestMessage = nil
            refreshInterestHumanCheck()
            interestHumanAnswer = ""
            return
        }

        isSubmittingInterest = true
        interestErrorMessage = nil
        interestMessage = nil

        Task {
            do {
                try await container.apiClient.registerInterest(
                    firstName: firstName,
                    surname: surname,
                    email: email,
                    useType: requestedUseType,
                    clubName: clubName
                )
                await MainActor.run {
                    interestMessage = requestedUseType == "personal"
                        ? "Your personal account has been created. Check your email to verify your address and choose your password."
                        : "Thanks. We have received your club enquiry and will be in touch."
                    interestErrorMessage = nil
                    isSubmittingInterest = false
                }
            } catch {
                await MainActor.run {
                    interestErrorMessage = (error as? APIErrorResponse)?.message
                        ?? (requestedUseType == "personal"
                            ? "Unable to create your personal account right now."
                            : "Unable to submit your club enquiry right now.")
                    interestMessage = nil
                    isSubmittingInterest = false
                }
            }
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
                    version: "RcktScore iOS",
                    build: AppConfig.buildID
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
                    resetEmail = ""
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

    private func isValidEmail(_ value: String) -> Bool {
        let emailPattern = "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"
        return value.range(of: emailPattern, options: .regularExpression) != nil
    }

    private func trackInterestActivity() {
        guard overlayMode == .registerInterest else {
            return
        }

        interestLastActivityAt = Date()
    }

    private func refreshInterestHumanCheck() {
        interestHumanLeft = Int.random(in: 2...9)
        interestHumanRight = Int.random(in: 2...9)
    }

    private func closeRegisterInterestOverlay() {
        interestMessage = nil
        interestErrorMessage = nil
        overlayMode = nil
    }
}

private extension Color {
    static let loginAction = Color(red: 18 / 255, green: 116 / 255, blue: 208 / 255)
    static let loginBrandBlue = Color(red: 11 / 255, green: 95 / 255, blue: 179 / 255)
    static let loginBrandPink = Color(red: 236 / 255, green: 94 / 255, blue: 168 / 255)
    static let loginBackgroundStart = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 18 / 255, green: 26 / 255, blue: 38 / 255, alpha: 1)
                : UIColor(red: 233 / 255, green: 242 / 255, blue: 250 / 255, alpha: 1)
        }
    )
    static let loginBackgroundEnd = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 11 / 255, green: 18 / 255, blue: 27 / 255, alpha: 1)
                : UIColor(red: 245 / 255, green: 248 / 255, blue: 252 / 255, alpha: 1)
        }
    )
    static let loginCardBackground = Color(UIColor.secondarySystemGroupedBackground)
    static let loginBorder = Color(
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
