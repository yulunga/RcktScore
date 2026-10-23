package com.hitnscore.mobile.feature.scoring

import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchEvent
import com.hitnscore.mobile.data.model.MatchFormatting
import com.hitnscore.mobile.data.model.MatchState
import com.hitnscore.mobile.data.model.TennisParticipant

/** One point on the tennis/Padel point timeline, with an optional game divider after it. */
data class TennisPoint(
    val id: String,
    /** "player1" or "player2": the side that won the point. */
    val scorer: String,
    /** The point score after the rally ("15", "40", "Ad", tiebreak count) or "Game". */
    val label: String,
    val isGame: Boolean,
    /** Set games after a completed game, e.g. "3–2", or null. */
    val gameScore: String?,
)

/**
 * Tennis and Padel rules the scorer needs on the device, ported from iOS
 * `TennisScoringPresentation`, `TennisBreakRules` and `MatchScoringView`.
 * The backend is authoritative for the score itself; these only drive the UI.
 */
object TennisRules {
    private val RALLY_EVENTS = setOf("score_point", "stroke")

    fun isTennis(match: MatchDetail?): Boolean = match != null && MatchFormatting.isTennisStyle(match.sport, match.state)

    fun isPadel(match: MatchDetail?): Boolean = match?.sport.equals("padel", ignoreCase = true)

    fun isDoubles(match: MatchDetail?): Boolean = isTennis(match) && match?.state?.teamFormat.equals("doubles", ignoreCase = true)

    /** Timed breaks: 120 s after a set, 90 s changeover after odd games from game 3. */
    fun breakSeconds(enabled: Boolean, completedGameNumber: Int, setCompleted: Boolean): Int? {
        if (!enabled) return null
        if (setCompleted) return MatchTimer.TENNIS_SET_BREAK_SECONDS
        if (completedGameNumber <= 1 || completedGameNumber % 2 == 0) return null
        return MatchTimer.INTERVAL_SECONDS
    }

    fun latestGameCompletion(state: MatchState?): MatchEvent? =
        state?.events?.lastOrNull { it.payload?.tennisGameCompleted == true }

    /** Identifies the latest completed game so a break starts once per game. */
    fun gameCompletionSignature(state: MatchState?): String? {
        val payload = latestGameCompletion(state)?.payload ?: return null
        val set = payload.gameNumber ?: return null
        val game = payload.completedGameNumber ?: return null
        return listOf(
            set.toString(),
            game.toString(),
            (payload.completedGamePlayer1Games ?: 0).toString(),
            (payload.completedGamePlayer2Games ?: 0).toString(),
            if (payload.setCompleted == true) "set" else "game",
        ).joinToString(":")
    }

    fun completedGames(state: MatchState?): Int = state?.events?.count { it.payload?.tennisGameCompleted == true } ?: 0

    /** Padel Golden Point at 40–40: the receiving team picks the receiver before the point. */
    fun requiresReceiverChoice(match: MatchDetail?): Boolean {
        val state = match?.state ?: return false
        return isPadel(match) && state.tennisNoAdScoring && !state.isTieBreak &&
            state.player1Score == 3 && state.player2Score == 3 && state.noAdDecidingSide == null
    }

    fun receivingSide(state: MatchState): String =
        state.currentReceiverSide ?: if (state.currentServerSide == "player1") "player2" else "player1"

    fun goldenPointReceivers(state: MatchState): List<TennisParticipant> = state.tennisTeams?.get(receivingSide(state)).orEmpty()

    /** The deuce-court receiver picks "Right"; the partner picks "Left". */
    fun receiverCourt(state: MatchState, receiver: TennisParticipant): String {
        val side = receivingSide(state)
        val deuce = state.receiverDeuceOrder?.get(side) ?: goldenPointReceivers(state).firstOrNull()?.id
        return if (receiver.id == deuce) "Right" else "Left"
    }

    /** Team members, falling back to the match names when the backend sent no teams. */
    fun team(match: MatchDetail, side: String): List<TennisParticipant> {
        val teams = match.state?.tennisTeams?.get(side).orEmpty()
        if (teams.isNotEmpty()) return teams
        return if (side == "player1") {
            listOf(TennisParticipant("team1_player1", match.player1Name, match.player1Surname, MatchFormatting.fullName(match.player1Name, match.player1Surname)))
        } else {
            listOf(TennisParticipant("team2_player1", match.player2Name, match.player2Surname, MatchFormatting.fullName(match.player2Name, match.player2Surname)))
        }
    }

