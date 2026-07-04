import XCTest

class HitnScoreBaseUITest: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE"]
        app.launchEnvironment["RESET_STATE"] = "1"
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}