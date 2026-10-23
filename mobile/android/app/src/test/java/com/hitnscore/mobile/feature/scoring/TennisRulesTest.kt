package com.hitnscore.mobile.feature.scoring

import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchEvent
import com.hitnscore.mobile.data.model.MatchEventPayload
import com.hitnscore.mobile.data.model.MatchState
import com.hitnscore.mobile.data.model.TennisParticipant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TennisRulesTest {
    private val teams = mapOf(
        "player1" to listOf(TennisParticipant("team1_player1", "Ann", displayName = "Ann A"), TennisParticipant("team1_player2", "Bea", displayName = "Bea B")),
        "player2" to listOf(TennisParticipant("team2_player1", "Cat", displayName = "Cat C"), TennisParticipant("team2_player2", "Dee", displayName = "Dee D")),
    )
    private val doublesState = MatchState(teamFormat = "doubles", tennisTeams = teams, scoreType = 6)

    private fun match(sport: String, state: MatchState) =
        MatchDetail(id = "m1", sport = sport, player1Name = "Ann A / Bea B", player2Name = "Cat C / Dee D", state = state)

    @Test
    fun breaksFollowTheIosRules() {
        assertNull(TennisRules.breakSeconds(false, 3, false))
        assertNull(TennisRules.breakSeconds(true, 1, false))
        assertNull(TennisRules.breakSeconds(true, 2, false))
        assertEquals(90, TennisRules.breakSeconds(true, 3, false))
        assertEquals(120, TennisRules.breakSeconds(true, 6, true))
    }

    @Test
    fun doublesServeOrderAlternatesTeamsStartingWithTheServer() {
        assertEquals(
            listOf("team1_player2", "team2_player1", "team1_player1", "team2_player2"),
            TennisRules.openingServeOrder(doublesState, "team1_player2"),
        )
        assertEquals(
            mapOf("player2" to "team2_player2", "player1" to "team1_player1"),
            TennisRules.openingReceiverDeuceOrder(doublesState, "team1_player2", "team2_player2"),
        )
    }

    @Test
    fun openingChoicesDependOnDoubles() {
        val doubles = match("tennis", doublesState)
        assertEquals(4, TennisRules.openingServers(doubles).size)
        assertEquals(listOf("team2_player1", "team2_player2"), TennisRules.openingReceivers(doubles, "team1_player1").map { it.id })

        val singles = match("tennis", MatchState(teamFormat = "singles"))
        assertEquals(listOf("team1_player1", "team2_player1"), TennisRules.openingServers(singles).map { it.id })
        assertEquals(listOf("team1_player1"), TennisRules.openingReceivers(singles, "team2_player1").map { it.id })
    }

    @Test
    fun padelGoldenPointWaitsForTheReceiverChoice() {
        val atDeuce = doublesState.copy(tennisNoAdScoring = true, player1Score = 3, player2Score = 3, currentServerSide = "player1")
        assertTrue(TennisRules.requiresReceiverChoice(match("padel", atDeuce)))
        assertFalse(TennisRules.requiresReceiverChoice(match("tennis", atDeuce)))
        assertFalse(TennisRules.requiresReceiverChoice(match("padel", atDeuce.copy(noAdDecidingSide = "Right"))))
        val receivers = TennisRules.goldenPointReceivers(atDeuce)
        assertEquals("Right", TennisRules.receiverCourt(atDeuce, receivers[0]))
        assertEquals("Left", TennisRules.receiverCourt(atDeuce, receivers[1]))
    }

    @Test
    fun timelineMarksCompletedGames() {
        val events = listOf(
            MatchEvent("e1", "score_point", MatchEventPayload(scorer = "player1", pointPlayer1ScoreLabel = "15")),
            MatchEvent("e2", "let", MatchEventPayload(playerSide = "player1")),
            MatchEvent(
                "e3",
                "score_point",
                MatchEventPayload(scorer = "player2", tennisGameCompleted = true, completedGamePlayer1Games = 0, completedGamePlayer2Games = 1),
            ),
        )
        val points = TennisRules.timeline(MatchState(events = events))
        assertEquals(2, points.size)
        assertEquals("15", points[0].label)
        assertEquals("Game", points[1].label)
        assertEquals("0–1", points[1].gameScore)
    }
}
