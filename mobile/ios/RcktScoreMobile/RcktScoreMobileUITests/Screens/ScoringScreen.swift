import XCTest

struct ScoringScreen {

    let app: XCUIApplication

    var backButton: XCUIElement {
        app.buttons["scoring.backButton"]
    }

    var gameSettingsButton: XCUIElement {
        app.buttons["scoring.gameSettingsButton"]
    }

    var player1ScoreCard: XCUIElement {
        app.otherElements["scoring.scoreCard.player1"]
    }

    var player2ScoreCard: XCUIElement {
        app.otherElements["scoring.scoreCard.player2"]
    }

    var timerButton: XCUIElement {
        app.buttons["scoring.timerButton"]
    }

    var timerSkipButton: XCUIElement {
        app.buttons["scoring.timerSkipButton"]
    }

    var actionButton: XCUIElement {
        app.buttons["scoring.actionButton"]
    }

    var undoActionButton: XCUIElement {
        app.buttons["scoring.action.undo"]
    }

    var endMatchEarlyButton: XCUIElement {
        app.buttons["scoring.action.endEarly"]
    }

    var strokeActionButton: XCUIElement {
        app.buttons["scoring.action.stroke"]
    }

    var letActionButton: XCUIElement {
        app.buttons["scoring.action.let"]
    }

    var warmupStartButton: XCUIElement {
        app.buttons["scoring.warmup.startButton"]
    }

    var warmupSkipButton: XCUIElement {
        app.buttons["scoring.warmup.skipButton"]
    }

    func verifyLoaded(timeout: TimeInterval = 8) {
        XCTAssertTrue(
            player1ScoreCard.waitForExistence(timeout: timeout)
                || warmupStartButton.waitForExistence(timeout: timeout)
                || timerButton.waitForExistence(timeout: timeout)
        )
    }

    func scorePlayer1(times: Int) {
        for _ in 0..<times {
            player1ScoreCard.tap()
        }
    }

    func scorePlayer2(times: Int) {
        for _ in 0..<times {
            player2ScoreCard.tap()
        }
    }

    func openActionMenu() {
        actionButton.tap()
    }
}
