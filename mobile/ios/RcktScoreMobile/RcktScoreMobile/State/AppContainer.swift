import Foundation
import Combine

@MainActor
final class AppContainer: ObservableObject {
    let apiClient: APIClient
    let sessionStore: SessionStore
    let networkMonitor: NetworkMonitor
    let offlineMatchStore: OfflineMatchStore
    let uiTestLaunchOptions: UITestLaunchOptions
    private var cancellables = Set<AnyCancellable>()

    init(
        apiClient: APIClient? = nil,
        sessionStore: SessionStore? = nil,
        networkMonitor: NetworkMonitor? = nil,
        offlineMatchStore: OfflineMatchStore? = nil,
        uiTestLaunchOptions: UITestLaunchOptions? = nil
    ) {
        let resolvedLaunchOptions = uiTestLaunchOptions ?? .current
        self.uiTestLaunchOptions = resolvedLaunchOptions
        self.apiClient = apiClient ?? APIClient()
        self.sessionStore = sessionStore ?? SessionStore(uiTestLaunchOptions: resolvedLaunchOptions)
        self.networkMonitor = networkMonitor ?? NetworkMonitor()
        self.offlineMatchStore = offlineMatchStore ?? OfflineMatchStore()
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
    }

    func logout() {
        let sessionToken = sessionStore.sessionToken
        sessionStore.clear()
        Task {
            await apiClient.logout(sessionTokenOverride: sessionToken)
        }
    }
}
