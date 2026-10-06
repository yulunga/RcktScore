import XCTest

// MARK: - Live Personal Plus Tennis Journey
//
// Logs in to the real backend and completes two Best-of-3 matches. The singles
// match tests deuce/advantage, a 6-6 first set and an extended tiebreak. The
// doubles match tests four-player setup, Golden Point and timed breaks. The
// journey verifies match completion after each match and finishes by logging
// out. It creates real completed matches in the Personal Plus test account.

final class LiveTennisMatchJourneyUITests: HitnScoreBaseUITest {
    @MainActor
    func testPersonalPlusCompletesSinglesAndDoublesJourneys() throws {
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
        checkpoint("Tennis-01-Logged-In")

        openTennisSetup(dashboard: dashboard, setup: setup)
        if endExistingPersonalMatchIfNeeded(setup: setup, scoring: scoring) {
            openTennisSetup(dashboard: dashboard, setup: setup)
            XCTAssertFalse(
                setup.resumeActiveMatchButton.waitForExistence(timeout: 3),
                "The previously active personal match was ended, but it is still being offered for resume."
            )
        }

        setup.enterPlayers(player1: "Paul", player2: "Mark")
        setup.selectBestOfThreeTennis()
        setup.disableTennisTimedBreaks()
        checkpoint("Tennis-02-Best-of-3-Setup")
        XCTAssertTrue(setup.startMatchButton.isEnabled)
        setup.startMatchButton.tap()

        XCTAssertTrue(scoring.warmupSkipButton.waitForExistence(timeout: 20))
        scoring.warmupSkipButton.tap()
        chooseSinglesOpeningOrder(scoring)
        scoring.waitForTennisState(side: "player1", points: "0", games: 0, sets: 0)
        scoring.waitForTennisTimedBreaks(enabled: false)
        checkpoint("Tennis-03-Match-Live")

        // Set one starts with a love hold, then a deuce game won by Mark.
        completeLoveGame(winner: "player1", games: (1, 0), sets: (0, 0), scoring: scoring)
        completeDeuceGameForPlayer2(games: (1, 1), scoring: scoring)
        checkpoint("Tennis-04-Deuce-Game-Complete")

        // Alternate the remaining games so neither player can win before 6-6.
        for gameNumber in 3...12 {
            let winner = gameNumber.isMultiple(of: 2) ? "player2" : "player1"
            completeLoveGame(
                winner: winner,
                games: ((gameNumber + 1) / 2, gameNumber / 2),
                sets: (0, 0),
                scoring: scoring
            )
        }

        scoring.waitForTennisState(side: "player1", points: "0", games: 6, sets: 0)
        scoring.waitForTennisState(side: "player2", points: "0", games: 6, sets: 0)
        scoring.waitForTennisMode("tiebreak", set: 1)
        checkpoint("Tennis-05-First-Set-6-6")

        // Reach 6-6 in the tiebreak, proving it does not end at 7-6, then win 8-6.
        for pointNumber in 1...12 {
            let side = pointNumber.isMultiple(of: 2) ? "player2" : "player1"
            scorePoint(side, expectedPoints: String((pointNumber + 1) / 2), games: 6, sets: 0, scoring: scoring)
        }
        scorePoint("player1", expectedPoints: "7", games: 6, sets: 0, scoring: scoring)
        XCTAssertFalse(scoring.completedReturnButton.exists, "The tiebreak must be won by two points.")
        scoring.tapTennisScoreCard(side: "player1")
        scoring.waitForTennisState(side: "player1", points: "0", games: 0, sets: 1)
        scoring.waitForTennisMode("standard", set: 2)
        checkpoint("Tennis-06-Paul-Wins-Tiebreak-8-6")
        XCTAssertFalse(
            scoring.intervalSkipButton.waitForExistence(timeout: 2),
            "Timed breaks were disabled during setup, but a set-break overlay appeared."
        )

        // Paul closes the best-of-three match in straight sets, 6-0 in set two.
        for completedGames in 1...5 {
            completeLoveGame(
                winner: "player1",
                games: (completedGames, 0),
                sets: (1, 0),
                scoring: scoring
            )
        }
        scoreFirstThreePoints("player1", games: (5, 0), sets: (1, 0), scoring: scoring)
        scoring.tapTennisScoreCard(side: "player1")

        XCTAssertTrue(scoring.completedReturnButton.waitForExistence(timeout: 25))
        checkpoint("Tennis-07-Singles-Complete-2-0")
        scoring.completedReturnButton.tap()

        // Start a second match as doubles and exercise four-player setup,
        // Golden Point, timed breaks, team scoring, and match completion.
        XCTAssertTrue(dashboard.startNewMatchButton.waitForExistence(timeout: 12))
        openTennisSetup(dashboard: dashboard, setup: setup)
        setup.chooseDoubles()
        setup.enterDoublesPlayers(
            team1Player1: "Paul",
            team1Player2: "Peter",
            team2Player1: "Mark",
            team2Player2: "Matt"
        )
        setup.selectBestOfThreeTennis()
        setup.enableTennisGoldenPoint()
        setup.enableTennisTimedBreaks()
        checkpoint("Tennis-08-Doubles-Setup")
        XCTAssertTrue(setup.startMatchButton.isEnabled)
        setup.startMatchButton.tap()

        XCTAssertTrue(scoring.warmupSkipButton.waitForExistence(timeout: 20))
        scoring.warmupSkipButton.tap()
        chooseDoublesOpeningOrder(scoring)
        scoring.waitForTennisState(side: "player1", points: "0", games: 0, sets: 0)
        scoring.waitForTennisTimedBreaks(enabled: true)
        checkpoint("Tennis-09-Doubles-Match-Live")

        completeGoldenPointGameForPlayer1(scoring: scoring)

        for completedGames in 2...5 {
            completeLoveGame(
                winner: "player1",
                games: (completedGames, 0),
                sets: (0, 0),
                scoring: scoring
            )
            if completedGames == 3 || completedGames == 5 {
                skipDoublesTimedBreak(afterGame: completedGames, set: 1, scoring: scoring)
            }
        }
        scoreFirstThreePoints("player1", games: (5, 0), sets: (0, 0), scoring: scoring)
        scoring.tapTennisScoreCard(side: "player1")
        scoring.waitForTennisState(side: "player1", points: "0", games: 0, sets: 1)
        scoring.waitForTennisMode("standard", set: 2)
        skipDoublesTimedBreak(afterGame: 6, set: 1, scoring: scoring)

        for completedGames in 1...5 {
            completeLoveGame(
                winner: "player1",
                games: (completedGames, 0),
                sets: (1, 0),
                scoring: scoring
            )
            if completedGames == 3 || completedGames == 5 {
                skipDoublesTimedBreak(afterGame: completedGames, set: 2, scoring: scoring)
            }
        }
        scoreFirstThreePoints("player1", games: (5, 0), sets: (1, 0), scoring: scoring)
        scoring.tapTennisScoreCard(side: "player1")

        XCTAssertTrue(scoring.completedReturnButton.waitForExistence(timeout: 25))
        checkpoint("Tennis-10-Doubles-Complete-2-0")
        scoring.completedReturnButton.tap()

        XCTAssertTrue(dashboard.settingsTab.waitForExistence(timeout: 12))
        dashboard.openSettings()
        settings.verifyLoaded()
        settings.logout()
        login.verifyLoaded()
        checkpoint("Tennis-11-Logged-Out")
    }

