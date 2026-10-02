import Foundation

@main
enum RacketPointRailScenarioTests {
    static func main() {
        testManualSideChangeReplacesCurrentScore()
        testManualSideChangePersistsAfterNextPoint()
        testUnchangedCurrentServeIsNotDuplicated()
        testNextPointAppendsOneNewScore()
        testServiceTransferAppendsOneNewScore()
        testUndoStyleRollbackDoesNotRetainFutureEntry()
        print("Racket point-rail scenarios passed")
    }

    private static func testManualSideChangeReplacesCurrentScore() {
        let rightAtTwo = entry(id: "point-2", server: "player1", side: "R", score: "2")
        let leftAtTwo = entry(
            id: "current-player1-left",
            server: "player1",
            side: "L",
            score: "2",
            current: true
        )

        let result = RacketPointRailReducer.reconcile(history: [rightAtTwo], currentServe: leftAtTwo)

        check(result.count == 1, "manual R2 to L2 change must not add a second score")
        check(result[0].displaySideLabel == "L", "R2 must be replaced by L2")
        check(result[0].displayScore == "2", "manual side change must not change the score")
    }

    private static func testUnchangedCurrentServeIsNotDuplicated() {
        let rightAtTwo = entry(id: "point-2", server: "player1", side: "R", score: "2")
        let current = entry(
            id: "current-player1-right",
            server: "player1",
            side: "R",
            score: "2",
            current: true
        )

        let result = RacketPointRailReducer.reconcile(history: [rightAtTwo], currentServe: current)

        check(result == [rightAtTwo], "unchanged current serve must not be duplicated")
    }

    private static func testManualSideChangePersistsAfterNextPoint() {
        let rightAtTwo = entry(id: "point-2", server: "player1", side: "R", score: "2")
        let correctedHistory = RacketPointRailReducer.replacingLatestServiceSide(
            in: [rightAtTwo],
            sideLabel: "L",
            eventID: "serve-side-left"
        )
        let rightAtThree = entry(id: "point-3", server: "player1", side: "R", score: "3")
        let current = entry(
            id: "current-player1-right",
            server: "player1",
            side: "R",
            score: "3",
            current: true
        )

        let result = RacketPointRailReducer.reconcile(
            history: correctedHistory + [rightAtThree],
            currentServe: current
        )

        check(result.map(\.displaySideLabel) == ["L", "R"], "manual L2 correction must survive R3")
        check(result.map(\.displayScore) == ["2", "3"], "corrected history must survive later scoring")
    }

    private static func testNextPointAppendsOneNewScore() {
        let leftAtTwo = entry(id: "point-2", server: "player1", side: "L", score: "2")
        let rightAtThree = entry(
            id: "current-player1-right",
            server: "player1",
            side: "R",
            score: "3",
            current: true
        )

        let result = RacketPointRailReducer.reconcile(history: [leftAtTwo], currentServe: rightAtThree)

        check(result.map(\.displaySideLabel) == ["L", "R"], "server win should retain L2 and add R3")
        check(result.map(\.displayScore) == ["2", "3"], "server win should advance exactly once")
    }

    private static func testServiceTransferAppendsOneNewScore() {
        let playerOneAtThree = entry(id: "point-p1-3", server: "player1", side: "L", score: "3")
        let playerTwoAtEight = entry(
            id: "current-player2-right",
            server: "player2",
            side: "R",
            score: "8",
            current: true
        )

        let result = RacketPointRailReducer.reconcile(history: [playerOneAtThree], currentServe: playerTwoAtEight)

        check(result.count == 2, "service transfer must append the receiving player's score")
        check(result.last?.serverSide == "player2", "service transfer must move the server")
    }

    private static func testUndoStyleRollbackDoesNotRetainFutureEntry() {
        let rightAtOne = entry(id: "point-1", server: "player1", side: "R", score: "1")
        let leftAtTwo = entry(id: "point-2", server: "player1", side: "L", score: "2")
        let restoredCurrent = entry(
            id: "current-player1-left",
            server: "player1",
            side: "L",
            score: "2",
            current: true
        )

        let result = RacketPointRailReducer.reconcile(
            history: [rightAtOne, leftAtTwo],
            currentServe: restoredCurrent
        )

        check(result.count == 2, "restored state must not invent a future timeline entry")
        check(result.last?.displayScore == "2", "restored timeline must end at the restored score")
    }

    private static func entry(
        id: String,
        server: String,
        side: String,
        score: String,
        current: Bool = false
    ) -> RacketPointRailEntry {
        RacketPointRailEntry(
            id: id,
            serverSide: server,
            displaySide: server,
            displaySideLabel: side,
            displayScore: score,
            isCurrentServe: current
        )
    }

    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fatalError("Scenario failed: \(message)")
        }
    }
}
