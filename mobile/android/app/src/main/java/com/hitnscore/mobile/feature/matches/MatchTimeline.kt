package com.hitnscore.mobile.feature.matches

import com.hitnscore.mobile.data.model.GameHistoryEntry
import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchEvent
import com.hitnscore.mobile.data.model.MatchFormatting
import java.time.Instant

/** One point (or stroke / let) row in the historic timeline. */
data class TimelineEntry(
    val id: String,
    val score: String?,
    val timestamp: Instant?,
    /** "player1" or "player2". */
    val winnerSide: String,
    val serverSide: String?,
    /** "R" or "L" service side initial, squash/racketball only. */
    val serviceSideLabel: String,
    val tennisGameCompleted: Boolean,
    val setCompleted: Boolean,
    val completedGameScore: String?,
    val matchCompleted: Boolean,
)

data class TimelineGame(
    val gameNumber: Int,
    val result: GameHistoryEntry?,
    val entries: List<TimelineEntry>,
    val durationSeconds: Int?,
    /** Cumulative games score after this game, e.g. "2–1" (squash/racketball). */
    val gamesScoreAfter: String,
)

/**
 * Historic-match timeline grouped by game (or set for tennis/Padel), ported from
 * iOS `HistoricMatchView`. Built once per match, off the drawing path.
 */
data class MatchTimeline(
    val isTennisStyle: Boolean,
    val games: List<TimelineGame>,
    /** The greater of the recorded total and the sum of game durations. */
    val totalDurationSeconds: Int,
) {
    companion object {
        private val POINT_EVENTS = setOf("score_point", "stroke", "let")

        fun from(match: MatchDetail): MatchTimeline {
            val state = match.state
            val tennis = MatchFormatting.isTennisStyle(match.sport, state)
            val history = state?.gameHistory.orEmpty()
            val grouped = state?.events.orEmpty()
                .filter { it.eventType in POINT_EVENTS }
                .groupBy { it.payload?.gameNumber ?: 1 }
            val gameNumbers = (grouped.keys + history.map { it.gameNumber }).toSortedSet()

            val games = gameNumbers.map { number ->
                val entries = grouped[number].orEmpty()
                    .sortedBy { it.createdAt.orEmpty() }
                    .map { it.toEntry(tennis) }
                val times = entries.mapNotNull { it.timestamp }
                val duration = if (times.isEmpty()) {
                    null
                } else {
                    (times.last().epochSecond - times.first().epochSecond).toInt().coerceAtLeast(0)
                }
                val completedSoFar = history.filter { it.gameNumber <= number }
                TimelineGame(
                    gameNumber = number,
                    result = history.firstOrNull { it.gameNumber == number },
                    entries = entries,
                    durationSeconds = duration,
                    gamesScoreAfter = "${completedSoFar.count { it.player1Score > it.player2Score }}" +
                        "–${completedSoFar.count { it.player2Score > it.player1Score }}",
                )
            }
            val recorded = match.matchDurationSeconds ?: state?.matchDurationSeconds ?: 0
            val derived = games.sumOf { it.durationSeconds ?: 0 }
            return MatchTimeline(tennis, games, maxOf(recorded, derived, 0))
        }

        private fun MatchEvent.toEntry(tennis: Boolean): TimelineEntry {
            val p = payload
            return TimelineEntry(
                id = id,
                score = scoreLine(this, tennis),
                timestamp = MatchFormatting.parseInstant(createdAt),
                winnerSide = p?.scorer ?: p?.playerSide ?: "player1",
                serverSide = p?.currentServerSide,
                serviceSideLabel = p?.serviceSide?.take(1)?.uppercase().orEmpty(),
                tennisGameCompleted = p?.tennisGameCompleted == true,
                setCompleted = p?.setCompleted == true,
                completedGameScore = if (p?.completedGamePlayer1Games != null && p.completedGamePlayer2Games != null) {
                    "${p.completedGamePlayer1Games}-${p.completedGamePlayer2Games}"
                } else {
                    null
                },
                matchCompleted = p?.matchCompleted == true,
            )
        }

        private fun scoreLine(event: MatchEvent, tennis: Boolean): String? {
            val p = event.payload ?: return null
            if (tennis) {
                if (p.pointPlayer1ScoreLabel != null && p.pointPlayer2ScoreLabel != null) {
                    return "${p.pointPlayer1ScoreLabel}-${p.pointPlayer2ScoreLabel}"
                }
                if (p.pointPlayer1Score != null && p.pointPlayer2Score != null) {
                    return tennisScore(p.pointPlayer1Score, p.pointPlayer2Score, p.isTieBreak == true)
                }
            }
            val one = p.gameResult?.player1Score ?: p.player1Score ?: return null
            val two = p.gameResult?.player2Score ?: p.player2Score ?: return null
            return "$one-$two"
        }

        fun tennisScore(player1: Int, player2: Int, tieBreak: Boolean): String {
            if (tieBreak) return "$player1-$player2"
            val labels = listOf("0", "15", "30", "40")
            if (player1 >= 3 && player2 >= 3) {
                return when {
                    player1 == player2 -> "Deuce"
                    player1 > player2 -> "Advantage-40"
                    else -> "40-Advantage"
                }
            }
            return "${labels[minOf(player1, 3)]}-${labels[minOf(player2, 3)]}"
        }
    }
}
