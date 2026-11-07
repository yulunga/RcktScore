package com.hitnscore.mobile.feature.scoring.offline

import com.hitnscore.mobile.data.model.GameHistoryEntry
import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchEvent
import com.hitnscore.mobile.data.model.MatchEventPayload
import com.hitnscore.mobile.data.model.MatchState
import com.hitnscore.mobile.feature.scoring.TennisRules
import com.hitnscore.mobile.feature.scoring.TennisScoringReducer
import java.time.Instant

/**
 * Projects a queued action onto the scoreboard, as iOS `OfflineScoringReducer`.
 * Squash/racketball points use the rally-scoring rules below; tennis and Padel use
 * [TennisScoringReducer]. Each action also adds a local event so the point rail,
 * the tennis timeline and the break timers react before the server confirms it.
 */
object OfflineScoringReducer {

    fun apply(action: OfflineMatchAction, state: MatchState, match: MatchDetail): MatchState {
        val tennis = TennisRules.isTennis(match)
        var next = when (action.kind) {
            OfflineActionKind.ScorePoint, OfflineActionKind.Stroke -> {
                val scoringSide = action.scorer ?: action.playerSide ?: "player1"
                if (tennis) TennisScoringReducer.applyPoint(state, scoringSide, match) else applyRacketPoint(state, scoringSide, match)
            }
            OfflineActionKind.Let, OfflineActionKind.Undo -> state
            OfflineActionKind.ServeSide -> state.copy(serviceSide = action.side ?: state.serviceSide)
            OfflineActionKind.ReceiverChoice -> TennisScoringReducer.applyReceiverChoice(state, action.side ?: "Right", match)
            OfflineActionKind.Server -> state.copy(
                currentServer = action.currentServer ?: state.currentServer,
                currentServerSide = action.currentServerSide ?: state.currentServerSide,
                serviceSide = action.serviceSide ?: state.serviceSide,
                currentServerParticipantId = action.currentServerParticipantId ?: state.currentServerParticipantId,
                currentReceiver = action.currentReceiver ?: state.currentReceiver,
                currentReceiverSide = action.currentReceiverSide ?: state.currentReceiverSide,
                currentReceiverParticipantId = action.currentReceiverParticipantId ?: state.currentReceiverParticipantId,
                serveOrder = action.serveOrder ?: state.serveOrder,
                receiverDeuceOrder = action.receiverDeuceOrder ?: state.receiverDeuceOrder,
            )
            OfflineActionKind.Timer -> state.copy(matchDurationSeconds = action.matchDurationSeconds ?: state.matchDurationSeconds)
            OfflineActionKind.EndMatch -> state.copy(
                matchComplete = true,
                matchDurationSeconds = action.matchDurationSeconds ?: state.matchDurationSeconds,
                winnerName = when {
                    state.player1GamesWon > state.player2GamesWon -> match.player1Name
                    state.player2GamesWon > state.player1GamesWon -> match.player2Name
                    else -> state.winnerName
                },
            )
            OfflineActionKind.MatchSettings -> state.copy(
                scoreType = action.scoreType ?: state.scoreType,
                bestOf = action.bestOf ?: state.bestOf,
                player1ShirtColor = action.player1ShirtColor ?: state.player1ShirtColor,
                player2ShirtColor = action.player2ShirtColor ?: state.player2ShirtColor,
            )
        }
        if (action.kind != OfflineActionKind.Undo) next = withLocalEvent(action, next, state, match, tennis)
        return next
    }

    /** Squash/racketball point-a-rally scoring, mirroring iOS `applyRacketPoint`. */
    internal fun applyRacketPoint(state: MatchState, scoringSide: String, match: MatchDetail): MatchState {
        if (state.matchComplete) return state
        val previousServer = state.currentServerSide ?: "player1"
        val p1 = state.player1Score + (if (scoringSide == "player1") 1 else 0)
        val p2 = state.player2Score + (if (scoringSide == "player2") 1 else 0)
        val serviceSide = if (scoringSide == previousServer) {
            if ((state.serviceSide ?: "Right").equals("right", ignoreCase = true)) "Left" else "Right"
        } else {
            serviceSideForReceiver(match, scoringSide)
        }
        val scorerName = if (scoringSide == "player1") match.player1Name else match.player2Name
        var next = state.copy(
            player1Score = p1,
            player2Score = p2,
            currentServerSide = scoringSide,
            currentServer = scorerName,
            serviceSide = serviceSide,
        )

        val high = maxOf(p1, p2)
        val low = minOf(p1, p2)
        val requiredLead = if (state.tennisNoAdScoring) 1 else 2
        if (high < state.scoreType || high - low < requiredLead) return next

        val winnerName = if (p1 > p2) match.player1Name else match.player2Name
        val history = state.gameHistory + GameHistoryEntry(state.currentGameNumber, p1, p2, winnerName)
        val p1Games = state.player1GamesWon + (if (scoringSide == "player1") 1 else 0)
        val p2Games = state.player2GamesWon + (if (scoringSide == "player2") 1 else 0)
        next = next.copy(gameHistory = history, player1GamesWon = p1Games, player2GamesWon = p2Games)
        val gamesToWin = state.bestOf / 2 + 1
        if (p1Games >= gamesToWin || p2Games >= gamesToWin) {
            return next.copy(matchComplete = true, winnerName = winnerName)
        }
        val handicap = state.handicap?.takeIf { it.enabled }
        return next.copy(
            currentGameNumber = state.currentGameNumber + 1,
            player1Score = handicap?.player1Offset ?: 0,
            player2Score = handicap?.player2Offset ?: 0,
            currentServerSide = scoringSide,
            currentServer = winnerName,
            serviceSide = serviceSideForReceiver(match, scoringSide),
        )
    }

