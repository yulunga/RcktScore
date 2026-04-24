import SwiftUI

private enum HelpOverlayMode {
    case options
    case passwordReset
}

struct LoginView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var helpOverlayMode: HelpOverlayMode?
    @State private var resetEmail = ""
    @State private var resetMessage: String?
    @State private var resetErrorMessage: String?
    @State private var isRequestingPasswordReset = false

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
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                TextField("Enter username", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
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
                                Text("Password")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                SecureField("Enter password", text: $password)
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

                        HStack(spacing: 18) {
                            Button("register interest") {
                                openRegisterInterest()
                            }
                            .buttonStyle(.plain)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.loginAction)

                            Button("need help ?") {
                                openNeedHelp()
                            }
                            .buttonStyle(.plain)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.loginAction)

                            Spacer(minLength: 0)
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

            if let helpOverlayMode {
                helpOverlayBackdrop(for: helpOverlayMode)
            }
        }
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
        openMailLink(subject: "Register Interest")
    }

    private func openNeedHelp() {
        resetErrorMessage = nil
        resetMessage = nil
        helpOverlayMode = .options
    }

    private func openMailLink(subject: String) {
        let trimmedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        guard let url = URL(string: "mailto:hello@hitnscore.com?subject=\(trimmedSubject)") else {
            return
        }

        openURL(url)
    }

    @ViewBuilder
    private func helpOverlayBackdrop(for mode: HelpOverlayMode) -> some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isRequestingPasswordReset {
                        helpOverlayMode = nil
                    }
                }

            switch mode {
            case .options:
                helpOptionsCard
            case .passwordReset:
                passwordResetCard
            }
        }
    }

    private var helpOptionsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Need Help?")
                    .font(.title3.weight(.bold))
                Spacer()
                overlayCloseButton
            }

            Text("Choose an option below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                openMailLink(subject: "Ping Us")
                helpOverlayMode = nil
            } label: {
                Text("Ping Us")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.loginAction)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                resetEmail = username.contains("@") ? username : ""
                resetMessage = nil
                resetErrorMessage = nil
                helpOverlayMode = .passwordReset
            } label: {
                Text("Password Reset")
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
        .padding(24)
        .frame(maxWidth: 360, alignment: .leading)
        .background(Color.loginCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.loginBorder, lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    private var passwordResetCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Password Reset")
                    .font(.title3.weight(.bold))
                Spacer()
                overlayCloseButton
            }

            Text("Enter the email address used for your account. If it is registered, we will send a reset link.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Account email")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("you@club.com", text: $resetEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled(true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.loginBorder, lineWidth: 1)
                    )
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
                Button("Back") {
                    resetErrorMessage = nil
                    resetMessage = nil
                    helpOverlayMode = .options
                }
                .buttonStyle(.plain)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.loginAction.opacity(0.12))
                .foregroundStyle(Color.loginAction)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button {
                    requestPasswordReset()
                } label: {
                    Group {
                        if isRequestingPasswordReset {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Send Reset Email")
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
                .disabled(isRequestingPasswordReset || resetEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(isRequestingPasswordReset || resetEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.72 : 1)
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
        .padding(.horizontal, 24)
    }

    private var overlayCloseButton: some View {
        Button {
            if !isRequestingPasswordReset {
                helpOverlayMode = nil
            }
        } label: {
            Text("×")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.loginAction)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
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
