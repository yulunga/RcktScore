//
//  RcktScoreMobileApp.swift
//  RcktScoreMobile
//
//  Created by Glenn Rowe on 26/03/2026.
//

import SwiftUI

@main
struct RcktScoreMobileApp: App {
    private let uiTestLaunchOptions: UITestLaunchOptions
    @StateObject private var container: AppContainer

    init() {
        let uiTestLaunchOptions = UITestLaunchOptions.current
        uiTestLaunchOptions.preparePersistentStateIfNeeded()
        self.uiTestLaunchOptions = uiTestLaunchOptions
        _container = StateObject(
            wrappedValue: AppContainer(uiTestLaunchOptions: uiTestLaunchOptions)
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
                .preferredColorScheme(uiTestLaunchOptions.preferredColorScheme)
        }
    }
}
