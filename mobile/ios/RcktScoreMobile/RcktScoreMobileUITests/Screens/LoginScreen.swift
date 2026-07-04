import XCTest

struct LoginScreen {

    let app: XCUIApplication

    var usernameField: XCUIElement {
        app.textFields["login.usernameField"]
    }

    var passwordField: XCUIElement {
        let secureField = app.secureTextFields["login.passwordField"]
        if secureField.exists {
            return secureField
        }
        return app.textFields["login.passwordField"]
    }

    var passwordVisibilityButton: XCUIElement {
        app.buttons["login.passwordVisibilityButton"]
    }

    var signInButton: XCUIElement {
        app.buttons["login.signInButton"]
    }

    var wantInButton: XCUIElement {
        app.buttons["login.wantInButton"]
    }

    var needHelpButton: XCUIElement {
        app.buttons["login.needHelpButton"]
    }

    func verifyLoaded(timeout: TimeInterval = 5) {
        XCTAssertTrue(usernameField.waitForExistence(timeout: timeout))
        XCTAssertTrue(signInButton.exists)
    }

    func login(user: TestUser) {
        verifyLoaded()

        usernameField.tap()
        usernameField.typeText(user.username)

        passwordField.tap()
        passwordField.typeText(user.password)

        signInButton.tap()
    }
}
