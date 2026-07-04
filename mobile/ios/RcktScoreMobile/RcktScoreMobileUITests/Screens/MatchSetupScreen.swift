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
}
