import XCTest

final class RacketServiceSideTimelineUITests: HitnScoreBaseUITest {
    private let scenario = "racket-service-side-timeline"

    @MainActor
    func testManualLeftServeReplacesR2AndPersistsWhenServerScores() {
        launchApp(lightMode: false, scenario: scenario)
        rotatePortrait()

        let scoring = ScoringScreen(app: app)
        scoring.verifyLoaded()

        let scoreTwo = scoring.pointRailEntry(side: "player2", score: 2)
        XCTAssertTrue(scoreTwo.waitForExistence(timeout: 8))
        XCTAssertEqual(scoreTwo.label, "R2")
        captureScreenshot("Racket-Service-Side-01-Initial-R2")

        XCTAssertTrue(scoring.player2ServeSideButton.waitForExistence(timeout: 5))
        XCTAssertTrue(scoring.player2ServeSideButton.isEnabled)
        scoring.player2ServeSideButton.tap()

        waitForLabel("L2", on: scoreTwo)
        captureScreenshot("Racket-Service-Side-02-Corrected-L2")

        scoring.player2ScoreCard.tap()

        let scoreThree = scoring.pointRailEntry(side: "player2", score: 3)
        XCTAssertTrue(scoreThree.waitForExistence(timeout: 5))
        waitForLabel("R3", on: scoreThree)
        XCTAssertEqual(scoreTwo.label, "L2", "The corrected L2 entry must remain after the server wins the next point.")
        captureScreenshot("Racket-Service-Side-03-L2-Persists-With-R3")
    }

    private func waitForLabel(
        _ expectedLabel: String,
        on element: XCUIElement,
        timeout: TimeInterval = 5
    ) {
        let predicate = NSPredicate(format: "label == %@", expectedLabel)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
    }
}
