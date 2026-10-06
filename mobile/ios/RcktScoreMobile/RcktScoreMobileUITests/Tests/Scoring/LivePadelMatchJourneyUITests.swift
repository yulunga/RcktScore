import XCTest

final class LivePadelMatchJourneyUITests: HitnScoreBaseUITest {
    @MainActor
    func testPersonalPlusCompletesStandardAndGoldenPointBestOfThreeJourneys() throws {
        let user = try TestUser.personalPlusFromEnvironment()
        launchApp(lightMode: true)
        rotatePortrait()

        let login = LoginScreen(app: app)
        let dashboard = DashboardScreen(app: app)
        let setup = MatchSetupScreen(app: app)
        let scoring = ScoringScreen(app: app)
        let settings = SettingsScreen(app: app)

        login.login(user: user)
        dismissPasswordSavePromptIfPresent()
        dashboard.verifyLoaded()
        checkpoint("Padel-01-Logged-In")

        openPadelSetup(dashboard: dashboard, setup: setup)
        if endExistingPersonalMatchIfNeeded(setup: setup, scoring: scoring) {
            openPadelSetup(dashboard: dashboard, setup: setup)
            XCTAssertFalse(
                setup.resumeActiveMatchButton.waitForExistence(timeout: 3),
                "The previously active personal match was ended, but it is still being offered for resume."
            )
        }

        configurePadelMatch(
            setup: setup,
            players: ("Paul", "Peter", "Mark", "Matt"),
            goldenPoint: false
        )
        checkpoint("Padel-02-Standard-Best-of-3-Setup")
        startPadelMatch(setup: setup, scoring: scoring)
        checkpoint("Padel-03-Standard-Match-Live")

        completeStandardDeuceGameForPlayer1(scoring: scoring)
        checkpoint("Padel-04-Standard-Deuce-Complete")
        completeStraightSetsAfterFirstGame(scoring: scoring)

        XCTAssertTrue(scoring.completedReturnButton.waitForExistence(timeout: 25))
        checkpoint("Padel-05-Standard-Complete-2-0")
        scoring.completedReturnButton.tap()

        XCTAssertTrue(dashboard.startNewMatchButton.waitForExistence(timeout: 12))
        openPadelSetup(dashboard: dashboard, setup: setup)
        configurePadelMatch(
            setup: setup,
            players: ("Alex", "Andy", "Ben", "Bob"),
            goldenPoint: true
        )
        checkpoint("Padel-06-Golden-Point-Best-of-3-Setup")
        startPadelMatch(setup: setup, scoring: scoring)
        checkpoint("Padel-07-Golden-Point-Match-Live")

        completeGoldenPointGameForPlayer1(scoring: scoring)
        checkpoint("Padel-08-Golden-Point-Complete")
        completeStraightSetsAfterFirstGame(scoring: scoring)

        XCTAssertTrue(scoring.completedReturnButton.waitForExistence(timeout: 25))
        checkpoint("Padel-09-Golden-Point-Match-Complete-2-0")
        scoring.completedReturnButton.tap()

        XCTAssertTrue(dashboard.settingsTab.waitForExistence(timeout: 12))
        dashboard.openSettings()
        settings.verifyLoaded()
        settings.logout()
        login.verifyLoaded()
        checkpoint("Padel-10-Logged-Out")
    }

    private func openPadelSetup(dashboard: DashboardScreen, setup: MatchSetupScreen) {
        dashboard.openStartNewMatch()
        XCTAssertTrue(
            setup.padelSportButton.waitForExistence(timeout: 8),
            "Padel must be enabled for the Personal Plus UI-test account."
        )
        setup.chooseSport(.padel)
        setup.verifySetupLoaded(timeout: 10)
        XCTAssertTrue(
            setup.player3FirstNameField.waitForExistence(timeout: 8),
            "Padel setup should require two players on each team."
        )
    }

    private func configurePadelMatch(
        setup: MatchSetupScreen,
        players: (String, String, String, String),
        goldenPoint: Bool
    ) {
        setup.enterDoublesPlayers(
            team1Player1: players.0,
            team1Player2: players.1,
            team2Player1: players.2,
            team2Player2: players.3
        )
        setup.selectBestOfThreeTennis()
        if goldenPoint {
            setup.enableTennisGoldenPoint()
        } else {
            setup.disableTennisGoldenPoint()
        }
        setup.disableTennisTimedBreaks()
        XCTAssertTrue(setup.startMatchButton.isEnabled)
    }

    private func startPadelMatch(setup: MatchSetupScreen, scoring: ScoringScreen) {
        setup.startMatchButton.tap()
        XCTAssertTrue(scoring.warmupSkipButton.waitForExistence(timeout: 20))
        scoring.warmupSkipButton.tap()
        chooseOpeningOrder(scoring)
        scoring.waitForTennisState(side: "player1", points: "0", games: 0, sets: 0)
        scoring.waitForTennisTimedBreaks(enabled: false)
    }

