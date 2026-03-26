import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        Group {
            if container.sessionStore.isAuthenticated {
                DashboardView()
            } else {
                LoginView()
            }
        }
    }
}
