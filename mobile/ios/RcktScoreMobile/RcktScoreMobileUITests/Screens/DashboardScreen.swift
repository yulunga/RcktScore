import XCTest

struct DashboardScreen {

    let app: XCUIApplication

    var homeTab: XCUIElement {
        app.buttons["dashboard.tab.home"]
    }

    var matchesTab: XCUIElement {
        app.buttons["dashboard.tab.matches"]
    }

    var historyTab: XCUIElement {
        app.buttons["dashboard.tab.history"]
    }

    var settingsTab: XCUIElement {
        app.buttons["dashboard.tab.settings"]
    }

    var helpTab: XCUIElement {
        app.buttons["dashboard.tab.help"]
    }

    var notificationButton: XCUIElement {
        app.buttons["dashboard.notificationButton"]
    }

    var startNewMatchButton: XCUIElement {
        app.buttons["dashboard.startNewMatchButton"]
    }

    func verifyLoaded(timeout: TimeInterval = 8) {
        XCTAssertTrue(startNewMatchButton.waitForExistence(timeout: timeout))
        XCTAssertTrue(settingsTab.exists)
    }

    func openSettings() {
        settingsTab.tap()
    }

    func openStartNewMatch() {
        startNewMatchButton.tap()
    }
}
