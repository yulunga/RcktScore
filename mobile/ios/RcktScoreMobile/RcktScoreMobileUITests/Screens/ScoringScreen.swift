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

    var tennisPlayer1ScoreCard: XCUIElement {
        app.buttons["tennis.scoreCard.player1"]
    }

    var tennisPlayer2ScoreCard: XCUIElement {
        app.buttons["tennis.scoreCard.player2"]
    }

    var tennisFormatBanner: XCUIElement {
        app.descendants(matching: .any)["tennis.formatBanner"]
    }

    var tennisOpeningPlayer1ServerButton: XCUIElement {
        app.buttons["scoring.tennisOpening.server.team1_player1"]
    }

    var tennisOpeningPlayer2ReceiverButton: XCUIElement {
        app.buttons["scoring.tennisOpening.receiver.team2_player1"]
    }

    var tennisBeginMatchButton: XCUIElement {
        app.buttons["scoring.tennisOpening.beginMatchButton"]
    }

    var tennisNoAdReceiverChoice: XCUIElement {
        app.descendants(matching: .any)["tennis.noAdReceiverChoice"]
    }

    var tennisNoAdDeuceCourtButton: XCUIElement {
        app.buttons["tennis.noAdReceiverChoice.Right"]
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

    var intervalSkipButton: XCUIElement {
        app.buttons["scoring.interval.skipButton"]
    }

    var actionButton: XCUIElement {
        app.buttons["scoring.actionButton"]
    }

    var closeActionMenuButton: XCUIElement {
        app.buttons["Close match actions"]
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

    func waitForTennisState(
        side: String,
        points: String,
        games: Int,
        sets: Int,
        timeout: TimeInterval = 20
    ) {
        let card = side == "player1" ? tennisPlayer1ScoreCard : tennisPlayer2ScoreCard
        let expected = "Points \(points), Games \(games), Sets \(sets)"
        let predicate = NSPredicate(format: "value == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: card)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected \(side) tennis state '\(expected)', but the score card value is \(String(describing: card.value))."
        )
    }

    func tapTennisScoreCard(side: String, timeout: TimeInterval = 30) {
        let card = side == "player1" ? tennisPlayer1ScoreCard : tennisPlayer2ScoreCard
        XCTAssertTrue(card.waitForExistence(timeout: timeout))

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if card.isEnabled && card.isHittable {
                card.tap()
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        XCTFail(
            "Timed out waiting for \(side) tennis score card to become enabled and hittable. "
                + "enabled=\(card.isEnabled), hittable=\(card.isHittable), value=\(String(describing: card.value))"
        )
    }

    func waitForTennisMode(_ mode: String, set: Int, timeout: TimeInterval = 20) {
        let expected = "\(mode) set \(set)"
        let predicate = NSPredicate(format: "value == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: tennisFormatBanner)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected tennis mode '\(expected)', but the format banner value is \(String(describing: tennisFormatBanner.value))."
        )
    }
}
