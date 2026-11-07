package com.hitnscore.mobile.feature.scoring.offline

import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchHandicap
import com.hitnscore.mobile.data.model.MatchState
import com.hitnscore.mobile.data.model.TennisParticipant
import com.hitnscore.mobile.feature.scoring.TennisRules
import com.hitnscore.mobile.feature.scoring.TennisScoringReducer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OfflineScoringReducerTest {
    private val squash = MatchDetail(id = "m1", sport = "squash", player1Name = "Ann", player2Name = "Bea")
    private val squashState = MatchState(scoreType = 11, bestOf = 3, currentServerSide = "player1", serviceSide = "Right")

    private fun point(state: MatchState, side: String, match: MatchDetail = squash) =
        OfflineScoringReducer.apply(OfflineMatchAction(matchId = match.id, kind = OfflineActionKind.ScorePoint, scorer = side), state, match)

    @Test
    fun serverWinningARallyChangesServiceBox() {
        val next = point(squashState, "player1")
        assertEquals(1, next.player1Score)
        assertEquals("Left", next.serviceSide)
        assertEquals("player1", next.currentServerSide)
        assertEquals(1, next.events.size)
        assertEquals("score_point", next.events.single().eventType)
    }

    @Test
    fun receiverWinningTakesServeFromTheRightBox() {
        val next = point(squashState.copy(serviceSide = "Left"), "player2")
        assertEquals("player2", next.currentServerSide)
        assertEquals("Right", next.serviceSide)
    }

    @Test
    fun gameEndsAtElevenWithATwoPointLead() {
        val atTen = squashState.copy(player1Score = 10, player2Score = 9)
        val game = point(atTen, "player1")
        assertEquals(1, game.player1GamesWon)
        assertEquals(1, game.gameHistory.size)
        assertEquals(0, game.player1Score)
        assertEquals(2, game.currentGameNumber)
        assertTrue(game.events.last().payload?.gameCompleted == true)

        val deuce = point(squashState.copy(player1Score = 10, player2Score = 10), "player1")
        assertEquals(11, deuce.player1Score)
        assertEquals(0, deuce.player1GamesWon)
    }

    @Test
    fun handicapOffsetsReturnAtTheStartOfEachGame() {
        val state = squashState.copy(
            scoreType = 15,
            player1Score = 14,
            player2Score = 3,
            handicap = MatchHandicap(enabled = true, player1Offset = -2, player2Offset = 2),
        )
        val next = point(state, "player1")
        assertEquals(-2, next.player1Score)
        assertEquals(2, next.player2Score)
    }

    @Test
    fun matchEndsWhenEnoughGamesAreWon() {
        val next = point(squashState.copy(player1GamesWon = 1, player1Score = 10, player2Score = 3), "player1")
        assertTrue(next.matchComplete)
        assertEquals("Ann", next.winnerName)
    }

    @Test
    fun letChangesNothingButIsRecorded() {
        val next = OfflineScoringReducer.apply(OfflineMatchAction(matchId = "m1", kind = OfflineActionKind.Let, note = "General let"), squashState, squash)
        assertEquals(squashState.copy(events = next.events), next)
        assertEquals("let", next.events.single().eventType)
    }

    // Tennis and Padel -------------------------------------------------------

    private val teams = mapOf(
        "player1" to listOf(TennisParticipant("team1_player1", "Ann", displayName = "Ann A")),
        "player2" to listOf(TennisParticipant("team2_player1", "Bea", displayName = "Bea B")),
    )
    private val tennis = MatchDetail(id = "t1", sport = "tennis", player1Name = "Ann A", player2Name = "Bea B")
    private val tennisState = MatchState(
        scoreType = 6,
        bestOf = 3,
        teamFormat = "singles",
        tennisTeams = teams,
        serveOrder = listOf("team1_player1", "team2_player1"),
        currentServerParticipantId = "team1_player1",
        currentServerSide = "player1",
        serviceSide = "Right",
    )

    @Test
    fun tennisPointsCountFifteenThirtyFortyGame() {
        var state = tennisState
        val labels = mutableListOf<String?>()
        repeat(3) {
            state = point(state, "player1", tennis)
            labels += state.player1ScoreLabel
        }
        assertEquals(listOf("15", "30", "40"), labels)
        state = point(state, "player1", tennis)
        assertEquals(1, state.player1SetGames)
        assertEquals("player2", state.currentServerSide)
        assertEquals("Game", state.events.last().payload?.pointPlayer1ScoreLabel)
        assertTrue(TennisRules.timeline(state).last().isGame)
    }

    @Test
    fun deuceNeedsAdvantageWithoutGoldenPoint() {
        val deuce = tennisState.copy(player1Score = 3, player2Score = 3)
        val ad = TennisScoringReducer.applyPoint(deuce, "player2", tennis)
        assertEquals("Ad", ad.player2ScoreLabel)
        assertEquals(0, ad.player2SetGames)
        val back = TennisScoringReducer.applyPoint(ad, "player1", tennis)
        assertEquals("40", back.player1ScoreLabel)
        assertEquals("40", back.player2ScoreLabel)
    }

    @Test
    fun goldenPointWinsTheGameAtDeuce() {
        val deuce = tennisState.copy(player1Score = 3, player2Score = 3, tennisNoAdScoring = true)
        val next = TennisScoringReducer.applyPoint(deuce, "player2", tennis)
        assertEquals(1, next.player2SetGames)
    }

    @Test
    fun sixAllStartsATiebreak() {
        val state = tennisState.copy(player1SetGames = 6, player2SetGames = 5, player1Score = 0, player2Score = 3)
        val next = TennisScoringReducer.applyPoint(state, "player2", tennis)
        assertTrue(next.isTieBreak)
        assertEquals(6, next.player2SetGames)
        assertEquals("0", next.player1ScoreLabel)
    }

    @Test
    fun tiebreakToSevenWinsTheSet() {
        val state = tennisState.copy(isTieBreak = true, player1SetGames = 6, player2SetGames = 6, player1Score = 6, player2Score = 4)
        val next = TennisScoringReducer.applyPoint(state, "player1", tennis)
        assertFalse(next.isTieBreak)
        assertEquals(1, next.player1GamesWon)
        assertEquals(7, next.gameHistory.single().player1Score)
        assertEquals(2, next.currentGameNumber)
    }

    @Test
    fun padelGoldenPointWaitsForTheReceiverChoice() {
        val padel = tennis.copy(id = "p1", sport = "padel")
        val deuce = tennisState.copy(player1Score = 3, player2Score = 3, tennisNoAdScoring = true)
        assertEquals(deuce, TennisScoringReducer.applyPoint(deuce, "player1", padel))
        val chosen = TennisScoringReducer.applyReceiverChoice(deuce, "Left", padel)
        assertEquals("Left", chosen.noAdDecidingSide)
        val won = TennisScoringReducer.applyPoint(chosen, "player1", padel)
        assertEquals(1, won.player1SetGames)
        assertNull(won.noAdDecidingSide)
    }
}
