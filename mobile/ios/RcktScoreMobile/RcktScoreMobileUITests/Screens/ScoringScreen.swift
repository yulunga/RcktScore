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
        app.buttons["scoring.scoreCard.player1"]
    }

    var player2ScoreCard: XCUIElement {
        app.buttons["scoring.scoreCard.player2"]
    }

    var player2ServeSideButton: XCUIElement {
        app.buttons["scoring.serveSide.player2"]
    }

    var player1FirstServerButton: XCUIElement {
        app.buttons["scoring.firstServer.player1"]
    }

    var player2FirstServerButton: XCUIElement {
        app.buttons["scoring.firstServer.player2"]
    }

    var completedReturnButton: XCUIElement {
        app.buttons["scoring.completed.returnButton"]
    }

    var player1ActionButton: XCUIElement {
        app.buttons["scoring.playerAction.player1"]
    }

    var player2ActionButton: XCUIElement {
        app.buttons["scoring.playerAction.player2"]
    }

    func pointRailEntry(side: String, score: Int) -> XCUIElement {
        app.descendants(matching: .any)["scoring.pointRail.\(side).\(score)"]
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

    func waitForScore(side: String, score: Int, timeout: TimeInterval = 15) {
        let card = side == "player1" ? player1ScoreCard : player2ScoreCard
        let predicate = NSPredicate(format: "value == %@", String(score))
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: card)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected \(side) score to become \(score), but the score card value is \(String(describing: card.value))."
        )
    }
}