    private func chooseOpeningOrder(_ scoring: ScoringScreen) {
        XCTAssertTrue(scoring.tennisOpeningPlayer1ServerButton.waitForExistence(timeout: 8))
        scoring.tennisOpeningPlayer1ServerButton.tap()
        XCTAssertTrue(
            scoring.tennisOpeningPlayer2ReceiverButton.waitForExistence(timeout: 5),
            "Padel should require the receiving team to choose its opening receiver."
        )
        scoring.tennisOpeningPlayer2ReceiverButton.tap()
        XCTAssertTrue(scoring.tennisBeginMatchButton.isEnabled)
        scoring.tennisBeginMatchButton.tap()
    }

    private func completeStandardDeuceGameForPlayer1(scoring: ScoringScreen) {
        reachFortyAll(scoring: scoring)
        XCTAssertFalse(
            scoring.tennisNoAdReceiverChoice.exists,
            "Standard padel scoring must not show a Golden Point receiver choice."
        )
        scorePoint("player1", expectedPoints: "Ad", games: 0, sets: 0, scoring: scoring)
        scoring.tapTennisScoreCard(side: "player1")
        scoring.waitForTennisState(side: "player1", points: "0", games: 1, sets: 0)
    }

    private func completeGoldenPointGameForPlayer1(scoring: ScoringScreen) {
        reachFortyAll(scoring: scoring)
        XCTAssertTrue(
            scoring.tennisNoAdReceiverChoice.waitForExistence(timeout: 8),
            "Padel Golden Point should require the receiving team to choose a player at 40-40."
        )
        XCTAssertTrue(scoring.padelGoldenPointTeam2Player1ReceiverButton.waitForExistence(timeout: 5))
        XCTAssertTrue(scoring.padelGoldenPointTeam2Player2ReceiverButton.waitForExistence(timeout: 5))
        scoring.padelGoldenPointTeam2Player2ReceiverButton.tap()
        scoring.tapTennisScoreCard(side: "player1")
        scoring.waitForTennisState(side: "player1", points: "0", games: 1, sets: 0)
    }

    private func reachFortyAll(scoring: ScoringScreen) {
        for points in ["15", "30", "40"] {
            scorePoint("player1", expectedPoints: points, games: 0, sets: 0, scoring: scoring)
            scorePoint("player2", expectedPoints: points, games: 0, sets: 0, scoring: scoring)
        }
    }

    private func completeStraightSetsAfterFirstGame(scoring: ScoringScreen) {
        for completedGames in 2...5 {
            completeLoveGame(
                winner: "player1",
                games: (completedGames, 0),
                sets: (0, 0),
                scoring: scoring
            )
            if completedGames == 3 {
                assertNoTimedBreak(set: 1, scoring: scoring)
            }
        }

        scoreFirstThreePoints("player1", games: (5, 0), sets: (0, 0), scoring: scoring)
        scoring.tapTennisScoreCard(side: "player1")
        scoring.waitForTennisState(side: "player1", points: "0", games: 0, sets: 1)
        scoring.waitForTennisMode("standard", set: 2)
        assertNoTimedBreak(set: 1, scoring: scoring)

        for completedGames in 1...5 {
            completeLoveGame(
                winner: "player1",
                games: (completedGames, 0),
                sets: (1, 0),
                scoring: scoring
            )
            if completedGames == 3 {
                assertNoTimedBreak(set: 2, scoring: scoring)
            }
        }

        scoreFirstThreePoints("player1", games: (5, 0), sets: (1, 0), scoring: scoring)
        scoring.tapTennisScoreCard(side: "player1")
    }

    private func assertNoTimedBreak(set: Int, scoring: ScoringScreen) {
        XCTAssertFalse(
            scoring.intervalSkipButton.waitForExistence(timeout: 1),
            "Timed breaks are disabled, but an interval appeared during set \(set)."
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

        checkpoint("Padel-Recovery-01-Existing-Personal-Match")
        setup.resumeActiveMatchButton.tap()
        scoring.verifyLoaded(timeout: 20)
        XCTAssertTrue(scoring.actionButton.waitForExistence(timeout: 10))
        scoring.openActionMenu()
        XCTAssertTrue(scoring.endMatchEarlyButton.waitForExistence(timeout: 8))
        scoring.endMatchEarlyButton.tap()
        XCTAssertTrue(scoring.completedReturnButton.waitForExistence(timeout: 25))
        checkpoint("Padel-Recovery-02-Existing-Personal-Match-Ended")
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
