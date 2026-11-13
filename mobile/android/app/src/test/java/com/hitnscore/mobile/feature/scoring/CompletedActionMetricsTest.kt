package com.hitnscore.mobile.feature.scoring

import com.hitnscore.mobile.data.model.MatchEvent
import com.hitnscore.mobile.data.model.MatchEventPayload
import org.junit.Assert.assertEquals
import org.junit.Test

class CompletedActionMetricsTest {
    private fun event(type: String, scorer: String? = null, pointServer: String? = null, currentServer: String? = null, side: String? = null) =
        MatchEvent(id = type + scorer + pointServer, eventType = type, payload = MatchEventPayload(scorer = scorer, playerSide = side, pointServerSide = pointServer, currentServerSide = currentServer))

    @Test
    fun countsServesStrokesAndLets() {
        val metrics = completedActionMetrics(
            listOf(
                event("score_point", scorer = "player1", pointServer = "player1"),
                event("score_point", scorer = "player2", pointServer = "player1"),
                event("score_point", scorer = "player2", pointServer = "player2"),
                // Falls back to the current server when the point server is missing.
                event("score_point", scorer = "player1", currentServer = "player2"),
                // A stroke awards the point to player_side.
                event("stroke", side = "player1", pointServer = "player1"),
                event("let", side = "player2"),
                event("undo"),
            ),
        )
        assertEquals(CompletedActionMetrics(player1ServeWon = 2, player1ServeLost = 1, player2ServeWon = 1, player2ServeLost = 1, strokes = 1, lets = 1), metrics)
    }
}
