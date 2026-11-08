import SwiftUI

struct PasswordSetupView: View {
    private enum Stage {
        case checking
        case ready
        case invalid
        case done
    }

    @EnvironmentObject private var container: AppContainer
    @Environment(\.colorScheme) private var colorScheme
    let link: PasswordResetLink

    @State private var stage: Stage = .checking
    @State private var password = ""
    @State private var confirmation = ""
    @State private var showsPassword = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var canRetryCheck = false

    private var unmetRules: Set<PasswordRule> {
        HitnScorePasswordPolicy.unmetRules(for: password)
    }

    private var confirmationMatches: Bool {
        !confirmation.isEmpty && confirmation == password
    }

    private var canSave: Bool {
        stage == .ready && !isSaving && unmetRules.isEmpty && confirmationMatches
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 236 / 255, green: 243 / 255, blue: 252 / 255),
                    Color(red: 246 / 255, green: 248 / 255, blue: 252 / 255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        Button {
                            container.closePasswordReset()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .bold))
                                .frame(width: 42, height: 42)
                                .background(.thinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                        .accessibilityLabel("Close")
                    }

                    Image("BrandLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)

                    brandWordmark

                    VStack(alignment: .leading, spacing: 16) {
                        stageContent
                    }
                    .padding(24)
                    .frame(maxWidth: 420, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.blue.opacity(colorScheme == .dark ? 0.3 : 0.16), lineWidth: 1)
                    )
                    .shadow(
                        color: colorScheme == .dark ? .clear : Color.black.opacity(0.08),
                        radius: 20,
                        x: 0,
                        y: 12
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .interactiveDismissDisabled(isSaving)
        .task(id: link.id) {
            await checkLink()
        }
    }

    @ViewBuilder
    private var stageContent: some View {
        switch stage {
        case .checking:
            HStack(spacing: 14) {
                ProgressView()
                Text("Checking your secure link...")
                    .font(.body.weight(.medium))
            }

        case .invalid:
            Text("This link cannot be used")
                .font(.title2.bold())
            Text(errorMessage ?? "The link is invalid, has expired or has already been used.")
                .font(.body)
                .foregroundStyle(Color(red: 217 / 255, green: 37 / 255, blue: 103 / 255))
            Text("Request a new password reset email, then open its most recent link.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if canRetryCheck {
                Button("Retry") {
                    Task { await checkLink() }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
            primaryButton("Back to Sign In") {
                container.closePasswordReset()
            }

        case .ready:
            passwordForm

        case .done:
            Text(link.isAccountSetup ? "Your account is ready" : "Password changed")
                .font(.title2.bold())
            Text(
                link.isAccountSetup
                    ? "Your email has been confirmed and your password has been created. You can now sign in."
                    : "Your new password has been saved and your previous sessions have been signed out."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            primaryButton("Go to Sign In") {
                container.closePasswordReset()
            }
            .accessibilityIdentifier("passwordSetup.signInButton")
        }
    }

    private var passwordForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(link.isAccountSetup ? "Create your password" : "Choose a new password")
                .font(.title2.bold())

            Text(
                link.isAccountSetup
                    ? "Create a secure password to finish setting up your HitnScore account."
                    : "Enter a secure new password for your HitnScore account."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            passwordField(title: "New password", text: $password)
                .accessibilityIdentifier("passwordSetup.newPasswordField")
            passwordField(title: "Confirm password", text: $confirmation)
                .accessibilityIdentifier("passwordSetup.confirmPasswordField")

            if !confirmation.isEmpty && !confirmationMatches {
                Text("Passwords do not match.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(PasswordRule.allCases, id: \.self) { rule in
                    let isMet = !unmetRules.contains(rule)
                    HStack(spacing: 10) {
                        Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isMet ? Color.green : (password.isEmpty ? Color.secondary : Color.red))
                        Text(rule.label)
                            .font(.subheadline)
                            .foregroundStyle(isMet ? Color.primary : Color.secondary)
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
            }

            primaryButton(
                isSaving
                    ? "Saving..."
                    : (link.isAccountSetup ? "Create Password" : "Save New Password"),
                showsProgress: isSaving
            ) {
                Task { await savePassword() }
            }
            .disabled(!canSave)
            .accessibilityIdentifier("passwordSetup.saveButton")
        }
    }

    private func passwordField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Group {
                    if showsPassword {
                        TextField(title, text: text)
                    } else {
                        SecureField(title, text: text)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)

                Button {
                    showsPassword.toggle()
                } label: {
                    Image(systemName: showsPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showsPassword ? "Hide password" : "Show password")
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.blue.opacity(0.24), lineWidth: 1)
            )
        }
    }

    private func primaryButton(
        _ title: String,
        showsProgress: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if showsProgress {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(Color(red: 11 / 255, green: 95 / 255, blue: 179 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var brandWordmark: some View {
        (
            Text("Hit ").foregroundStyle(Color(red: 11 / 255, green: 95 / 255, blue: 179 / 255))
            + Text("n").foregroundStyle(Color(red: 217 / 255, green: 37 / 255, blue: 103 / 255))
            + Text(" Score").foregroundStyle(Color(red: 11 / 255, green: 95 / 255, blue: 179 / 255))
        )
        .font(.system(size: 28, weight: .heavy, design: .rounded))
    }

    @MainActor
    private func checkLink() async {
        stage = .checking
        errorMessage = nil
        canRetryCheck = false
        do {
            let valid = try await container.apiClient.validatePasswordResetToken(link.token)
            stage = valid ? .ready : .invalid
        } catch {
            errorMessage = (error as? APIErrorResponse)?.message ?? "Unable to check the link. Check your connection and try again."
            canRetryCheck = (error as? APIErrorResponse) == nil
            stage = .invalid
        }
    }

    @MainActor
    private func savePassword() async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        do {
            try await container.apiClient.confirmPasswordReset(token: link.token, password: password)
            password = ""
            confirmation = ""
            isSaving = false
            container.passwordResetCompleted(isAccountSetup: link.isAccountSetup)
            stage = .done
        } catch {
            errorMessage = (error as? APIErrorResponse)?.message ?? "Unable to save the password. Please try again."
            isSaving = false
        }
    }
}
