import XCTest

struct DashboardScreen {

    let app: XCUIApplication

    var dashboardTitle: XCUIElement {
        app.staticTexts["dashboardTitle"]
    }

    var settingsButton: XCUIElement {
        app.buttons["settingsButton"]
    }

    func verifyDashboardLoaded() {

        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

    }

}