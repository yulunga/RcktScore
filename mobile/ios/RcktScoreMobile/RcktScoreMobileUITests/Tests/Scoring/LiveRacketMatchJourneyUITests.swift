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
        dismissPasswordSavePromptIfPresent()
        dashboard.verifyLoaded()
        visualCheckpoint("Live-01-Logged-In")

        dashboard.openStartNewMatch()
        XCTAssertTrue(setup.squashSportButton.waitForExistence(timeout: 8))
        setup.chooseSport(.squash)
        setup.verifySetupLoaded(timeout: 10)

        if endExistingPersonalMatchIfNeeded(setup: setup, scoring: scoring) {
            XCTAssertTrue(dashboard.startNewMatchButton.waitForExistence(timeout: 15))
            dashboard.openStartNewMatch()
            XCTAssertTrue(setup.squashSportButton.waitForExistence(timeout: 8))
            setup.chooseSport(.squash)
            setup.verifySetupLoaded(timeout: 10)
            XCTAssertFalse(
                setup.resumeActiveMatchButton.waitForExistence(timeout: 3),
                "The previously active personal match was ended, but it is still being offered for resume."
            )
        }

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

    private func endExistingPersonalMatchIfNeeded(
        setup: MatchSetupScreen,
        scoring: ScoringScreen
    ) -> Bool {
        guard setup.resumeActiveMatchButton.waitForExistence(timeout: 3) else {
            return false
        }

        visualCheckpoint("Live-Recovery-01-Existing-Personal-Match")
        setup.resumeActiveMatchButton.tap()
        scoring.verifyLoaded(timeout: 20)

        XCTAssertTrue(
            scoring.actionButton.waitForExistence(timeout: 10),
            "The existing personal match opened, but its Action control was unavailable."
        )
        XCTAssertTrue(scoring.actionButton.isHittable)
        scoring.openActionMenu()
        XCTAssertTrue(
            scoring.endMatchEarlyButton.waitForExistence(timeout: 8),
            "The existing personal match could not expose End Match Early."
        )
        XCTAssertTrue(scoring.endMatchEarlyButton.isEnabled)
        scoring.endMatchEarlyButton.tap()

        XCTAssertTrue(
            scoring.completedReturnButton.waitForExistence(timeout: 25),
            "The existing personal match did not reach its completed state after End Match Early."
        )
        visualCheckpoint("Live-Recovery-02-Existing-Personal-Match-Ended")
        scoring.completedReturnButton.tap()
        return true
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
