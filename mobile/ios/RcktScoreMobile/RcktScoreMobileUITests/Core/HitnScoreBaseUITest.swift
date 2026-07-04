import XCTest

class HitnScoreBaseUITest: XCTestCase {

    var app: XCUIApplication!

    // MARK: - Setup

    override func setUpWithError() throws {

        continueAfterFailure = false

    }

    override func tearDownWithError() throws {

        app = nil

    }

    // MARK: - Launching

    func launchApp(lightMode: Bool = true) {

        app = XCUIApplication()

        app.launchArguments = ["UITEST_MODE"]

        app.launchEnvironment["RESET_STATE"] = "1"

        if lightMode {

            app.launchArguments.append("UITEST_LIGHT")

        } else {

            app.launchArguments.append("UITEST_DARK")

        }

        app.launch()

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