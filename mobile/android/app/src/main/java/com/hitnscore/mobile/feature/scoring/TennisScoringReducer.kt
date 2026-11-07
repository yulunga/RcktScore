package com.hitnscore.mobile.feature.scoring

import com.hitnscore.mobile.data.model.GameHistoryEntry
import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchState
import com.hitnscore.mobile.data.model.TennisParticipant
import kotlin.math.abs

/**
 * Device-side tennis/Padel rules used while scoring actions wait to sync, ported
 * line for line from iOS `TennisScoringReducer`. The backend stays authoritative;
 * this mirrors its transitions so an offline scoreboard does not jump on reconnect.
 */
object TennisScoringReducer {

    /** Mutable working copy of the fields a point can change. */
    private class Draft(state: MatchState) {
        val base = state
        var player1Score = state.player1Score
        var player2Score = state.player2Score
        var player1GamesWon = state.player1GamesWon
        var player2GamesWon = state.player2GamesWon
        var player1SetGames = state.player1SetGames
        var player2SetGames = state.player2SetGames
        var currentGameNumber = state.currentGameNumber
        val bestOf = state.bestOf
        val scoreType = state.scoreType
        var currentServer = state.currentServer
        var currentServerSide = state.currentServerSide
        var serviceSide = state.serviceSide
        var scoreDisplayMode = state.scoreDisplayMode
        var player1ScoreLabel = state.player1ScoreLabel
        var player2ScoreLabel = state.player2ScoreLabel
        var isTieBreak = state.isTieBreak
        var isMatchTiebreak = state.isMatchTiebreak
        val noAd = state.tennisNoAdScoring
        val finalSetMatchTiebreak = state.tennisFinalSetMatchTiebreak
        var noAdDecidingSide = state.noAdDecidingSide
        val teams: Map<String, List<TennisParticipant>> = state.tennisTeams.orEmpty()
        val teamServiceOrder = state.teamServiceOrder
        var currentServerParticipantId = state.currentServerParticipantId
        var currentReceiver = state.currentReceiver
        var currentReceiverSide = state.currentReceiverSide
        var currentReceiverParticipantId = state.currentReceiverParticipantId
        var serveOrder = state.serveOrder
        val receiverDeuceOrder = state.receiverDeuceOrder
        var tieBreakFirstServerSide = state.tieBreakFirstServerSide
        var tieBreakFirstServerParticipantId = state.tieBreakFirstServerParticipantId
        val gameHistory = state.gameHistory.toMutableList()
        var matchComplete = state.matchComplete
        var winnerName = state.winnerName

        fun value(): MatchState = base.copy(
            player1Score = player1Score,
            player2Score = player2Score,
            player1GamesWon = player1GamesWon,
            player2GamesWon = player2GamesWon,
            player1SetGames = player1SetGames,
            player2SetGames = player2SetGames,
            currentGameNumber = currentGameNumber,
            currentServer = currentServer,
            currentServerSide = currentServerSide,
            serviceSide = serviceSide,
            scoreDisplayMode = scoreDisplayMode,
            player1ScoreLabel = player1ScoreLabel,
            player2ScoreLabel = player2ScoreLabel,
            isTieBreak = isTieBreak,
            isMatchTiebreak = isMatchTiebreak,
            noAdDecidingSide = noAdDecidingSide,
            currentServerParticipantId = currentServerParticipantId,
            currentReceiver = currentReceiver,
            currentReceiverSide = currentReceiverSide,
            currentReceiverParticipantId = currentReceiverParticipantId,
            serveOrder = serveOrder,
            tieBreakFirstServerSide = tieBreakFirstServerSide,
            tieBreakFirstServerParticipantId = tieBreakFirstServerParticipantId,
            gameHistory = gameHistory.toList(),
            matchComplete = matchComplete,
            winnerName = winnerName,
        )
    }

