import Foundation

@main
enum TennisScoringReducerScenarioTests {
    static func main() {
        testDeuceAndNoAd()
        testStandardAndLongTiebreak()
        testFinalSetMatchTiebreakAndCompletion()
        testSinglesAndDoublesServiceRotation()
        testUndoSnapshotAndOfflineReplay()
        print("TennisScoringReducer scenarios passed")
    }

    private static func testDeuceAndNoAd() {
        let match = makeMatch()
        var advantage = MutableMatchState(makeState(player1Score: 3, player2Score: 3))
        TennisScoringReducer.applyPoint(to: &advantage, scoringSide: "player1", match: match)
        check(advantage.player1ScoreLabel == "Ad", "advantage point")
        TennisScoringReducer.applyPoint(to: &advantage, scoringSide: "player2", match: match)
        check(advantage.player1ScoreLabel == "40" && advantage.player2ScoreLabel == "40", "return to deuce")

        var noAd = MutableMatchState(makeState(player1Score: 3, player2Score: 3, noAd: true))
        TennisScoringReducer.applyPoint(to: &noAd, scoringSide: "player1", match: match)
        check(noAd.player1Score == 3, "No-Ad blocks scoring until receiver choice")
        TennisScoringReducer.applyReceiverChoice(to: &noAd, side: "Left", match: match)
        TennisScoringReducer.applyPoint(to: &noAd, scoringSide: "player1", match: match)
        check(noAd.player1SetGames == 1 && noAd.player1Score == 0, "No-Ad deciding point wins game")
    }

    private static func testStandardAndLongTiebreak() {
        let match = makeMatch()
        var state = MutableMatchState(makeState(player1Score: 3, player1SetGames: 5, player2SetGames: 6))
        TennisScoringReducer.applyPoint(to: &state, scoringSide: "player1", match: match)
        check(state.isTieBreak && !state.isMatchTiebreak, "6-6 starts standard tiebreak")
        state.player1Score = 7
        state.player2Score = 7
        TennisScoringReducer.applyPoint(to: &state, scoringSide: "player1", match: match)
        check(!state.matchComplete && state.player1Score == 8, "long tiebreak requires two clear")
    }

    private static func testFinalSetMatchTiebreakAndCompletion() {
        let match = makeMatch()
        var state = MutableMatchState(makeState(
            player1Score: 3,
            player1Sets: 0,
            player2Sets: 1,
            player1SetGames: 5,
            finalSetTiebreak: true
        ))
        TennisScoringReducer.applyPoint(to: &state, scoringSide: "player1", match: match)
        check(state.isTieBreak && state.isMatchTiebreak, "deciding set replaced with match tiebreak")
        state.player1Score = 9
        state.player2Score = 8
        TennisScoringReducer.applyPoint(to: &state, scoringSide: "player1", match: match)
        check(state.matchComplete && state.winnerName == "Alex", "10-point match tiebreak completes match")
    }

    private static func testSinglesAndDoublesServiceRotation() {
        let match = makeMatch()
        var singles = MutableMatchState(makeState(player1Score: 3, player1SetGames: 5))
        TennisScoringReducer.applyPoint(to: &singles, scoringSide: "player1", match: match)
        check(singles.currentServerSide == "player1", "even-game set keeps next-set server rotation")

        var doublesState = makeState(player1Score: 3, player1SetGames: 5)
        doublesState = replacingTeams(
            in: doublesState,
            teams: [
                "player1": [participant("team1_player1", "Alex"), participant("team1_player2", "Casey")],
                "player2": [participant("team2_player1", "Blair"), participant("team2_player2", "Drew")],
            ],
            order: ["team1_player1", "team2_player1", "team1_player2", "team2_player2"]
        )
        var doubles = MutableMatchState(doublesState)
        TennisScoringReducer.applyPoint(to: &doubles, scoringSide: "player1", match: match)
        check(doubles.currentServerParticipantID == "team1_player2", "doubles service rotation crosses set boundary")
    }

