import Foundation
import Combine

@MainActor
final class AppContainer: ObservableObject {
    let apiClient: APIClient
    let sessionStore: SessionStore
    private var cancellables = Set<AnyCancellable>()

    init(apiClient: APIClient? = nil, sessionStore: SessionStore? = nil) {
        self.apiClient = apiClient ?? APIClient()
        self.sessionStore = sessionStore ?? SessionStore()
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
    }

    func logout() async {
        await apiClient.logout()
        sessionStore.clear()
    }
}