    fun applyPoint(state: MatchState, scoringSide: String, match: MatchDetail): MatchState {
        if (state.matchComplete) return state
        val isPadel = match.sport.equals("padel", ignoreCase = true)
        if (isPadel && state.tennisNoAdScoring && !state.isTieBreak &&
            state.player1Score == 3 && state.player2Score == 3 && state.noAdDecidingSide == null
        ) {
            return state
        }

        val d = Draft(state)
        val currentServerSide = d.currentServerSide ?: "player1"
        val currentServerId = d.currentServerParticipantId ?: currentGameServerId(d)
        val order = combinedServeOrder(d).toMutableList()

        if (scoringSide == "player1") d.player1Score += 1 else d.player2Score += 1
        d.serviceSide = serviceSide(d.player1Score, d.player2Score)

        if (d.isTieBreak) {
            val firstServerSide = d.tieBreakFirstServerSide ?: currentServerSide
            val firstServerId = d.tieBreakFirstServerParticipantId ?: currentServerId
            val target = if (d.isMatchTiebreak) 10 else 7
            if (isComplete(d.player1Score, d.player2Score, target, 2)) {
                val p1Won = if (scoringSide == "player1") 1 else 0
                val p2Won = if (scoringSide == "player2") 1 else 0
                completeSet(
                    d,
                    scoringSide,
                    match,
                    player1Games = if (d.isMatchTiebreak) p1Won else d.player1SetGames + p1Won,
                    player2Games = if (d.isMatchTiebreak) p2Won else d.player2SetGames + p2Won,
                    nextServerId = nextParticipant(firstServerId, order),
                    nextServerSide = opponent(firstServerSide),
                    serveOrder = order,
                )
            } else {
                val nextId = tieBreakServer(order, d.player1Score + d.player2Score) ?: firstServerId
                setServer(d, nextId, participantSide(nextId, d) ?: opponent(firstServerSide), match)
                updateReceiver(d, match)
            }
            updateLabels(d)
            return d.value()
        }

        val requiredMargin = if (d.noAd) 1 else 2
        if (!isComplete(d.player1Score, d.player2Score, 4, requiredMargin)) {
            setServer(d, currentServerId, currentServerSide, match)
            if (d.noAd && d.player1Score == 3 && d.player2Score == 3) {
                d.noAdDecidingSide = if (isPadel) null else "Right"
                if (!isPadel) d.serviceSide = "Right"
            }
            updateReceiver(d, match)
            updateLabels(d)
            return d.value()
        }

        d.noAdDecidingSide = null
        if (scoringSide == "player1") d.player1SetGames += 1 else d.player2SetGames += 1
        val trigger = tieBreakTrigger(d.scoreType)
        when {
            isComplete(d.player1SetGames, d.player2SetGames, d.scoreType, 2) -> {
                val completedGames = d.player1SetGames + d.player2SetGames
                completeSet(
                    d,
                    scoringSide,
                    match,
                    player1Games = d.player1SetGames,
                    player2Games = d.player2SetGames,
                    nextServerId = participant(completedGames, order),
                    nextServerSide = opponent(currentServerSide),
                    serveOrder = order,
                )
            }
            d.player1SetGames == trigger && d.player2SetGames == trigger -> {
                d.player1Score = 0
                d.player2Score = 0
                d.isTieBreak = true
                d.isMatchTiebreak = false
                val firstId = participant(d.player1SetGames + d.player2SetGames, order)
                val firstSide = participantSide(firstId, d) ?: opponent(currentServerSide)
                d.tieBreakFirstServerParticipantId = firstId
                d.tieBreakFirstServerSide = firstSide
                d.serviceSide = "Right"
                rotate(order, firstId)
                d.serveOrder = order.toList()
                setServer(d, firstId, firstSide, match)
                updateReceiver(d, match)
            }
            else -> {
                d.player1Score = 0
                d.player2Score = 0
                d.serviceSide = "Right"
                val nextId = participant(d.player1SetGames + d.player2SetGames, order)
                setServer(d, nextId, opponent(currentServerSide), match)
                updateReceiver(d, match)
            }
        }
        updateLabels(d)
        return d.value()
    }

    /** Padel Golden Point: the receiving team's choice of court ("Right" or "Left"). */
    fun applyReceiverChoice(state: MatchState, side: String, match: MatchDetail): MatchState {
        if (!match.sport.equals("padel", ignoreCase = true) || !state.tennisNoAdScoring || state.isTieBreak ||
            state.player1Score != 3 || state.player2Score != 3 || (side != "Right" && side != "Left")
        ) {
            return state
        }
        val d = Draft(state)
        d.noAdDecidingSide = side
        d.serviceSide = side
        updateReceiver(d, match)
        return d.value()
    }

    private fun completeSet(
        d: Draft,
        scoringSide: String,
        match: MatchDetail,
        player1Games: Int,
        player2Games: Int,
        nextServerId: String?,
        nextServerSide: String,
        serveOrder: MutableList<String>,
    ) {
        val winner = if (scoringSide == "player1") match.player1Name else match.player2Name
        d.player1SetGames = player1Games
        d.player2SetGames = player2Games
        d.gameHistory += GameHistoryEntry(d.currentGameNumber, player1Games, player2Games, winner)
        if (scoringSide == "player1") d.player1GamesWon += 1 else d.player2GamesWon += 1
        val setsToWin = d.bestOf / 2 + 1
        if (maxOf(d.player1GamesWon, d.player2GamesWon) >= setsToWin) {
            d.matchComplete = true
            d.winnerName = winner
            return
        }

        d.currentGameNumber += 1
        d.player1SetGames = 0
        d.player2SetGames = 0
        d.player1Score = 0
        d.player2Score = 0
        d.noAdDecidingSide = null
        d.isTieBreak = false
        d.isMatchTiebreak = false
        d.tieBreakFirstServerSide = null
        d.tieBreakFirstServerParticipantId = null
        d.serviceSide = "Right"
        rotate(serveOrder, nextServerId)
        d.serveOrder = serveOrder.toList()
        setServer(d, nextServerId, nextServerSide, match)

        if (d.finalSetMatchTiebreak && d.bestOf > 1 &&
            d.player1GamesWon == setsToWin - 1 && d.player2GamesWon == setsToWin - 1
        ) {
            d.isTieBreak = true
            d.isMatchTiebreak = true
            d.tieBreakFirstServerSide = d.currentServerSide
            d.tieBreakFirstServerParticipantId = d.currentServerParticipantId
        }
        updateReceiver(d, match)
    }

