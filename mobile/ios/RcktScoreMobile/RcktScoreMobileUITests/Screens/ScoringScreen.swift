import XCTest

struct ScoringScreen {

    let app: XCUIApplication

    var player1ScoreButton: XCUIElement {
        app.buttons["player1ScoreButton"]
    }

    var player2ScoreButton: XCUIElement {
        app.buttons["player2ScoreButton"]
    }

    var undoButton: XCUIElement {
        app.buttons["undoButton"]
    }

    var scoreLabel: XCUIElement {
        app.staticTexts["matchScoreLabel"]
    }

    func scorePlayer1(times: Int) {
        for _ in 0..<times {
            player1ScoreButton.tap()
        }
    }

    func scorePlayer2(times: Int) {
        for _ in 0..<times {
            player2ScoreButton.tap()
        }
    }
}