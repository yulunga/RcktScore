//
//  RcktScoreMobileApp.swift
//  RcktScoreMobile
//
//  Created by Glenn Rowe on 26/03/2026.
//

import SwiftUI

@main
struct RcktScoreMobileApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
        }
    }
}
