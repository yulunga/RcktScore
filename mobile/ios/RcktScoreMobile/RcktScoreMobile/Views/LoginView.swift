import SwiftUI
import Combine
import LocalAuthentication

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
    @Environment(\.openURL) private var openURL

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
    @State private var pastedResetLink = ""
    @State private var pastedResetLinkIsInvalid = false
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

            GeometryReader { geometry in
                let compactLandscape = geometry.size.width > geometry.size.height && geometry.size.height < 600
                let horizontalInset: CGFloat = compactLandscape ? 18 : 24
                let maximumCardWidth: CGFloat = compactLandscape ? 760 : 420
                let cardWidth = min(maximumCardWidth, max(0, geometry.size.width - (horizontalInset * 2)))
                VStack {
                    Spacer(minLength: compactLandscape ? 8 : 40)
                    loginCard(compactLandscape: compactLandscape, width: cardWidth)
                    Spacer(minLength: compactLandscape ? 8 : 0)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }

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

    @ViewBuilder
    private func loginCard(compactLandscape: Bool, width: CGFloat) -> some View {
        Group {
            if compactLandscape {
                HStack(spacing: 22) {
                    loginBranding(compact: true)
                        .frame(width: 160)
                    loginFormContent(compact: true)
                }
            } else {
                VStack(alignment: .leading, spacing: 22) {
                    loginBranding(compact: false)
                    loginFormContent(compact: false)
                }
            }
        }
        .padding(compactLandscape ? 18 : 24)
        .frame(width: width)
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

    private func loginBranding(compact: Bool) -> some View {
        VStack(alignment: .center, spacing: compact ? 6 : 12) {
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: compact ? 96 : 132, height: compact ? 96 : 132)

            hitnScoreWordmark(size: compact ? 24 : 30)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func loginFormContent(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 22) {
            loginFields(compact: compact)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("login.errorMessage")
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
                    compact ? "Connect to the internet to sign in." : "You are offline. Connect to the internet to sign in. Previously saved sessions can be reopened with Face ID or Touch ID until they expire.",
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

            loginLinks(compact: compact)
        }
    }

    private func hitnScoreWordmark(size: CGFloat) -> some View {
        (
            Text("Hit")
                .foregroundStyle(Color.loginBrandBlue)
            + Text("n")
                .foregroundStyle(Color.loginBrandPink)
            + Text("Score")
                .foregroundStyle(Color.loginBrandBlue)
        )
        .font(.system(size: size, weight: .heavy, design: .rounded))
        .accessibilityLabel("HitnScore")
    }

    private func loginFields(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 14) {
            styledField(title: "Username", compact: compact) {
                TextField("Enter username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($focusedField, equals: .username)
                    .accessibilityIdentifier("login.usernameField")
            }

            styledField(title: "Password", compact: compact) {
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

    private func loginLinks(compact: Bool) -> some View {
        HStack(spacing: 10) {
            Spacer()

            Button("Want In") {
                openRegisterInterest()
            }
            .buttonStyle(.plain)
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
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
            .lineLimit(1)
            .foregroundStyle(Color.loginBrandPink)
            .accessibilityIdentifier("login.needHelpButton")

            Spacer()
        }
        .padding(.top, compact ? 0 : 14)
    }

    @ViewBuilder
    private func styledField<Content: View>(title: String, compact: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
                .padding(.horizontal, 14)
                .padding(.vertical, compact ? 10 : 14)
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

            GeometryReader { geometry in
                if mode == .registerInterest || mode == .helpOptions || mode == .pingUs || mode == .passwordReset {
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
                        case .sessionConflict, .organizationSelection:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack {
                            switch mode {
                            case .registerInterest, .helpOptions, .pingUs, .passwordReset:
                                EmptyView()
                            case .sessionConflict:
                                sessionConflictCard
                            case .organizationSelection:
                                organizationSelectionCard
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 40)
                        .frame(minHeight: geometry.size.height, alignment: .top)
                    }
                }
            }
        }
    }

    private var registerInterestCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 9) {
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)

                hitnScoreWordmark(size: 24)

                Spacer(minLength: 8)

                Button {
                    closeRegisterInterestOverlay()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 34, height: 34)
                        .foregroundStyle(Color.loginAction)
                        .background(Color.loginAction.opacity(0.10))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isSubmittingInterest)
                .accessibilityLabel("Close")
            }

            if let interestMessage {
                submissionConfirmation(
                    title: interestUseType == "personal"
                        ? "Thank you for registering"
                        : "Thank you for your interest",
                    message: interestMessage
                ) {
                    closeRegisterInterestOverlay()
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to HitnScore racketsport app")
                        .font(.headline.weight(.bold))
                    Text("Create a account to start scoring")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                compactInterestField("First name", text: $interestFirstName, capitalization: .words)
                compactInterestField("Surname", text: $interestSurname, capitalization: .words)
                compactInterestField("Email address", text: $interestEmail, capitalization: .never, keyboard: .emailAddress)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Score for")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("App Use", selection: $interestUseType) {
                        Text("Personal").tag("personal")
                        Text("Club").tag("club")
                    }
                    .pickerStyle(.segmented)
                }

                if interestUseType == "club" {
                    compactInterestField("Club name", text: $interestClubName, capitalization: .words)
                }

                compactInterestField("Human check: \(interestHumanLeft) + \(interestHumanRight)", text: $interestHumanAnswer, capitalization: .never, keyboard: .numberPad)

                if let interestErrorMessage {
                    Text(interestErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                overlayPrimaryButton(
                    title: isSubmittingInterest ? "Creating..." : "Create Account",
                    showProgress: isSubmittingInterest
                ) {
                    submitRegisterInterest()
                }
                .disabled(isSubmittingInterest)
                .accessibilityIdentifier("login.registerInterest.createAccountButton")
            }
        }
        .padding(18)
        .frame(maxWidth: 420, alignment: .leading)
        .background(Color.loginCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.loginBorder, lineWidth: 1)
        )
    }

    private func compactInterestField(
        _ placeholder: String,
        text: Binding<String>,
        capitalization: TextInputAutocapitalization,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        TextField(placeholder, text: text)
            .textInputAutocapitalization(capitalization)
            .keyboardType(keyboard)
            .autocorrectionDisabled(true)
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
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

            overlaySecondaryButton("Guides") {
                openURL(URL(string: "https://app.hitnscore.com/help")!)
            }
            .accessibilityIdentifier("login.guidesButton")

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
        VStack(alignment: .leading, spacing: 12) {
            overlayHeader("Ping Us")

            if let feedbackSuccessMessage {
                submissionConfirmation(
                    title: "Thank you for contacting us",
                    message: feedbackSuccessMessage
                ) {
                    overlayMode = nil
                }
            } else {
                Text("Tell us what is working, what is broken, or what you want to improve.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                styledField(title: "Your name", compact: true) {
                    TextField("Your name", text: $feedbackName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)
                }

                styledField(title: "Your email", compact: true) {
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
                    .padding(.vertical, 10)
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
                        .frame(height: 92)
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

                overlayPrimaryButton(
                    title: isSubmittingFeedback ? "Sending..." : "Send",
                    showProgress: isSubmittingFeedback
                ) {
                    submitFeedback()
                }
                .disabled(isSubmittingFeedback)
            }
        }
        .padding(18)
        .frame(maxWidth: 400, alignment: .leading)
        .background(Color.loginCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.loginBorder, lineWidth: 1)
        )
    }

    private var passwordResetCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            overlayHeader("Password Reset")

            Text("Enter the email address used for your account. If it is registered, we will send a reset link.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            styledField(title: "Account email", compact: true) {
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

            overlayPrimaryButton(
                title: isRequestingPasswordReset ? "Sending..." : "Send Reset",
                showProgress: isRequestingPasswordReset
            ) {
                requestPasswordReset()
            }
            .disabled(isRequestingPasswordReset)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Already have the reset link?")
                    .font(.subheadline.weight(.semibold))

                styledField(title: "Paste link or token", compact: true) {
                    TextField("https://app.hitnscore.com/help?...", text: $pastedResetLink)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled(true)
                        .onChange(of: pastedResetLink) { pastedResetLinkIsInvalid = false }
                }

                if pastedResetLinkIsInvalid {
                    Text("Paste the complete HitnScore reset link, or its secure token.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button("Open Reset Link") {
                    pastedResetLinkIsInvalid = !container.openPasswordResetText(pastedResetLink)
                    if !pastedResetLinkIsInvalid {
                        overlayMode = nil
                        pastedResetLink = ""
                    }
                }
                .buttonStyle(.bordered)
                .disabled(pastedResetLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
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
                .accessibilityIdentifier("login.logoutOtherMobileSessionButton")
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
                    .accessibilityIdentifier(
                        "login.organizationMembership.\(membership.organizationID).\(membership.plan ?? membership.organizationType ?? "unknown")"
                    )
                    .accessibilityLabel(
                        "\(membership.organizationName), \(membership.plan.map { displayPlanName($0) } ?? displayPlanName(membership.organizationType == "personal" ? "personal_free" : "club_essentials"))"
                    )
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
        .accessibilityIdentifier("login.organizationSelectionCard")
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
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.loginAction)
                .frame(width: 44, height: 44)
                .background(Color.loginAction.opacity(0.12))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.loginAction.opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel("Close")
        .accessibilityIdentifier("login.overlayCloseButton")
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

    private func submissionConfirmation(
        title: String,
        message: String,
        closeAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.loginAction)
                .accessibilityHidden(true)

            Text(title)
                .font(.title3.weight(.bold))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            overlayPrimaryButton(title: "Close", action: closeAction)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            subscriptionProvider: membership.subscriptionProvider,
            subscriptionStatus: membership.subscriptionStatus,
            subscriptionExpiresAt: membership.subscriptionExpiresAt,
            subscriptionAutoRenewEnabled: membership.subscriptionAutoRenewEnabled,
            subscriptionLastRenewedAt: membership.subscriptionLastRenewedAt,
            availableMemberships: selection.memberships
        )

        container.sessionStore.save(chosenSession)
        pendingOrganizationSelection = nil
        overlayMode = nil
    }

    private func displayPlanName(_ plan: String) -> String {
        switch plan.lowercased() {
        case "personal_plus":
            return "Personal Plus"
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
                        ? "Your personal account has been created. We have sent a verification email to \(email). Open the link in the email to verify your address and set your password. You can then return to HitnScore and sign in."
                        : "Your Personal account has been created and we have received your club subscription interest. Use the email sent to \(email) to set your password. You will also find our controlled-release update in Messages after signing in."
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
                    feedbackSuccessMessage = "Your message has been sent successfully. We will review it and contact you at \(email) if a response is needed."
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
