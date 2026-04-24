import Foundation
import Combine

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var session: UserSession?

    private let key = "rcktscore.mobile.session"

    init() {
        load()
    }

    var isAuthenticated: Bool {
        session != nil
    }

    var sessionToken: String? {
        session?.sessionToken
    }

    func save(_ newSession: UserSession) {
        session = newSession
        if let encoded = try? JSONEncoder().encode(newSession) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    func clear() {
        session = nil
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let stored = try? JSONDecoder().decode(UserSession.self, from: data) else {
            return
        }
        session = stored
    }
}
