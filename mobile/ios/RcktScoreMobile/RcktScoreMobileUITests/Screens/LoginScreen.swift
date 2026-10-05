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
        let identifiedButton = app.buttons["login.logoutOtherMobileSessionButton"]
        if identifiedButton.exists {
            return identifiedButton
        }
        return app.buttons["Log Out Other Mobile Session"]
    }

    var errorMessage: XCUIElement {
        app.staticTexts["login.errorMessage"]
    }

    var organizationSelectionCard: XCUIElement {
        app.descendants(matching: .any)["login.organizationSelectionCard"]
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
        waitForLoginToComplete(user: user)
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

    private func waitForLoginToComplete(user: TestUser, timeout: TimeInterval = 20) {
        let dashboardSettingsTab = app.buttons["dashboard.tab.settings"]
        let deadline = Date().addingTimeInterval(timeout)
        var handledSessionConflict = false

        while Date() < deadline {
            if dashboardSettingsTab.exists {
                return
            }

            if logoutOtherMobileSessionButton.exists,
               logoutOtherMobileSessionButton.isEnabled,
               !handledSessionConflict {
                handledSessionConflict = true
                logoutOtherMobileSessionButton.tap()
                continue
            }

            if organizationSelectionCard.exists {
                let membership = preferredMembershipButton(for: user)
                XCTAssertTrue(
                    membership.waitForExistence(timeout: 5),
                    "Login requires an account choice, but no membership matching \(user.tier) was available."
                )
                membership.tap()
                XCTAssertTrue(dashboardSettingsTab.waitForExistence(timeout: timeout))
                return
            }

            if errorMessage.exists {
                XCTFail("Login failed: \(errorMessage.label)")
                return
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        XCTFail("Login did not reach the dashboard, present an account/session choice, or show an API error")
    }

    private func preferredMembershipButton(for user: TestUser) -> XCUIElement {
        let planFragment: String
        switch user.tier.lowercased() {
        case "personal+", "personal plus":
            planFragment = "personal_plus"
        case "personal", "personal free":
            planFragment = "personal_free"
        case "club pro":
            planFragment = "club_pro"
        default:
            planFragment = "club_essentials"
        }

        return app.buttons.matching(
            NSPredicate(format: "identifier CONTAINS[c] %@", planFragment)
        ).firstMatch
    }
}
