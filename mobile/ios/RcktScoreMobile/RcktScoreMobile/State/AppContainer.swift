import Foundation
import Combine

@MainActor
final class AppContainer: ObservableObject {
    @Published private(set) var pendingPasswordResetLink: PasswordResetLink?
    let apiClient: APIClient
    let sessionStore: SessionStore
    let networkMonitor: NetworkMonitor
    let offlineMatchStore: OfflineMatchStore
    let purchaseService: StoreKitPurchaseService
    let uiTestLaunchOptions: UITestLaunchOptions
    private var cancellables = Set<AnyCancellable>()
    private var sessionValidationTask: Task<Void, Never>?

    init(
        apiClient: APIClient? = nil,
        sessionStore: SessionStore? = nil,
        networkMonitor: NetworkMonitor? = nil,
        offlineMatchStore: OfflineMatchStore? = nil,
        purchaseService: StoreKitPurchaseService? = nil,
        uiTestLaunchOptions: UITestLaunchOptions? = nil
    ) {
        let resolvedLaunchOptions = uiTestLaunchOptions ?? .current
        self.uiTestLaunchOptions = resolvedLaunchOptions
        self.apiClient = apiClient ?? APIClient()
        self.sessionStore = sessionStore ?? SessionStore(uiTestLaunchOptions: resolvedLaunchOptions)
        self.networkMonitor = networkMonitor ?? NetworkMonitor(
            forcedOnlineState: resolvedLaunchOptions.runsRacketServiceSideScenario ? false : nil
        )
        self.offlineMatchStore = offlineMatchStore ?? OfflineMatchStore()
        self.purchaseService = purchaseService ?? StoreKitPurchaseService()
        self.purchaseService.configure(
            apiClient: self.apiClient,
            organizationIDProvider: { [weak sessionStore = self.sessionStore] in
                sessionStore?.session?.organizationID
            }
        )
        self.apiClient.setSessionToken(self.sessionStore.sessionToken)
        self.apiClient.onSessionInvalidated = { [weak self] code in
            self?.sessionStore.clear(expired: code == "SESSION_EXPIRED")
        }

        self.sessionStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        self.sessionStore.$session
            .sink { [weak self] session in
                self?.apiClient.setSessionToken(session?.sessionToken)
                self?.purchaseService.accountDidChange()

            }
            .store(in: &cancellables)

        self.sessionStore.$session
            .map { $0?.sessionToken }
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.restartSessionValidation()
            }
            .store(in: &cancellables)

        self.networkMonitor.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        self.offlineMatchStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        self.purchaseService.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        self.networkMonitor.$isOnline
            .removeDuplicates()
            .sink { [weak self] isOnline in
                guard isOnline, let self else { return }
                Task { @MainActor in
                    await self.offlineMatchStore.sync(
                        using: self.apiClient,
                        session: self.sessionStore.session
                    )
                }
            }
            .store(in: &cancellables)

        self.sessionStore.$session
            .compactMap { $0 }
            .sink { [weak self] session in
                guard let self, self.networkMonitor.isOnline else { return }
                Task { @MainActor in
                    await self.offlineMatchStore.sync(using: self.apiClient, session: session)
                }
            }
            .store(in: &cancellables)

        if resolvedLaunchOptions.runsRacketServiceSideScenario {
            let fixture = RacketServiceSideUITestFixture.make()
            self.sessionStore.save(fixture.session)
            self.offlineMatchStore.cache(fixture.match, session: fixture.session)
        }
    }

    func logout() {
        if sessionStore.signOutKeepingBiometricLogin() {
            return
        }

        let sessionToken = sessionStore.sessionToken
        sessionStore.clear()
        Task {
            await apiClient.logout(sessionTokenOverride: sessionToken)
        }
    }

    @discardableResult
    func handleIncomingURL(_ url: URL) -> Bool {
        guard let link = PasswordResetLink.parse(url: url) else {
            return false
        }
        pendingPasswordResetLink = link
        return true
    }

    @discardableResult
    func openPasswordResetText(_ text: String) -> Bool {
        guard let link = PasswordResetLink.parse(text: text) else {
            return false
        }
        pendingPasswordResetLink = link
        return true
    }

    func closePasswordReset() {
        pendingPasswordResetLink = nil
    }

    func passwordResetCompleted(isAccountSetup: Bool) {
        if !isAccountSetup {
            // The backend revokes every session for this identity after a reset.
            // Remove the device's normal and biometric copies immediately too.
            sessionStore.clear()
        }
    }

    private func restartSessionValidation() {
        sessionValidationTask?.cancel()
        guard !uiTestLaunchOptions.isEnabled else {
            sessionValidationTask = nil
            return
        }

        sessionValidationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                guard let token = self.sessionStore.session?.sessionToken else { return }
                if self.networkMonitor.isOnline,
                   let snapshot = try? await self.apiClient.validateSession(),
                   !Task.isCancelled,
                   let current = self.sessionStore.session,
                   current.sessionToken == token,
                   let memberships = snapshot.availableMemberships,
                   let selected = memberships.first(where: { $0.organizationID == current.organizationID }) ?? memberships.first {
                    let updated = current.switchingMembership(to: selected, refreshedMemberships: memberships)
                    if updated != current { self.sessionStore.save(updated) }
                }
                // Membership roles, plan and sport access can be changed by a
                // club/root administrator while this device remains signed in.
                // Reconcile promptly; every protected request is still
                // authorised independently by the backend.
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }
}
