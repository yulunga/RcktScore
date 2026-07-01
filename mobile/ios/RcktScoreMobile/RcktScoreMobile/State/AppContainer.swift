import Foundation
import Combine

@MainActor
final class AppContainer: ObservableObject {
    let apiClient: APIClient
    let sessionStore: SessionStore
    let networkMonitor: NetworkMonitor
    private var cancellables = Set<AnyCancellable>()

    init(apiClient: APIClient? = nil, sessionStore: SessionStore? = nil, networkMonitor: NetworkMonitor? = nil) {
        self.apiClient = apiClient ?? APIClient()
        self.sessionStore = sessionStore ?? SessionStore()
        self.networkMonitor = networkMonitor ?? NetworkMonitor()
        self.apiClient.setSessionToken(self.sessionStore.sessionToken)
        self.apiClient.onSessionInvalidated = { [weak self] _ in
            self?.sessionStore.clear()
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
    }

    func logout() async {
        await apiClient.logout()
        sessionStore.clear()
    }
}