    private static func testUndoSnapshotAndOfflineReplay() {
        let match = makeMatch()
        let serverState = makeState()
        var projected = MutableMatchState(serverState)
        var snapshots = [serverState]
        for side in ["player1", "player2", "player1"] {
            TennisScoringReducer.applyPoint(to: &projected, scoringSide: side, match: match)
            snapshots.append(projected.value)
        }
        check(projected.player1Score == 2 && projected.player2Score == 1, "offline replay applies actions in order")
        snapshots.removeLast()
        check(snapshots.last?.player1Score == 1 && snapshots.last?.player2Score == 1, "undo restores preceding snapshot")
    }

    private static func makeMatch() -> MatchDetail {
        MatchDetail(
            id: "match-1", courtName: "Court 1", courtAlias: nil, courtDisplayCode: nil,
            sport: "tennis", player1Name: "Alex", player1Surname: nil,
            player1Handedness: "right", player1ShirtColor: "navy",
            player2Name: "Blair", player2Surname: nil, player2Handedness: "right",
            player2ShirtColor: "white", refereeName: nil, scoreType: 6, bestOf: 3,
            handicapEnabled: false, player1Offset: 0, player2Offset: 0,
            player1Band: nil, player2Band: nil, status: "active", autoScheduled: nil,
            autoScheduleReason: nil, createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z", completedAt: nil,
            matchDurationSeconds: 0, state: nil
        )
    }

    private static func makeState(
        player1Score: Int = 0,
        player2Score: Int = 0,
        player1Sets: Int = 0,
        player2Sets: Int = 0,
        player1SetGames: Int = 0,
        player2SetGames: Int = 0,
        noAd: Bool = false,
        finalSetTiebreak: Bool = false
    ) -> MatchState {
        let teams = [
            "player1": [participant("team1_player1", "Alex")],
            "player2": [participant("team2_player1", "Blair")],
        ]
        return MatchState(
            player1Score: player1Score, player2Score: player2Score,
            player1GamesWon: player1Sets, player2GamesWon: player2Sets,
            player1SetGames: player1SetGames, player2SetGames: player2SetGames,
            currentGameNumber: player1Sets + player2Sets + 1, bestOf: 3, scoreType: 6,
            currentServer: "Alex", currentServerSide: "player1", serviceSide: "Right",
            player1ShirtColor: "navy", player2ShirtColor: "white", scoreDisplayMode: "tennis",
            player1ScoreLabel: label(player1Score), player2ScoreLabel: label(player2Score),
            isTieBreak: false, teamFormat: "singles", tennisTeams: teams,
            currentServerParticipantID: "team1_player1", currentReceiver: "Blair",
            currentReceiverSide: "player2", currentReceiverParticipantID: "team2_player1",
            teamServiceOrder: ["player1": ["team1_player1"], "player2": ["team2_player1"]],
            serveOrder: ["team1_player1", "team2_player1"],
            receiverDeuceOrder: ["player1": "team1_player1", "player2": "team2_player1"],
            tieBreakFirstServerSide: nil, tieBreakFirstServerParticipantID: nil,
            handicap: nil, matchDurationSeconds: 0, gameHistory: [], matchComplete: false,
            winnerName: nil, events: [], tennisNoAdScoring: noAd,
            tennisFinalSetMatchTiebreak: finalSetTiebreak
        )
    }

    private static func replacingTeams(in state: MatchState, teams: [String: [TennisParticipant]], order: [String]) -> MatchState {
        var mutable = MutableMatchState(state)
        mutable.teamFormat = "doubles"
        mutable.tennisTeams = teams
        mutable.teamServiceOrder = [
            "player1": teams["player1"]!.map(\.id),
            "player2": teams["player2"]!.map(\.id),
        ]
        mutable.serveOrder = order
        mutable.receiverDeuceOrder = ["player1": order[0], "player2": order[1]]
        return mutable.value
    }

    private static func participant(_ id: String, _ name: String) -> TennisParticipant {
        TennisParticipant(id: id, firstName: name, surname: nil, displayName: name)
    }

    private static func label(_ value: Int) -> String { ["0", "15", "30", "40"][min(value, 3)] }

    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fatalError("Scenario failed: \(message)")
        }
    }
}
