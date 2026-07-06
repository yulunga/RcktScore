import XCTest

struct LoginScreen {

    let app: XCUIApplication

    var usernameField: XCUIElement {
        let identifiedField = app.textFields["login.usernameField"]
        if identifiedField.exists {
            return identifiedField
        }
        return app.textFields["Enter username"]
    }

    var passwordField: XCUIElement {
        let secureField = app.secureTextFields["login.passwordField"]
        if secureField.exists {
            return secureField
        }
        let visibleField = app.textFields["login.passwordField"]
        if visibleField.exists {
            return visibleField
        }
        return app.secureTextFields["Enter password"]
    }

    var passwordVisibilityButton: XCUIElement {
        app.buttons["login.passwordVisibilityButton"]
    }

    var signInButton: XCUIElement {
        let identifiedButton = app.buttons["login.signInButton"]
        if identifiedButton.exists {
            return identifiedButton
        }
        return app.buttons["Sign in"]
    }

    var wantInButton: XCUIElement {
        app.buttons["login.wantInButton"]
    }

    var needHelpButton: XCUIElement {
        app.buttons["login.needHelpButton"]
    }

    var logoutOtherMobileSessionButton: XCUIElement {
        app.buttons["Log Out Other Mobile Session"]
    }

    func verifyLoaded(timeout: TimeInterval = 10) {
        XCTAssertTrue(signInButton.waitForExistence(timeout: timeout))
        XCTAssertTrue(usernameField.waitForExistence(timeout: timeout))
    }

    func login(user: TestUser) {
        verifyLoaded()

        focusAndType(in: usernameField, text: user.username)

        focusAndType(in: passwordField, text: user.password)

        signInButton.tap()
        resolveSessionConflictIfNeeded()
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

    private func resolveSessionConflictIfNeeded(timeout: TimeInterval = 3) {
        if logoutOtherMobileSessionButton.waitForExistence(timeout: timeout) {
            logoutOtherMobileSessionButton.tap()
        }
    }
}
