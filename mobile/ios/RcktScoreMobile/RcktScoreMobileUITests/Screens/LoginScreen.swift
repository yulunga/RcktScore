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

        focusAndType(in: usernameField, text: user.username)

        focusAndType(in: passwordField, text: user.password)

        signInButton.tap()
    }

    private func focusAndType(in element: XCUIElement, text: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))

        focusElement(element)
        element.typeText(text)
    }

    private func focusElement(_ element: XCUIElement, timeout: TimeInterval = 2) {
        element.tap()
        waitForKeyboard(timeout: timeout)

        if !app.keyboards.firstMatch.exists {
            let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            coordinate.tap()
            waitForKeyboard(timeout: timeout)
        }
    }

    private func waitForKeyboard(timeout: TimeInterval = 2) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.keyboards.firstMatch.exists {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
    }
}
