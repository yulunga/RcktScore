import XCTest

struct LoginScreen {

    let app: XCUIApplication

    var emailField: XCUIElement {
        app.textFields["emailField"]
    }

    var passwordField: XCUIElement {
        app.secureTextFields["passwordField"]
    }

    var loginButton: XCUIElement {
        app.buttons["loginButton"]
    }

    func login(user: TestUser) {

        emailField.tap()
        emailField.typeText(user.username)

        passwordField.tap()
        passwordField.typeText(user.password)

        loginButton.tap()
    }

}