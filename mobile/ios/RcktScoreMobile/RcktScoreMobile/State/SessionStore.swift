import Foundation
import Combine
import LocalAuthentication

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var session: UserSession?
    @Published private(set) var biometricUnlockEnabled = false
    @Published private(set) var requiresBiometricUnlock = false
    @Published private(set) var biometricType: LABiometryType = .none
    @Published private(set) var biometricErrorMessage: String?
    @Published private(set) var sessionExpiryMessage: String?

    private let key = "rcktscore.mobile.session"
    private let biometricPreferenceKey = "rcktscore.mobile.biometricUnlockEnabled"
    private let uiTestLaunchOptions: UITestLaunchOptions

    init(uiTestLaunchOptions: UITestLaunchOptions? = nil) {
        let resolvedLaunchOptions = uiTestLaunchOptions ?? .current
        self.uiTestLaunchOptions = resolvedLaunchOptions
        biometricUnlockEnabled = UserDefaults.standard.bool(forKey: biometricPreferenceKey)
        refreshBiometricAvailability()
        load()
        if session != nil, biometricUnlockEnabled, biometricType != .none {
            requiresBiometricUnlock = true
        }
    }

    var isAuthenticated: Bool {
        session != nil && session?.isExpired == false
    }

    var sessionToken: String? {
        session?.sessionToken
    }

    var canUseBiometricUnlock: Bool {
        biometricType != .none
    }

    var biometricDisplayName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "Biometric Login"
        }
    }

    func save(_ newSession: UserSession) {
        guard !newSession.isExpired else {
            clear(expired: true)
            return
        }
        session = newSession
        sessionExpiryMessage = nil
        if let encoded = try? JSONEncoder().encode(newSession) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
        if biometricUnlockEnabled, biometricType != .none {
            requiresBiometricUnlock = false
        }
    }

    func switchMembership(to membership: UserMembership) {
        guard let currentSession = session else {
            return
        }

        save(currentSession.switchingMembership(to: membership))
    }

    func clear(expired: Bool = false) {
        session = nil
        requiresBiometricUnlock = false
        biometricErrorMessage = nil
        UserDefaults.standard.removeObject(forKey: key)
        sessionExpiryMessage = expired ? "Your saved session has expired. Please sign in again." : nil
    }

    func validateExpiry() {
        guard session?.isExpired == true else {
            return
        }
        clear(expired: true)
    }

    func refreshBiometricAvailability() {
        if uiTestLaunchOptions.isEnabled {
            biometricType = .none
            biometricUnlockEnabled = false
            requiresBiometricUnlock = false
            biometricErrorMessage = nil
            UserDefaults.standard.set(false, forKey: biometricPreferenceKey)
            return
        }

        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        } else {
            biometricType = .none
            if biometricUnlockEnabled {
                biometricUnlockEnabled = false
                UserDefaults.standard.set(false, forKey: biometricPreferenceKey)
            }
        }
    }

    func enableBiometricUnlock() async throws {
        refreshBiometricAvailability()
        guard biometricType != .none else {
            throw BiometricAuthError.notAvailable
        }

        _ = try await authenticateWithBiometrics(reason: "Enable \(biometricDisplayName) for app unlock.")
        biometricUnlockEnabled = true
        biometricErrorMessage = nil
        UserDefaults.standard.set(true, forKey: biometricPreferenceKey)
    }

    func disableBiometricUnlock() {
        biometricUnlockEnabled = false
        requiresBiometricUnlock = false
        biometricErrorMessage = nil
        UserDefaults.standard.set(false, forKey: biometricPreferenceKey)
    }

    func lockForBackgroundIfNeeded() {
        guard biometricUnlockEnabled, session != nil, biometricType != .none else {
            return
        }

        requiresBiometricUnlock = true
    }

    @discardableResult
    func unlockWithBiometrics() async -> Bool {
        refreshBiometricAvailability()
        guard biometricUnlockEnabled, session != nil, biometricType != .none else {
            requiresBiometricUnlock = false
            biometricErrorMessage = nil
            return true
        }

        do {
            _ = try await authenticateWithBiometrics(reason: "Unlock Hit n Score.")
            requiresBiometricUnlock = false
            biometricErrorMessage = nil
            return true
        } catch {
            biometricErrorMessage = readableBiometricError(error)
            return false
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let stored = try? JSONDecoder().decode(UserSession.self, from: data) else {
            return
        }
        guard !stored.isExpired else {
            clear(expired: true)
            return
        }
        session = stored
    }

    private func authenticateWithBiometrics(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = ""

        return try await withCheckedThrowingContinuation { continuation in
            var authError: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
                continuation.resume(throwing: authError ?? BiometricAuthError.notAvailable)
                return
            }

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    private func readableBiometricError(_ error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == LAError.errorDomain,
              let code = LAError.Code(rawValue: nsError.code) else {
            return "Unable to verify biometrics right now."
        }

        switch code {
        case .userCancel, .systemCancel, .appCancel:
            return "Biometric unlock was cancelled."
        case .biometryLockout:
            return "\(biometricDisplayName) is locked. Unlock your device and try again."
        case .biometryNotAvailable, .biometryNotEnrolled:
            return "\(biometricDisplayName) is not available on this device."
        case .authenticationFailed:
            return "\(biometricDisplayName) did not recognise you."
        default:
            return "Unable to verify \(biometricDisplayName)."
        }
    }
}

private enum BiometricAuthError: LocalizedError {
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device."
        }
    }
}
