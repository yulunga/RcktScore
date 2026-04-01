import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.colorScheme) private var colorScheme

    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

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

                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BETA")
                            .font(.caption2.weight(.black))
                            .tracking(1.2)
                            .foregroundStyle(Color.loginAction)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.loginAction.opacity(colorScheme == .dark ? 0.2 : 0.12))
                            .clipShape(Capsule())

                        Text("PointPal")
                            .font(.largeTitle.weight(.heavy))
                            .foregroundStyle(.primary)

                        Text("Live squash scoring for clubs, referees, and match operators.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
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

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Organisation login")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.loginAction)
                        Text("Use your PointPal organisation credentials to continue.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

                Spacer()
            }
            .padding(24)
        }
    }

    private func submit() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let session = try await container.apiClient.login(username: username, password: password)
                container.sessionStore.save(session)
            } catch {
                errorMessage = (error as? APIErrorResponse)?.message ?? "Unable to sign in."
            }
            isLoading = false
        }
    }
}

private extension Color {
    static let loginAction = Color(red: 18 / 255, green: 116 / 255, blue: 208 / 255)
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