    private func openTennisSetup(dashboard: DashboardScreen, setup: MatchSetupScreen) {
        dashboard.openStartNewMatch()
        XCTAssertTrue(setup.tennisSportButton.waitForExistence(timeout: 8))
        setup.chooseSport(.tennis)
        setup.verifySetupLoaded(timeout: 10)
    }

    private func chooseSinglesOpeningOrder(_ scoring: ScoringScreen) {
        XCTAssertTrue(scoring.tennisOpeningPlayer1ServerButton.waitForExistence(timeout: 8))
        scoring.tennisOpeningPlayer1ServerButton.tap()
        XCTAssertFalse(
            scoring.tennisOpeningPlayer2ReceiverButton.exists,
            "Singles should infer the receiver from the selected opening server."
        )
        XCTAssertTrue(scoring.tennisBeginMatchButton.isEnabled)
        scoring.tennisBeginMatchButton.tap()
    }

    private func chooseDoublesOpeningOrder(_ scoring: ScoringScreen) {
        XCTAssertTrue(scoring.tennisOpeningPlayer1ServerButton.waitForExistence(timeout: 8))
        scoring.tennisOpeningPlayer1ServerButton.tap()
        XCTAssertTrue(
            scoring.tennisOpeningPlayer2ReceiverButton.waitForExistence(timeout: 5),
            "Doubles should require the receiving team to choose its opening receiver."
        )
        scoring.tennisOpeningPlayer2ReceiverButton.tap()
        XCTAssertTrue(scoring.tennisBeginMatchButton.isEnabled)
        scoring.tennisBeginMatchButton.tap()
    }