    private fun serviceSideForReceiver(match: MatchDetail, serverSide: String): String {
        val receiverHandedness = if (serverSide == "player1") match.player2Handedness else match.player1Handedness
        return if (receiverHandedness.equals("left", ignoreCase = true)) "Left" else "Right"
    }

    private fun withLocalEvent(
        action: OfflineMatchAction,
        state: MatchState,
        previous: MatchState,
        match: MatchDetail,
        tennis: Boolean,
    ): MatchState {
        val gameResult = if (state.gameHistory.size > previous.gameHistory.size) state.gameHistory.last() else null
        val scoringSide = action.scorer ?: action.playerSide
        val isPoint = action.kind == OfflineActionKind.ScorePoint || action.kind == OfflineActionKind.Stroke
        val tennisPoint = tennis && isPoint
        val pointP1 = if (tennisPoint) previous.player1Score + (if (scoringSide == "player1") 1 else 0) else null
        val pointP2 = if (tennisPoint) previous.player2Score + (if (scoringSide == "player2") 1 else 0) else null
        val setGamesChanged = state.player1SetGames + state.player2SetGames > previous.player1SetGames + previous.player2SetGames
        val tennisGameCompleted = tennisPoint && (gameResult != null || setGamesChanged)
        var labels = if (pointP1 != null && pointP2 != null) tennisPointLabels(pointP1, pointP2, previous.isTieBreak) else null
        if (labels != null && tennisGameCompleted) {
            labels = if (scoringSide == "player2") labels.first to "Game" else "Game" to labels.second
        }
        val completedP1 = if (tennisGameCompleted) (gameResult?.player1Score ?: state.player1SetGames) else null
        val completedP2 = if (tennisGameCompleted) (gameResult?.player2Score ?: state.player2SetGames) else null
        val scorerName = if (scoringSide == "player2") match.player2Name else match.player1Name
        val summary = when (action.kind) {
            OfflineActionKind.ScorePoint -> "$scorerName scored (offline)"
            OfflineActionKind.Stroke -> "Stroke awarded to $scorerName (offline)"
            OfflineActionKind.Let -> action.note ?: "Let called (offline)"
            OfflineActionKind.ServeSide -> "Serve changed to ${action.side ?: "Right"} (offline)"
            OfflineActionKind.ReceiverChoice -> "Golden Point receiver selected: ${state.currentReceiver ?: "Receiver"} (offline)"
            OfflineActionKind.Server -> "${action.currentServer ?: "Player"} selected to serve (offline)"
            OfflineActionKind.Timer -> "Match duration saved offline"
            OfflineActionKind.EndMatch -> "Match ended offline"
            OfflineActionKind.MatchSettings -> "Match settings changed offline"
            OfflineActionKind.Undo -> return state
        }
        val event = MatchEvent(
            id = action.id,
            eventType = action.kind.eventType,
            payload = MatchEventPayload(
                scorer = action.scorer,
                note = action.note,
                playerSide = action.playerSide,
                currentServerSide = state.currentServerSide,
                serviceSide = state.serviceSide,
                gameCompleted = gameResult != null,
                matchCompleted = state.matchComplete,
                player1Score = state.player1Score,
                player2Score = state.player2Score,
                player1GamesWon = state.player1GamesWon,
                player2GamesWon = state.player2GamesWon,
                player1SetGames = state.player1SetGames,
                player2SetGames = state.player2SetGames,
                gameNumber = gameResult?.gameNumber ?: state.currentGameNumber,
                side = action.side,
                gameResult = gameResult,
                isTieBreak = state.isTieBreak,
                pointPlayer1Score = pointP1,
                pointPlayer2Score = pointP2,
                pointPlayer1ScoreLabel = labels?.first,
                pointPlayer2ScoreLabel = labels?.second,
                player1ScoreLabel = state.player1ScoreLabel,
                player2ScoreLabel = state.player2ScoreLabel,
                tennisGameCompleted = tennisGameCompleted,
                setCompleted = gameResult != null,
                completedGameNumber = if (tennisGameCompleted) (completedP1 ?: 0) + (completedP2 ?: 0) else null,
                completedGamePlayer1Games = completedP1,
                completedGamePlayer2Games = completedP2,
            ),
            createdAt = Instant.ofEpochMilli(action.createdAtMillis).toString(),
            summary = summary,
        )
        return state.copy(events = state.events + event)
    }

    private fun tennisPointLabels(player1: Int, player2: Int, isTieBreak: Boolean): Pair<String, String> {
        if (isTieBreak) return player1.toString() to player2.toString()
        if (player1 >= 3 && player2 >= 3) {
            if (player1 == player2) return "40" to "40"
            return if (player1 > player2) "Ad" to "40" else "40" to "Ad"
        }
        val labels = listOf("0", "15", "30", "40")
        return labels.getOrElse(player1) { "40" } to labels.getOrElse(player2) { "40" }
    }
}