    fun sideOf(participantId: String): String = if (participantId.startsWith("team1")) "player1" else "player2"

    /** Who can serve first: everyone in doubles, one per side in singles. */
    fun openingServers(match: MatchDetail): List<TennisParticipant> =
        if (isDoubles(match)) team(match, "player1") + team(match, "player2") else team(match, "player1").take(1) + team(match, "player2").take(1)

    /** The receiver candidates are the opposing team. */
    fun openingReceivers(match: MatchDetail, serverId: String?): List<TennisParticipant> {
        serverId ?: return emptyList()
        val receivers = team(match, if (sideOf(serverId) == "player1") "player2" else "player1")
        return if (isDoubles(match)) receivers else receivers.take(1)
    }

    fun participantName(match: MatchDetail, id: String): String =
        (team(match, "player1") + team(match, "player2")).firstOrNull { it.id == id }?.displayName ?: id

    /** Serving team from the chosen server, interleaved with the receiving team (as iOS). */
    fun openingServeOrder(state: MatchState?, serverId: String): List<String> {
        val teamOne = state?.tennisTeams?.get("player1").orEmpty().map { it.id }
        val teamTwo = state?.tennisTeams?.get("player2").orEmpty().map { it.id }
        val serverIsTeamOne = sideOf(serverId) == "player1"
        val serving = rotated(if (serverIsTeamOne) teamOne else teamTwo, serverId)
        val receiving = if (serverIsTeamOne) teamTwo else teamOne
        val order = mutableListOf<String>()
        for (index in 0 until maxOf(serving.size, receiving.size)) {
            serving.getOrNull(index)?.let(order::add)
            receiving.getOrNull(index)?.let(order::add)
        }
        return order
    }

    /** The chosen receiver takes the deuce court; the serving team's first player is their default. */
    fun openingReceiverDeuceOrder(state: MatchState?, serverId: String, receiverId: String): Map<String, String> {
        val serverSide = sideOf(serverId)
        val result = mutableMapOf(sideOf(receiverId) to receiverId)
        state?.tennisTeams?.get(serverSide)?.firstOrNull()?.id?.let { result[serverSide] = it }
        return result
    }

    private fun rotated(ids: List<String>, start: String): List<String> {
        val index = ids.indexOf(start)
        return if (index < 0) ids else ids.drop(index) + ids.take(index)
    }

    /** Point timeline for the whole match, with a divider after each completed game. */
    fun timeline(state: MatchState?): List<TennisPoint> = state?.events.orEmpty().mapNotNull { event ->
        val p = event.payload ?: return@mapNotNull null
        if (event.eventType !in RALLY_EVENTS) return@mapNotNull null
        val scorer = p.scorer ?: p.playerSide ?: return@mapNotNull null
        val isGame = p.tennisGameCompleted == true || p.gameCompleted == true
        val pointLabel = if (scorer == "player1") {
            p.pointPlayer1ScoreLabel ?: p.player1ScoreLabel ?: "•"
        } else {
            p.pointPlayer2ScoreLabel ?: p.player2ScoreLabel ?: "•"
        }
        val g1 = p.completedGamePlayer1Games
        val g2 = p.completedGamePlayer2Games
        TennisPoint(
            id = event.id,
            scorer = scorer,
            label = if (isGame) "Game" else pointLabel,
            isGame = isGame,
            gameScore = if (!isGame) null else if (g1 != null && g2 != null) "$g1–$g2" else "–",
        )
    }

    /** iOS shows first names, adding a surname initial when both first names match. */
    fun scoreDisplayName(match: MatchDetail, side: String): String {
        val name = if (side == "player1") match.player1Name else match.player2Name
        val surname = if (side == "player1") match.player1Surname else match.player2Surname
        val sameFirstNames = match.player1Name.trim().equals(match.player2Name.trim(), ignoreCase = true)
        val initial = surname?.trim()?.firstOrNull()
        return if (sameFirstNames && initial != null) "$name ${initial.uppercaseChar()}." else name
    }
}