    private func completeGoldenPointGameForPlayer1(scoring: ScoringScreen) {
        for points in ["15", "30", "40"] {
            scorePoint("player1", expectedPoints: points, games: 0, sets: 0, scoring: scoring)
            scorePoint("player2", expectedPoints: points, games: 0, sets: 0, scoring: scoring)
        }

        XCTAssertFalse(
            scoring.tennisNoAdReceiverChoice.exists,
            "Tennis Golden Point should use the normal 40-40 side without asking for a receiver choice."
        )
        scoring.tapTennisScoreCard(side: "player1")
        scoring.waitForTennisState(side: "player1", points: "0", games: 1, sets: 0)
    }

    private func skipDoublesTimedBreak(afterGame game: Int, set: Int, scoring: ScoringScreen) {
        XCTAssertTrue(
            scoring.intervalSkipButton.waitForExistence(timeout: 10),
            "Expected a timed doubles break after game \(game) of set \(set)."
        )
        scoring.intervalSkipButton.tap()

        let breakDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: scoring.intervalSkipButton
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [breakDismissed], timeout: 5),
            .completed,
            "The timed doubles break after game \(game) of set \(set) did not dismiss."
        )
    }

    private func completeLoveGame(
        winner: String,
        games: (Int, Int),
        sets: (Int, Int),
        scoring: ScoringScreen
    ) {
        let previousGames = winner == "player1" ? (games.0 - 1, games.1) : (games.0, games.1 - 1)
        scoreFirstThreePoints(winner, games: previousGames, sets: sets, scoring: scoring)
        scoring.tapTennisScoreCard(side: winner)
        scoring.waitForTennisState(
            side: winner,
            points: "0",
            games: winner == "player1" ? games.0 : games.1,
            sets: winner == "player1" ? sets.0 : sets.1
        )
        visualPause()
    }

    private func completeDeuceGameForPlayer2(games: (Int, Int), scoring: ScoringScreen) {
        for points in ["15", "30", "40"] {
            scorePoint("player1", expectedPoints: points, games: games.0, sets: 0, scoring: scoring)
            scorePoint("player2", expectedPoints: points, games: games.1 - 1, sets: 0, scoring: scoring)
        }
        scorePoint("player1", expectedPoints: "Ad", games: games.0, sets: 0, scoring: scoring)
        scorePoint("player2", expectedPoints: "40", games: games.1 - 1, sets: 0, scoring: scoring)
        scorePoint("player2", expectedPoints: "Ad", games: games.1 - 1, sets: 0, scoring: scoring)
        scoring.tapTennisScoreCard(side: "player2")
        scoring.waitForTennisState(side: "player2", points: "0", games: games.1, sets: 0)
    }

    private func scoreFirstThreePoints(
        _ side: String,
        games: (Int, Int),
        sets: (Int, Int),
        scoring: ScoringScreen
    ) {
        let sideGames = side == "player1" ? games.0 : games.1
        let sideSets = side == "player1" ? sets.0 : sets.1
        for points in ["15", "30", "40"] {
            scorePoint(side, expectedPoints: points, games: sideGames, sets: sideSets, scoring: scoring)
        }
    }

    private func scorePoint(
        _ side: String,
        expectedPoints: String,
        games: Int,
        sets: Int,
        scoring: ScoringScreen
    ) {
        scoring.tapTennisScoreCard(side: side)
        scoring.waitForTennisState(side: side, points: expectedPoints, games: games, sets: sets)
    }

    private func endExistingPersonalMatchIfNeeded(
        setup: MatchSetupScreen,
        scoring: ScoringScreen
    ) -> Bool {
        guard setup.resumeActiveMatchButton.waitForExistence(timeout: 3) else { return false }

        checkpoint("Tennis-Recovery-01-Existing-Personal-Match")
        setup.resumeActiveMatchButton.tap()
        scoring.verifyLoaded(timeout: 20)
        XCTAssertTrue(scoring.actionButton.waitForExistence(timeout: 10))
        scoring.openActionMenu()
        XCTAssertTrue(scoring.endMatchEarlyButton.waitForExistence(timeout: 8))
        scoring.endMatchEarlyButton.tap()
        XCTAssertTrue(scoring.completedReturnButton.waitForExistence(timeout: 25))
        checkpoint("Tennis-Recovery-02-Existing-Personal-Match-Ended")
        scoring.completedReturnButton.tap()
        return true
    }

    private func checkpoint(_ name: String) {
        visualPause()
        captureScreenshot(name)
    }

    private func visualPause() {
        let environment = ProcessInfo.processInfo.environment
        let rawValue = environment["HITNSCORE_UI_TEST_STEP_DELAY"]
            ?? environment["TEST_RUNNER_HITNSCORE_UI_TEST_STEP_DELAY"]
            ?? "0.2"
        let delay = max(0, min(Double(rawValue) ?? 0.2, 5))
        RunLoop.current.run(until: Date().addingTimeInterval(delay))
    }
}
