package com.hitnscore.mobile.feature.scoring

import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchEvent

/** One marker on the squash/racketball point rail: service side and score, on the server's lane. */
data class RailEntry(
    val id: String,
    val serverSide: String?,
    /** "player1" or "player2": which lane the marker sits in. */
    val displaySide: String,
    /** "R", "L" or "-". */
    val sideLabel: String,
    val score: String,
    val isCurrentServe: Boolean,
)

/** Scoring rules ported from iOS `MatchScoringView` and `RacketPointRailReducer`. */
object ScoringRules {
    private val RALLY_EVENTS = setOf("score_point", "stroke")

    fun isComplete(match: MatchDetail): Boolean =
        match.state?.matchComplete == true || match.status.equals("completed", ignoreCase = true)

    fun isScheduled(match: MatchDetail): Boolean = match.status.equals("scheduled", ignoreCase = true)

    /** Nothing scored yet (handicap offsets count as the starting score). */
    fun isFresh(match: MatchDetail): Boolean {
        val state = match.state
        val p1Start = if (match.handicapEnabled) match.player1Offset else 0
        val p2Start = if (match.handicapEnabled) match.player2Offset else 0
        return (state?.currentGameNumber ?: 1) == 1 &&
            (state?.player1Score ?: p1Start) == p1Start &&
            (state?.player2Score ?: p2Start) == p2Start &&
            state?.gameHistory.isNullOrEmpty() &&
            (state?.events?.size ?: 0) <= 1
    }

    /** The receiver's handedness decides the opening service box, as iOS. */
    fun openingServiceSide(match: MatchDetail, serverSide: String): String {
        val receiverHandedness = if (serverSide == "player2") match.player1Handedness else match.player2Handedness
        return if (receiverHandedness.equals("left", ignoreCase = true)) "Left" else "Right"
    }

    /** The server may choose their box at the start of a hand-in, or after winning a game. */
    fun canServerChooseSide(events: List<MatchEvent>, serverSide: String): Boolean {
        val latestIndex = events.indexOfLast { it.eventType in RALLY_EVENTS }
        if (latestIndex < 0) return true
        val latest = events[latestIndex]
        val payload = latest.payload
        if (payload != null && payload.gameCompleted == true && payload.matchCompleted != true) return true
        val previousServer = serverBefore(events, latestIndex)
        val scorer = latest.payload?.scorer ?: latest.payload?.playerSide
        val serverAfterRally = latest.payload?.currentServerSide ?: scorer
        if (serverAfterRally != serverSide) return true
        return scorer != previousServer
    }

    private fun serverBefore(events: List<MatchEvent>, index: Int): String {
        for (i in index - 1 downTo 0) {
            val event = events[i]
            val side = event.payload?.currentServerSide
            if ((event.eventType == "server" || event.eventType in RALLY_EVENTS) && side != null) return side
        }
        return "player1"
    }

    /** Point-rail markers for the current game, ending with the live serve. */
    fun pointRail(match: MatchDetail): List<RailEntry> {
        val state = match.state ?: return emptyList()
        val history = mutableListOf<RailEntry>()
        for (event in state.events) {
            val p = event.payload
            if (p != null && event.eventType in RALLY_EVENTS && p.gameNumber == state.currentGameNumber) {
                val winner = p.scorer ?: p.playerSide
                val server = p.currentServerSide ?: winner
                val score = if (winner == "player1") {
                    p.gameResult?.player1Score ?: p.player1Score ?: 0
                } else {
                    p.gameResult?.player2Score ?: p.player2Score ?: 0
                }
                history += RailEntry(
                    id = event.id,
                    serverSide = server,
                    displaySide = winner ?: server ?: "player1",
                    sideLabel = p.serviceSide?.take(1)?.uppercase()?.ifEmpty { "-" } ?: "-",
                    score = score.toString(),
                    isCurrentServe = false,
                )
            } else if (event.eventType == "serve_side" && history.isNotEmpty()) {
                val label = (p?.side ?: p?.serviceSide ?: "Right").take(1).uppercase()
                history[history.lastIndex] = history.last().copy(id = event.id, sideLabel = label, isCurrentServe = true)
            }
        }
        val serverSide = state.currentServerSide ?: "player1"
        val current = RailEntry(
            id = "current-${match.id}-$serverSide-${state.serviceSide ?: "Right"}",
            serverSide = state.currentServerSide,
            displaySide = serverSide,
            sideLabel = state.serviceSide?.take(1)?.uppercase().orEmpty(),
            score = (if (serverSide == "player2") state.player2Score else state.player1Score).toString(),
            isCurrentServe = true,
        )
        val last = history.lastOrNull() ?: return listOf(current)
        if (last.serverSide != current.serverSide || last.score != current.score) return history + current
        if (last.sideLabel == current.sideLabel) return history
        return history.dropLast(1) + current
    }
}
