import SwiftUI

private enum LoginOverlayMode {
    case registerInterest
    case helpOptions
    case pingUs
    case passwordReset
}

private let feedbackCategories = [
    "General Feedback",
    "Bug / Something not working",
    "Feature Request",
    "UI / Design Suggestion",
    "Performance Issue",
    "Other"
]

struct LoginView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.colorScheme) private var colorScheme

    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var overlayMode: LoginOverlayMode?

    @State private var interestFirstName = ""
    @State private var interestSurname = ""
    @State private var interestEmail = ""
    @State private var interestUseType = "personal"
    @State private var interestClubName = ""
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

    private var isOverlayBusy: Bool {
        isSubmittingInterest || isSubmittingFeedback || isRequestingPasswordReset
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.loginBackgroundStart,
                    Color.loginBackgroundEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                Spacer(minLength: 40)

                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .leading, spacing: 22) {
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

                        VStack(spacing: 14) {
                            styledField(title: "Username") {
                                TextField("Enter username", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                            }

                            styledField(title: "Password") {
                                SecureField("Enter password", text: $password)
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: submit) {
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
                        .disabled(isLoading || username.isEmpty || password.isEmpty)
                        .opacity(isLoading || username.isEmpty || password.isEmpty ? 0.72 : 1)

                        VStack(spacing: 10) {
                            HStack {
                                Spacer()

                                Button("Let me in") {
                                    openRegisterInterest()
                                }
                                .buttonStyle(.plain)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.loginAction)
                            }

                            HStack {
                                Spacer()

                                Button("Need help ?") {
                                    openNeedHelp()
                                }
                                .buttonStyle(.plain)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.loginBrandPink)

                                Spacer()
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
                    .shadow(
                        color: colorScheme == .dark ? .clear : Color.black.opacity(0.08),
                        radius: 24,
                        x: 0,
                        y: 14
                    )

                    Text("BETA")
                        .font(.caption2.weight(.black))
                        .tracking(1.2)
                        .foregroundStyle(Color.loginBetaText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.loginBetaBackground)
                        .overlay(
                            Capsule()
                                .stroke(Color.loginBetaBorder, lineWidth: 1)
                        )
                        .clipShape(Capsule())
                        .offset(x: 10, y: -12)
                }

                Spacer()
            }
            .padding(24)

            if let overlayMode {
                overlayBackdrop(for: overlayMode)
            }
        }
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
                    if !isOverlayBusy {
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
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }
        }
    }

    private var registerInterestCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            overlayHeader("Let me in")

            Text("Request early access by submitting your details. Approved users will be added to the root admin approval queue.")
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
                    title: isSubmittingInterest ? "Sending..." : "Send Register Interest",
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

    private func submit() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let session = try await container.apiClient.login(username: username, password: password)
                await MainActor.run {
                    container.sessionStore.save(session)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIErrorResponse)?.message ?? "Unable to sign in."
                    isLoading = false
                }
            }
        }
    }

    private func openRegisterInterest() {
        interestFirstName = ""
        interestSurname = ""
        interestEmail = username.contains("@") ? username : ""
        interestUseType = "personal"
        interestClubName = ""
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

        if interestUseType == "club" && clubName.isEmpty {
            interestErrorMessage = "Club name is required for club use."
            interestMessage = nil
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
                    useType: interestUseType,
                    clubName: clubName
                )
                await MainActor.run {
                    interestMessage = "Thanks. We have recorded your interest and will be in touch."
                    interestErrorMessage = nil
                    isSubmittingInterest = false
                }
            } catch {
                await MainActor.run {
                    interestErrorMessage = (error as? APIErrorResponse)?.message ?? "Unable to submit your interest right now."
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
}

private extension Color {
    static let loginAction = Color(red: 18 / 255, green: 116 / 255, blue: 208 / 255)
    static let loginBrandBlue = Color(red: 11 / 255, green: 95 / 255, blue: 179 / 255)
    static let loginBrandPink = Color(red: 236 / 255, green: 94 / 255, blue: 168 / 255)
    static let loginBetaBackground = Color(red: 1, green: 243 / 255, blue: 196 / 255)
    static let loginBetaText = Color(red: 138 / 255, green: 91 / 255, blue: 0)
    static let loginBetaBorder = Color(red: 153 / 255, green: 102 / 255, blue: 0).opacity(0.18)
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
