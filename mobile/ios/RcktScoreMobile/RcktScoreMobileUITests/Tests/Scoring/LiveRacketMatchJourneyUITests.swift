import XCTest

final class LiveRacketMatchJourneyUITests: HitnScoreBaseUITest {
    @MainActor
    func testPersonalPlusCreatesScoresCompletesAndLogsOut() throws {
        let user = try TestUser.personalPlusFromEnvironment()
        launchApp(lightMode: false)
        rotatePortrait()

        let login = LoginScreen(app: app)
        let dashboard = DashboardScreen(app: app)
        let setup = MatchSetupScreen(app: app)
        let scoring = ScoringScreen(app: app)
        let settings = SettingsScreen(app: app)

        login.login(user: user)
        dashboard.verifyLoaded()
        visualCheckpoint("Live-01-Logged-In")

        dashboard.openStartNewMatch()
        XCTAssertTrue(setup.squashSportButton.waitForExistence(timeout: 8))
        setup.chooseSport(.squash)
        setup.verifySetupLoaded(timeout: 10)

        XCTAssertFalse(
            setup.resumeActiveMatchButton.exists,
            "The Personal Plus test account already has an active match. Complete it before running this live journey so the test never ends an unrelated match."
        )

        setup.selectBestOfOneScoreToEleven()
        setup.enterPlayers(player1: "Paul", player2: "Mark")
        visualCheckpoint("Live-02-Paul-v-Mark-Best-of-1-PAR-11")

        XCTAssertTrue(setup.startMatchButton.isEnabled)
        setup.startMatchButton.tap()

        XCTAssertTrue(scoring.warmupSkipButton.waitForExistence(timeout: 20))
        visualCheckpoint("Live-03-Match-Created")
        scoring.warmupSkipButton.tap()

        XCTAssertTrue(scoring.player1FirstServerButton.waitForExistence(timeout: 8))
        visualCheckpoint("Live-04-Choose-Paul-First-Server")
        scoring.player1FirstServerButton.tap()
        scoring.waitForScore(side: "player1", score: 0)

        score(scoring.player2ScoreCard, side: "player2", expected: 1, scoring: scoring)
        score(scoring.player1ScoreCard, side: "player1", expected: 1, scoring: scoring)
        score(scoring.player1ScoreCard, side: "player1", expected: 2, scoring: scoring)
        score(scoring.player2ScoreCard, side: "player2", expected: 2, scoring: scoring)

        let markAtTwo = scoring.pointRailEntry(side: "player2", score: 2)
        XCTAssertTrue(markAtTwo.waitForExistence(timeout: 8))
        XCTAssertEqual(markAtTwo.label, "R2")
        visualCheckpoint("Live-05-Mark-Gains-Serve-R2")

        XCTAssertTrue(scoring.player2ServeSideButton.waitForExistence(timeout: 5))
        scoring.player2ServeSideButton.tap()
        waitForLabel("L2", on: markAtTwo)
        visualCheckpoint("Live-06-R2-Replaced-By-L2")

        scoring.openActionMenu()
        XCTAssertTrue(scoring.letActionButton.waitForExistence(timeout: 5))
        scoring.letActionButton.tap()
        XCTAssertTrue(scoring.player2ActionButton.waitForExistence(timeout: 5))
        scoring.player2ActionButton.tap()
        scoring.waitForScore(side: "player2", score: 2)
        XCTAssertEqual(markAtTwo.label, "L2")
        visualCheckpoint("Live-07-Let-Preserves-L2")

        score(scoring.player2ScoreCard, side: "player2", expected: 3, scoring: scoring)
        let markAtThree = scoring.pointRailEntry(side: "player2", score: 3)
        XCTAssertTrue(markAtThree.waitForExistence(timeout: 8))
        XCTAssertEqual(markAtThree.label, "R3")
        XCTAssertEqual(markAtTwo.label, "L2")
        visualCheckpoint("Live-08-L2-Persists-With-R3")

        scoring.openActionMenu()
        XCTAssertTrue(scoring.undoActionButton.waitForExistence(timeout: 5))
        scoring.undoActionButton.tap()
        scoring.waitForScore(side: "player2", score: 2)
        XCTAssertEqual(markAtTwo.label, "L2")
        visualCheckpoint("Live-09-Undo-Returns-To-L2")

        score(scoring.player2ScoreCard, side: "player2", expected: 3, scoring: scoring)
        for nextScore in 4...10 {
            score(scoring.player2ScoreCard, side: "player2", expected: nextScore, scoring: scoring)
        }

        scoring.player2ScoreCard.tap()

        XCTAssertTrue(scoring.completedReturnButton.waitForExistence(timeout: 20))
        visualCheckpoint("Live-10-Mark-Wins-11-2")
        scoring.completedReturnButton.tap()

        XCTAssertTrue(dashboard.settingsTab.waitForExistence(timeout: 12))
        dashboard.openSettings()
        settings.verifyLoaded()
        visualCheckpoint("Live-11-Ready-To-Logout")
        settings.logout()
        login.verifyLoaded()
        visualCheckpoint("Live-12-Logged-Out")
    }

    private func score(
        _ card: XCUIElement,
        side: String,
        expected: Int,
        scoring: ScoringScreen
    ) {
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        card.tap()
        scoring.waitForScore(side: side, score: expected)
        visualPause()
    }

    private func waitForLabel(
        _ expectedLabel: String,
        on element: XCUIElement,
        timeout: TimeInterval = 10
    ) {
        let predicate = NSPredicate(format: "label == %@", expectedLabel)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
    }

    private func visualCheckpoint(_ name: String) {
        visualPause()
        captureScreenshot(name)
    }

    private func visualPause() {
        let environment = ProcessInfo.processInfo.environment
        let rawValue = environment["HITNSCORE_UI_TEST_STEP_DELAY"]
            ?? environment["TEST_RUNNER_HITNSCORE_UI_TEST_STEP_DELAY"]
            ?? "0.8"
        let delay = max(0, min(Double(rawValue) ?? 0.8, 5))
        RunLoop.current.run(until: Date().addingTimeInterval(delay))
    }
}
