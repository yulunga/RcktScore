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

        self.sessionStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
