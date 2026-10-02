import SwiftUI

struct UITestLaunchOptions {
    static let racketServiceSideScenario = "racket-service-side-timeline"

    let isEnabled: Bool
    let resetState: Bool
    let preferredColorScheme: ColorScheme?
    let scenario: String?

    var runsRacketServiceSideScenario: Bool {
        isEnabled && scenario == Self.racketServiceSideScenario
    }

    static var current: UITestLaunchOptions {
        let processInfo = ProcessInfo.processInfo
        let arguments = Set(processInfo.arguments)
        let environment = processInfo.environment

        let isEnabled = arguments.contains("UITEST_MODE")
        let resetState = environment["RESET_STATE"] == "1"

        let preferredColorScheme: ColorScheme?
        if arguments.contains("UITEST_DARK") {
            preferredColorScheme = .dark
        } else if arguments.contains("UITEST_LIGHT") {
            preferredColorScheme = .light
        } else {
            preferredColorScheme = nil
        }

        return UITestLaunchOptions(
            isEnabled: isEnabled,
            resetState: resetState,
            preferredColorScheme: preferredColorScheme,
            scenario: environment["UITEST_SCENARIO"]
        )
    }

    func preparePersistentStateIfNeeded() {
        guard isEnabled, resetState else {
            return
        }

        let defaults = UserDefaults.standard
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleIdentifier)
        }
        defaults.synchronize()
    }
}
