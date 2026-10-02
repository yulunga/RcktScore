import XCTest

class HitnScoreBaseUITest: XCTestCase {

    var app: XCUIApplication!

    // MARK: - Setup

    override func setUpWithError() throws {

        continueAfterFailure = false

        addUIInterruptionMonitor(withDescription: "Dismiss iOS password-save prompt") { alert in
            let normalizedLabel = alert.label.lowercased()
            let passwordPromptText = alert.staticTexts
                .matching(NSPredicate(format: "label CONTAINS[c] 'Save Password'"))
                .firstMatch
            guard normalizedLabel.contains("save password") || passwordPromptText.exists else {
                return false
            }

            for title in ["Not Now", "Not now"] {
                let button = alert.buttons[title]
                if button.exists {
                    button.tap()
                    return true
                }
            }

            return false
        }

    }

    override func tearDownWithError() throws {

        app = nil

    }

    // MARK: - Launching

    func launchApp(lightMode: Bool = true, scenario: String? = nil) {
        if let app, app.state != .notRunning {
            app.terminate()
        }

        app = XCUIApplication()

        app.launchArguments = ["UITEST_MODE"]

        app.launchEnvironment["RESET_STATE"] = "1"

        if let scenario {
            app.launchEnvironment["UITEST_SCENARIO"] = scenario
        }

        if lightMode {

            app.launchArguments.append("UITEST_LIGHT")

        } else {

            app.launchArguments.append("UITEST_DARK")

        }

        app.launch()

    }

    func closeApp() {

        guard let app, app.state != .notRunning else {
            return
        }

        app.terminate()

    }

    /// The Simulator may offer to save credentials after the first successful
    /// login. That sheet belongs to iOS rather than the app, so dashboard
    /// elements can exist while remaining untappable underneath it.
    func dismissPasswordSavePromptIfPresent(timeout: TimeInterval = 4) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let candidates = [
                springboard.buttons["Not Now"],
                springboard.buttons["Not now"],
                app.alerts.buttons["Not Now"],
                app.alerts.buttons["Not now"],
                app.sheets.buttons["Not Now"],
                app.sheets.buttons["Not now"],
            ]

            if let button = candidates.first(where: { $0.exists && $0.isHittable }) {
                button.tap()
                return
            }

            // This harmless interaction also gives XCTest's interruption
            // monitor an opportunity to handle OS-owned alerts.
            if app.state == .runningForeground {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.02)).tap()
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
    }

    // MARK: - Orientation

    func rotatePortrait() {

        XCUIDevice.shared.orientation = .portrait

        waitForRotation()

    }

    func rotateLandscapeLeft() {

        XCUIDevice.shared.orientation = .landscapeLeft

        waitForRotation()

    }

    func rotateLandscapeRight() {

        XCUIDevice.shared.orientation = .landscapeRight

        waitForRotation()

    }

    private func waitForRotation() {

        RunLoop.current.run(until: Date().addingTimeInterval(1))

    }

    // MARK: - Screenshots

    func captureScreenshot(_ name: String) {

        let attachment = XCTAttachment(
            screenshot: XCUIScreen.main.screenshot()
        )

        attachment.name = name

        attachment.lifetime = .keepAlways

        add(attachment)

    }

}
