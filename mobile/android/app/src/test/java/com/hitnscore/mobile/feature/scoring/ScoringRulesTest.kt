package com.hitnscore.mobile.feature.scoring

import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchEvent
import com.hitnscore.mobile.data.model.MatchEventPayload
import com.hitnscore.mobile.data.model.MatchState
import com.hitnscore.mobile.feature.newmatch.Handicap
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ScoringRulesTest {
    private fun point(id: String, scorer: String, server: String, p1: Int, p2: Int, side: String = "right", game: Int = 1) = MatchEvent(
        id = id,
        eventType = "score_point",
        payload = MatchEventPayload(scorer = scorer, currentServerSide = server, serviceSide = side, player1Score = p1, player2Score = p2, gameNumber = game),
    )

    private fun match(events: List<MatchEvent>, p1: Int, p2: Int, server: String, side: String) = MatchDetail(
        id = "m1",
        player1Name = "Pat",
        player2Name = "Sam",
        player2Handedness = "left",
        status = "active",
        state = MatchState(player1Score = p1, player2Score = p2, currentServerSide = server, serviceSide = side, events = events),
    )

    @Test
    fun railShowsEachRallyThenTheLiveServe() {
        val events = listOf(point("e1", "player1", "player1", 1, 0), point("e2", "player2", "player2", 1, 1, side = "left"))
        val rail = ScoringRules.pointRail(match(events, 1, 1, "player2", "Right"))
        // Same server and score as the last rally but a new box: the live marker replaces it.
        assertEquals(listOf("player1", "player2"), rail.map { it.displaySide })
        assertEquals(listOf("1", "1"), rail.map { it.score })
        assertEquals(listOf("R", "R"), rail.map { it.sideLabel })
        assertTrue(rail.last().isCurrentServe)

        // A new point for the server adds a fresh live marker.
        val next = ScoringRules.pointRail(match(events, 1, 2, "player2", "Left"))
        assertEquals(3, next.size)
        assertEquals("2", next.last().score)
    }

    @Test
    fun serverMayChooseBoxOnlyAtHandIn() {
        val handIn = listOf(point("e1", "player2", "player2", 0, 1))
        assertTrue(ScoringRules.canServerChooseSide(handIn, "player2"))
        val holdsServe = handIn + point("e2", "player2", "player2", 0, 2)
        assertFalse(ScoringRules.canServerChooseSide(holdsServe, "player2"))
        assertTrue(ScoringRules.canServerChooseSide(emptyList(), "player1"))
    }

    @Test
    fun openingServiceSideFollowsReceiverHandedness() {
        val m = match(emptyList(), 0, 0, "player1", "Right")
        assertEquals("Left", ScoringRules.openingServiceSide(m, "player1"))
        assertEquals("Right", ScoringRules.openingServiceSide(m, "player2"))
    }

    @Test
    fun freshMatchAllowsOneStartEventAndHandicapOffsets() {
        val start = MatchEvent(id = "s", eventType = "match_started")
        val fresh = MatchDetail(id = "m", handicapEnabled = true, player1Offset = -2, player2Offset = 2, state = MatchState(player1Score = -2, player2Score = 2, events = listOf(start)))
        assertTrue(ScoringRules.isFresh(fresh))
        assertFalse(ScoringRules.isFresh(fresh.copy(state = fresh.state!!.copy(player1Score = -1))))
    }

    @Test
    fun handicapTableMatchesIos() {
        assertEquals(-3, Handicap.offset("A", "D"))
        assertEquals(3, Handicap.offset("D", "A"))
        assertEquals(0, Handicap.offset("G", "G"))
        assertEquals(0, Handicap.offset("A", ""))
    }
}
