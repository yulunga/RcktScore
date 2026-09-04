import Foundation
import Combine
@preconcurrency import LocalAuthentication
import Security

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var session: UserSession?
    @Published private(set) var biometricUnlockEnabled = false
    @Published private(set) var requiresBiometricUnlock = false
    @Published private(set) var biometricType: LABiometryType = .none
    @Published private(set) var biometricErrorMessage: String?
    @Published private(set) var sessionExpiryMessage: String?
    @Published private(set) var hasSavedBiometricSession = false

    private let key = "rcktscore.mobile.session"
    private let biometricPreferenceKey = "rcktscore.mobile.biometricUnlockEnabled"
    private let biometricSessionAvailableKey = "rcktscore.mobile.biometricSessionAvailable"
    private let biometricTypeKey = "rcktscore.mobile.biometricType"
    private let biometricKeychainService = "rcktScore.RcktScoreMobile.biometric-session"
    private let biometricKeychainAccount = "saved-session"
    private let uiTestLaunchOptions: UITestLaunchOptions
    private var isAuthenticatingWithBiometrics = false
    private var allowsAutomaticBiometricSignIn = true

    init(uiTestLaunchOptions: UITestLaunchOptions? = nil) {
        let resolvedLaunchOptions = uiTestLaunchOptions ?? .current
        self.uiTestLaunchOptions = resolvedLaunchOptions
        biometricUnlockEnabled = UserDefaults.standard.bool(forKey: biometricPreferenceKey)
        hasSavedBiometricSession = UserDefaults.standard.bool(forKey: biometricSessionAvailableKey)
        refreshBiometricAvailability()
        load()
        if let session, biometricUnlockEnabled {
            // Migrate an opted-in session from builds that predate Keychain storage,
            // without replacing the protected item on every cold launch.
            if !hasSavedBiometricSession,
               (try? storeBiometricSession(session)) != nil {
                setBiometricSessionAvailable(true)
            }
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

    var canRestoreBiometricSession: Bool {
        biometricUnlockEnabled && hasSavedBiometricSession && biometricType != .none
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
        if biometricUnlockEnabled {
            if (try? storeBiometricSession(newSession)) != nil {
                setBiometricSessionAvailable(true)
            }
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
        removeSavedBiometricSession()
        sessionExpiryMessage = expired ? "Your saved session has expired. Please sign in again." : nil
    }

    /// Signs out of the visible app while retaining an opted-in, biometric-protected
    /// session. The backend token remains live until its normal expiry so the user can
    /// restore it with Face ID or Touch ID, including while offline.
    func signOutKeepingBiometricLogin() -> Bool {
        guard biometricUnlockEnabled,
              hasSavedBiometricSession,
              session?.isExpired == false else {
            return false
        }

        session = nil
        requiresBiometricUnlock = false
        biometricErrorMessage = nil
        sessionExpiryMessage = nil
        allowsAutomaticBiometricSignIn = false
        UserDefaults.standard.removeObject(forKey: key)
        return true
    }

    func takeAutomaticBiometricSignInRequest() -> Bool {
        guard allowsAutomaticBiometricSignIn, canRestoreBiometricSession else {
            return false
        }
        allowsAutomaticBiometricSignIn = false
        return true
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

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error),
           context.biometryType != .none {
            biometricType = context.biometryType
            UserDefaults.standard.set(context.biometryType.rawValue, forKey: biometricTypeKey)
        } else {
            // Lockout and transient system states must not silently disable an
            // already configured biometric login. Keep the last detected type so
            // the user can retry after unlocking the device.
            biometricType = LABiometryType(
                rawValue: UserDefaults.standard.integer(forKey: biometricTypeKey)
            ) ?? .none
        }
    }

    func enableBiometricUnlock() async throws {
        refreshBiometricAvailability()
        guard biometricType != .none else {
            throw BiometricAuthError.notAvailable
        }

        guard let session else {
            throw BiometricAuthError.noSavedSession
        }

        _ = try await authenticateWithBiometrics(reason: "Enable \(biometricDisplayName) for app unlock.")
        try storeBiometricSession(session)
        biometricUnlockEnabled = true
        setBiometricSessionAvailable(true)
        biometricErrorMessage = nil
        UserDefaults.standard.set(true, forKey: biometricPreferenceKey)
    }

    func disableBiometricUnlock() {
        biometricUnlockEnabled = false
        requiresBiometricUnlock = false
        biometricErrorMessage = nil
        UserDefaults.standard.set(false, forKey: biometricPreferenceKey)
        removeSavedBiometricSession()
    }

    func lockForBackgroundIfNeeded() {
        guard !isAuthenticatingWithBiometrics,
              biometricUnlockEnabled,
              session != nil else {
            return
        }

        requiresBiometricUnlock = true
    }

    @discardableResult
    func unlockWithBiometrics() async -> Bool {
        refreshBiometricAvailability()
        guard !isAuthenticatingWithBiometrics else {
            return false
        }
        guard biometricUnlockEnabled, session != nil else {
            return false
        }
        guard biometricType != .none else {
            biometricErrorMessage = "Biometric authentication is not available right now. Unlock your device and try again."
            return false
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

    @discardableResult
    func restoreSavedSessionWithBiometrics() async -> Bool {
        refreshBiometricAvailability()
        guard !isAuthenticatingWithBiometrics, canRestoreBiometricSession else {
            return false
        }

        do {
            let context = try await authenticateWithBiometrics(
                reason: "Sign in to Hit n Score with \(biometricDisplayName)."
            )
            let restoredSession = try loadBiometricSession(using: context)
            guard !restoredSession.isExpired else {
                clear(expired: true)
                return false
            }

            session = restoredSession
            requiresBiometricUnlock = false
            biometricErrorMessage = nil
            sessionExpiryMessage = nil
            if let encoded = try? JSONEncoder().encode(restoredSession) {
                UserDefaults.standard.set(encoded, forKey: key)
            }
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

    private func authenticateWithBiometrics(reason: String) async throws -> LAContext {
        guard !isAuthenticatingWithBiometrics else {
            throw BiometricAuthError.authenticationInProgress
        }

        isAuthenticatingWithBiometrics = true
        defer { isAuthenticatingWithBiometrics = false }

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
                if success {
                    continuation.resume(returning: context)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: BiometricAuthError.authenticationFailed)
                }
            }
        }
    }

    private func storeBiometricSession(_ session: UserSession) throws {
        let encoded = try JSONEncoder().encode(session)
        var accessError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &accessError
        ) else {
            throw accessError?.takeRetainedValue() ?? BiometricAuthError.keychainUnavailable
        }

        SecItemDelete(biometricKeychainBaseQuery as CFDictionary)
        var query = biometricKeychainBaseQuery
        query[kSecValueData as String] = encoded
        query[kSecAttrAccessControl as String] = accessControl
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainStatusError(status: status)
        }
    }

    private func loadBiometricSession(using context: LAContext) throws -> UserSession {
        var query = biometricKeychainBaseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                setBiometricSessionAvailable(false)
            }
            throw KeychainStatusError(status: status)
        }
        return try JSONDecoder().decode(UserSession.self, from: data)
    }

    private var biometricKeychainBaseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: biometricKeychainService,
            kSecAttrAccount as String: biometricKeychainAccount
        ]
    }

    private func removeSavedBiometricSession() {
        SecItemDelete(biometricKeychainBaseQuery as CFDictionary)
        setBiometricSessionAvailable(false)
    }

    private func setBiometricSessionAvailable(_ isAvailable: Bool) {
        hasSavedBiometricSession = isAvailable
        UserDefaults.standard.set(isAvailable, forKey: biometricSessionAvailableKey)
    }

    private func readableBiometricError(_ error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == LAError.errorDomain,
              let code = LAError.Code(rawValue: nsError.code) else {
            if let localizedError = error as? LocalizedError,
               let description = localizedError.errorDescription {
                return description
            }
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
    case authenticationInProgress
    case authenticationFailed
    case noSavedSession
    case keychainUnavailable

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device."
        case .authenticationInProgress:
            return "Biometric authentication is already in progress."
        case .authenticationFailed:
            return "Biometric authentication was not successful."
        case .noSavedSession:
            return "Sign in normally before enabling biometric login."
        case .keychainUnavailable:
            return "The secure saved session could not be created on this device."
        }
    }
}

private struct KeychainStatusError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return "The secure saved session could not be accessed: \(message)"
        }
        return "The secure saved session could not be accessed."
    }
}
