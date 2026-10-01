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
        XCTAssertTrue(settingsTab.waitForExistence(timeout: timeout))
        XCTAssertTrue(homeTab.exists)

        if !startNewMatchButton.exists {
            homeTab.tap()
        }

        XCTAssertTrue(startNewMatchButton.waitForExistence(timeout: timeout))
    }

    func openSettings(timeout: TimeInterval = 8) {
        let profileMenu = app.buttons["settings.menu.profile"]

        for _ in 0..<3 {
            guard settingsTab.waitForExistence(timeout: timeout / 3) else {
                continue
            }

            if settingsTab.isHittable {
                settingsTab.tap()
            } else {
                settingsTab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }

            if profileMenu.waitForExistence(timeout: timeout / 3) {
                return
            }
        }

        XCTFail("Unable to open Settings from the dashboard")
    }

    func openStartNewMatch() {
        startNewMatchButton.tap()
    }
}
