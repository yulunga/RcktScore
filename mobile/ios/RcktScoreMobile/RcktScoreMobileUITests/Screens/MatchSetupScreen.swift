import XCTest

struct MatchSetupScreen {

    enum Sport: String {
        case squash
        case racketball
        case tennis
    }

    let app: XCUIApplication

    var squashSportButton: XCUIElement {
        app.buttons["startMatch.sport.squash"]
    }

    var racketballSportButton: XCUIElement {
        app.buttons["startMatch.sport.racketball"]
    }

    var tennisSportButton: XCUIElement {
        app.buttons["startMatch.sport.tennis"]
    }

    var setupCloseButton: XCUIElement {
        app.buttons["startMatch.setup.closeButton"]
    }

    var player1FirstNameField: XCUIElement {
        app.textFields["startMatch.player1.firstNameField"]
    }

    var player1SurnameField: XCUIElement {
        app.textFields["startMatch.player1.surnameField"]
    }

    var player2FirstNameField: XCUIElement {
        app.textFields["startMatch.player2.firstNameField"]
    }

    var player2SurnameField: XCUIElement {
        app.textFields["startMatch.player2.surnameField"]
    }

    var player3FirstNameField: XCUIElement {
        app.textFields["startMatch.player3.firstNameField"]
    }

    var player4FirstNameField: XCUIElement {
        app.textFields["startMatch.player4.firstNameField"]
    }

    var courtPicker: XCUIElement {
        app.buttons["startMatch.courtPicker"]
    }

    var startMatchButton: XCUIElement {
        app.buttons["startMatch.startButton"]
    }

    var bestOfPicker: XCUIElement {
        app.buttons["startMatch.bestOfPicker"]
    }

    var scoreTypePicker: XCUIElement {
        app.buttons["startMatch.scoreTypePicker"]
    }

    var resumeActiveMatchButton: XCUIElement {
        app.buttons["startMatch.resumeActiveMatchButton"]
    }

    var singlesButton: XCUIElement {
        app.buttons["startMatch.matchType.singles"]
    }

    var doublesButton: XCUIElement {
        app.buttons["startMatch.matchType.doubles"]
    }

    var scheduleToggle: XCUIElement {
        app.switches["startMatch.scheduleToggle"]
    }

    var handicapToggle: XCUIElement {
        app.switches["startMatch.handicapToggle"]
    }

    func chooseSport(_ sport: Sport) {
        switch sport {
        case .squash:
            squashSportButton.tap()
        case .racketball:
            racketballSportButton.tap()
        case .tennis:
            tennisSportButton.tap()
        }
    }

    func verifySetupLoaded(timeout: TimeInterval = 5) {
        XCTAssertTrue(startMatchButton.waitForExistence(timeout: timeout))
    }

    func createSinglesMatch(player1FirstName: String, player2FirstName: String, player1Surname: String = "", player2Surname: String = "") {
        verifySetupLoaded()

        player1FirstNameField.tap()
        player1FirstNameField.typeText(player1FirstName)

        if !player1Surname.isEmpty {
            player1SurnameField.tap()
            player1SurnameField.typeText(player1Surname)
        }

        player2FirstNameField.tap()
        player2FirstNameField.typeText(player2FirstName)

        if !player2Surname.isEmpty {
            player2SurnameField.tap()
            player2SurnameField.typeText(player2Surname)
        }

        startMatchButton.tap()
    }

    func selectBestOfOneScoreToEleven() {
        scrollToElement(bestOfPicker)
        XCTAssertTrue(bestOfPicker.waitForExistence(timeout: 5))
        bestOfPicker.tap()
        app.buttons["Best of 1"].tap()

        XCTAssertTrue(scoreTypePicker.waitForExistence(timeout: 5))
        scoreTypePicker.tap()
        app.buttons["PAR-11"].tap()
    }

    func enterPlayers(player1: String, player2: String) {
        scrollToElement(player1FirstNameField)
        replaceText(in: player1FirstNameField, with: player1)
        dismissKeyboard()
        scrollToElement(player2FirstNameField)
        replaceText(in: player2FirstNameField, with: player2)
        dismissKeyboard()
        scrollToElement(startMatchButton)
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()

        if !waitForKeyboardFocus(on: field, timeout: 1.5) {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        }

        XCTAssertTrue(
            waitForKeyboardFocus(on: field, timeout: 3),
            "Unable to give keyboard focus to \(field.identifier)."
        )

        if let currentValue = field.value as? String, !currentValue.isEmpty, currentValue != field.placeholderValue {
            field.press(forDuration: 0.8)
            app.menuItems["Select All"].tapIfExists()
            field.typeText(text)
        } else {
            field.typeText(text)
        }
    }

    private func waitForKeyboardFocus(on field: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "hasKeyboardFocus == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: field)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func dismissKeyboard() {
        guard app.keyboards.firstMatch.exists else {
            return
        }

        let returnButton = app.keyboards.buttons["Return"].firstMatch
        if returnButton.exists && returnButton.isHittable {
            returnButton.tap()
        }

        let keyboardGone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(
            predicate: keyboardGone,
            object: app.keyboards.firstMatch
        )
        _ = XCTWaiter.wait(for: [expectation], timeout: 2)
    }

    private func scrollToElement(_ element: XCUIElement, attempts: Int = 10) {
        for _ in 0..<attempts where !element.isHittable {
            if element.exists && element.frame.minY < 100 {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
        }
        XCTAssertTrue(element.isHittable)
    }
}

private extension XCUIElement {
    func tapIfExists() {
        if exists && isHittable {
            tap()
        }
    }
}
