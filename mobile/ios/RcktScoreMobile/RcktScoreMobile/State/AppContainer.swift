import Foundation
import Combine

@MainActor
final class AppContainer: ObservableObject {
    let apiClient: APIClient
    let sessionStore: SessionStore

    init(apiClient: APIClient? = nil, sessionStore: SessionStore? = nil) {
        self.apiClient = apiClient ?? APIClient()
        self.sessionStore = sessionStore ?? SessionStore()
    }
}
