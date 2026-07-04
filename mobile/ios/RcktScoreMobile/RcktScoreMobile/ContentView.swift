import SwiftUI
import LocalAuthentication

struct ContentView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if container.sessionStore.isAuthenticated {
                if container.sessionStore.requiresBiometricUnlock {
                    biometricUnlockView
                } else {
                    DashboardView()
                }
            } else {
                LoginView()
            }
        }
        .task {
            if container.sessionStore.requiresBiometricUnlock {
                _ = await container.sessionStore.unlockWithBiometrics()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if container.sessionStore.requiresBiometricUnlock {
                    Task {
                        _ = await container.sessionStore.unlockWithBiometrics()
                    }
                }
            case .inactive, .background:
                container.sessionStore.lockForBackgroundIfNeeded()
            @unknown default:
                break
            }
        }
    }

    private var biometricUnlockView: some View {
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

            VStack(spacing: 18) {
                Image(systemName: container.sessionStore.biometricType == .faceID ? "faceid" : "touchid")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(Color.blue)

                Text("Unlock Hit n Score")
                    .font(.title2.weight(.bold))

                Text("Use \(container.sessionStore.biometricDisplayName) to reopen your saved session on this device.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                if let error = container.sessionStore.biometricErrorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button("Use \(container.sessionStore.biometricDisplayName)") {
                    Task {
                        _ = await container.sessionStore.unlockWithBiometrics()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Sign Out") {
                    Task { await container.logout() }
                }
                .buttonStyle(.bordered)
            }
            .padding(28)
            .frame(maxWidth: 420)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(24)
        }
    }
}
