import XCTest

struct SettingsScreen {

    let app: XCUIApplication

    var signOutButton: XCUIElement {

        app.buttons["signOutButton"]

    }

    func logout() {

        signOutButton.tap()

    }

}