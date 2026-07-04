import XCTest

struct MatchSetupScreen {

    let app: XCUIApplication

    var newMatchButton: XCUIElement {
        app.buttons["newMatchButton"]
    }

    var player1NameField: XCUIElement {
        app.textFields["player1NameField"]
    }

    var player2NameField: XCUIElement {
        app.textFields["player2NameField"]
    }

    var startMatchButton: XCUIElement {
        app.buttons["startMatchButton"]
    }

    func createMatch(player1: String, player2: String) {
        newMatchButton.tap()

        player1NameField.tap()
        player1NameField.typeText(player1)

        player2NameField.tap()
        player2NameField.typeText(player2)

        startMatchButton.tap()
    }
}