    private fun isComplete(player1: Int, player2: Int, target: Int, margin: Int): Boolean =
        maxOf(player1, player2) >= target && abs(player1 - player2) >= margin

    private fun opponent(side: String): String = if (side == "player1") "player2" else "player1"

    private fun tieBreakTrigger(scoreType: Int): Int = if (scoreType == 4) 3 else 6

    private fun serviceSide(player1: Int, player2: Int): String = if ((player1 + player2) % 2 == 0) "Right" else "Left"

    private fun combinedServeOrder(d: Draft): List<String> {
        d.serveOrder?.takeIf { it.isNotEmpty() }?.let { return it }
        val team1 = d.teamServiceOrder?.get("player1") ?: d.teams["player1"]?.map { it.id }.orEmpty()
        val team2 = d.teamServiceOrder?.get("player2") ?: d.teams["player2"]?.map { it.id }.orEmpty()
        val result = mutableListOf<String>()
        for (index in 0 until maxOf(team1.size, team2.size)) {
            team1.getOrNull(index)?.let(result::add)
            team2.getOrNull(index)?.let(result::add)
        }
        return result
    }

    private fun rotate(order: MutableList<String>, participantId: String?) {
        participantId ?: return
        val index = order.indexOf(participantId)
        if (index < 0) return
        val rotated = order.drop(index) + order.take(index)
        order.clear()
        order.addAll(rotated)
    }

    private fun currentGameServerId(d: Draft): String? =
        participant(d.player1SetGames + d.player2SetGames, combinedServeOrder(d))

    private fun participant(index: Int, order: List<String>): String? =
        if (order.isEmpty()) null else order[index % order.size]

    private fun nextParticipant(participantId: String?, order: List<String>): String? {
        if (order.isEmpty()) return null
        val index = participantId?.let(order::indexOf) ?: -1
        if (index < 0) return order.first()
        return order[(index + 1) % order.size]
    }

    private fun tieBreakServer(order: List<String>, pointsPlayed: Int): String? {
        if (order.isEmpty()) return null
        if (pointsPlayed <= 0 || order.size == 1) return order[0]
        return order[(1 + (pointsPlayed - 1) / 2) % order.size]
    }

    private fun participantSide(id: String?, d: Draft): String? {
        id ?: return null
        return d.teams.entries.firstOrNull { entry -> entry.value.any { it.id == id } }?.key
    }

    private fun participantName(id: String?, d: Draft): String? {
        id ?: return null
        return d.teams.values.flatten().firstOrNull { it.id == id }?.displayName
    }

    private fun receiverId(side: String, serviceSide: String, d: Draft): String? {
        val participants = d.teams[side].orEmpty()
        val first = participants.firstOrNull() ?: return null
        val deuceId = d.receiverDeuceOrder?.get(side) ?: first.id
        if (participants.size == 1 || serviceSide.equals("right", ignoreCase = true)) return deuceId
        return participants.firstOrNull { it.id != deuceId }?.id ?: deuceId
    }

    private fun setServer(d: Draft, participantId: String?, fallbackSide: String, match: MatchDetail) {
        val side = participantSide(participantId, d) ?: fallbackSide
        d.currentServerParticipantId = participantId
        d.currentServerSide = side
        d.currentServer = participantName(participantId, d) ?: if (side == "player1") match.player1Name else match.player2Name
    }

    private fun updateReceiver(d: Draft, match: MatchDetail) {
        val side = opponent(d.currentServerSide ?: "player1")
        val id = receiverId(side, d.serviceSide ?: "Right", d)
        d.currentReceiverSide = side
        d.currentReceiverParticipantId = id
        d.currentReceiver = participantName(id, d) ?: if (side == "player1") match.player1Name else match.player2Name
    }

    private fun updateLabels(d: Draft) {
        if (d.isTieBreak) {
            d.player1ScoreLabel = d.player1Score.toString()
            d.player2ScoreLabel = d.player2Score.toString()
        } else if (d.player1Score >= 3 && d.player2Score >= 3) {
            when {
                d.player1Score == d.player2Score -> {
                    d.player1ScoreLabel = "40"
                    d.player2ScoreLabel = "40"
                }
                d.noAd -> {
                    d.player1ScoreLabel = if (d.player1Score > d.player2Score) "Game" else "40"
                    d.player2ScoreLabel = if (d.player2Score > d.player1Score) "Game" else "40"
                }
                d.player1Score > d.player2Score -> {
                    d.player1ScoreLabel = "Ad"
                    d.player2ScoreLabel = "40"
                }
                else -> {
                    d.player1ScoreLabel = "40"
                    d.player2ScoreLabel = "Ad"
                }
            }
        } else {
            val labels = listOf("0", "15", "30", "40")
            d.player1ScoreLabel = labels[minOf(d.player1Score, 3)]
            d.player2ScoreLabel = labels[minOf(d.player2Score, 3)]
        }
        d.scoreDisplayMode = "tennis"
    }
}
