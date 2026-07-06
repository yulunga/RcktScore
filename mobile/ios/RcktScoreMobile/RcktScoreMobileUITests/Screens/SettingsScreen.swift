import XCTest

struct SettingsScreen {

    let app: XCUIApplication

    var profileMenu: XCUIElement {
        app.buttons["settings.menu.profile"]
    }

    var subscriptionMenu: XCUIElement {
        app.buttons["settings.menu.subscription"]
    }

    var associationMenu: XCUIElement {
        app.buttons["settings.menu.association"]
    }

    var racketSportsMenu: XCUIElement {
        app.buttons["settings.menu.racketSports"]
    }

    var usersMenu: XCUIElement {
        app.buttons["settings.menu.users"]
    }

    var courtsMenu: XCUIElement {
        app.buttons["settings.menu.courts"]
    }

    var orgSettingsMenu: XCUIElement {
        app.buttons["settings.menu.orgSettings"]
    }

    var signOutButton: XCUIElement {
        app.buttons["settings.signOutButton"]
    }

    var profileFirstNameField: XCUIElement {
        app.textFields["settings.profile.firstNameField"]
    }

    var profileSurnameField: XCUIElement {
        app.textFields["settings.profile.surnameField"]
    }

    var profileEmailField: XCUIElement {
        app.textFields["settings.profile.emailField"]
    }

    var profileSaveButton: XCUIElement {
        app.buttons["settings.profile.saveButton"]
    }

    var biometricToggle: XCUIElement {
        app.switches["settings.profile.biometricToggle"]
    }

    var loginSignInButton: XCUIElement {
        let identifiedButton = app.buttons["login.signInButton"]
        if identifiedButton.exists {
            return identifiedButton
        }
        return app.buttons["Sign in"]
    }

    var loginUsernameField: XCUIElement {
        let identifiedField = app.textFields["login.usernameField"]
        if identifiedField.exists {
            return identifiedField
        }
        return app.textFields["Enter username"]
    }

    func verifyLoaded(timeout: TimeInterval = 5) {
        XCTAssertTrue(profileMenu.waitForExistence(timeout: timeout))
    }

    func openProfile() {
        profileMenu.tap()
    }

    func openAssociation() {
        associationMenu.tap()
    }

    func openRacketSports() {
        racketSportsMenu.tap()
    }

    func openUsers() {
        usersMenu.tap()
    }

    func openCourts() {
        courtsMenu.tap()
    }

    func openOrganisationSettings() {
        orgSettingsMenu.tap()
    }

    func logout() {
        for _ in 0..<3 {
            if loginScreenIsVisible(timeout: 1) {
                return
            }

            scrollToSignOutButton()

            if signOutButton.isHittable {
                signOutButton.tap()
            } else {
                let coordinate = signOutButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                coordinate.tap()
            }

            if loginScreenIsVisible(timeout: 3) {
                return
            }
        }

        XCTAssertTrue(loginScreenIsVisible(timeout: 10))
    }

    private func scrollToSignOutButton(maxScrollAttempts: Int = 8) {
        if signOutButton.isHittable {
            return
        }

        let scrollView = app.scrollViews.firstMatch

        for _ in 0..<maxScrollAttempts {
            if signOutButton.isHittable {
                return
            }

            if scrollView.exists {
                scrollView.swipeUp()
            } else {
                app.swipeUp()
            }
        }

        XCTAssertTrue(signOutButton.waitForExistence(timeout: 2))
    }

    private func loginScreenIsVisible(timeout: TimeInterval) -> Bool {
        if loginSignInButton.waitForExistence(timeout: timeout) {
            return true
        }
        return loginUsernameField.waitForExistence(timeout: 1)
    }
}
