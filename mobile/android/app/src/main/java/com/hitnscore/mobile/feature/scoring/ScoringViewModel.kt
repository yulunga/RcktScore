package com.hitnscore.mobile.feature.scoring

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.data.model.EndMatchRequest
import com.hitnscore.mobile.data.model.EventActionRequest
import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchFormatting
import com.hitnscore.mobile.data.model.MatchIdRequest
import com.hitnscore.mobile.data.model.ScorePointRequest
import com.hitnscore.mobile.data.model.newClientActionId
import com.hitnscore.mobile.data.remote.HitNScoreApi
import java.time.Instant
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ScoringUiState(
    val isLoading: Boolean = true,
    val match: MatchDetail? = null,
    val timer: MatchTimer = MatchTimer(),
    val isMutating: Boolean = false,
    val errorMessage: String? = null,
    val rail: List<RailEntry> = emptyList(),
    val canToggleServeSide: Boolean = false,
    /** Increments when a game is won, so the screen can give a stronger haptic. */
    val gamesCompleted: Int = 0,
    /** Tennis/Padel point timeline. */
    val tennisPoints: List<TennisPoint> = emptyList(),
) {
    val isComplete: Boolean get() = match?.let(ScoringRules::isComplete) == true
    val isScheduled: Boolean get() = match?.let(ScoringRules::isScheduled) == true
    val isTennis: Boolean get() = TennisRules.isTennis(match)
    val isDoubles: Boolean get() = TennisRules.isDoubles(match)

    /** Padel Golden Point: points wait until the receiving team picks its receiver. */
    val requiresReceiverChoice: Boolean get() = TennisRules.requiresReceiverChoice(match)

    val canPlay: Boolean
        get() = match != null && !isMutating && !isComplete && !isScheduled && timer.phase == TimerPhase.MatchLive
    val canScore: Boolean get() = canPlay && !requiresReceiverChoice

    /** Undo stays available for five minutes after the match ends, as iOS. */
    val undoLocked: Boolean
        get() {
            if (!isComplete) return false
            val completedAt = MatchFormatting.parseInstant(match?.completedAt) ?: return false
            return Instant.now().epochSecond - completedAt.epochSecond > UNDO_WINDOW_SECONDS
        }

    private companion object {
        const val UNDO_WINDOW_SECONDS = 300
    }
}

/**
 * Live scorer for squash, racketball, tennis and Padel. The server's response to each action is the
 * authoritative match state; this ViewModel only drives the clock and the UI.
 */
class ScoringViewModel(
    private val matchId: String,
    private val api: HitNScoreApi,
    private val timerStore: MatchTimerStore,
    private val nowMillis: () -> Long = System::currentTimeMillis,
) : ViewModel() {

    private val mutableState = MutableStateFlow(ScoringUiState())
    val uiState: StateFlow<ScoringUiState> = mutableState.asStateFlow()

    private var durationRecorded = false

    init {
        load()
        viewModelScope.launch {
            while (true) {
                delay(TICK_MS)
                val before = mutableState.value.timer
                if (!before.running) continue
                mutableState.update { it.copy(timer = it.timer.tick()) }
                persistTimer()
            }
        }
    }

    fun load() {
        mutableState.update { it.copy(isLoading = true, errorMessage = null) }
        viewModelScope.launch {
            when (val result = api.match(matchId)) {
                is ApiResult.Success -> apply(result.value, bootstrap = true)
                is ApiResult.Failure -> mutableState.update { it.copy(isLoading = false, errorMessage = result.error.message) }
            }
        }
    }

    // Scoring actions --------------------------------------------------------

    fun score(side: String) {
        if (!mutableState.value.canScore) return
        mutate { api.scorePoint(ScorePointRequest(matchId, side, newClientActionId())) }
    }

    /** A stroke awarded to [side]. */
    fun stroke(side: String) {
        if (!mutableState.value.canScore) return
        mutate { api.eventAction(EventActionRequest(matchId, "stroke", newClientActionId(), playerSide = side)) }
    }

    /** A let: replay the rally. [side] is the player it was awarded to, or null for a general let. */
    fun let(side: String?) {
        if (!mutableState.value.canScore) return
        val note = side?.let { "Let awarded to $it" } ?: "General let"
        mutate { api.eventAction(EventActionRequest(matchId, "let", newClientActionId(), playerSide = side, note = note)) }
    }

    fun toggleServeSide() {
        val state = mutableState.value
        if (state.isTennis || !state.canScore || !state.canToggleServeSide) return
        val next = if (state.match?.state?.serviceSide.equals("left", ignoreCase = true)) "Right" else "Left"
        mutate { api.eventAction(EventActionRequest(matchId, "serve_side", newClientActionId(), side = next)) }
    }

    fun chooseFirstServer(side: String) {
        val match = mutableState.value.match ?: return
        if (mutableState.value.isMutating) return
        val name = if (side == "player2") match.player2Name else match.player1Name
        mutate(onSuccess = { mutableState.update { it.copy(timer = it.timer.beginLive()) } }) {
            api.eventAction(
                EventActionRequest(
                    matchId = matchId,
                    actionType = "server",
                    clientActionId = newClientActionId(),
                    currentServer = name,
                    currentServerSide = side,
                    serviceSide = ScoringRules.openingServiceSide(match, side),
                ),
            )
        }
    }

    /**
     * Tennis/Padel opening order. Singles: the server (receiver follows). Doubles: the
     * server and the opposing receiver, which fixes the serve rotation and deuce courts.
     */
    fun chooseTennisOpening(serverId: String, receiverId: String) {
        val match = mutableState.value.match ?: return
        if (mutableState.value.isMutating) return
        val serverSide = TennisRules.sideOf(serverId)
        val receiverSide = TennisRules.sideOf(receiverId)
        if (serverSide == receiverSide) return
        mutate(onSuccess = { mutableState.update { it.copy(timer = it.timer.beginLive()) } }) {
            api.eventAction(
                EventActionRequest(
                    matchId = matchId,
                    actionType = "server",
                    clientActionId = newClientActionId(),
                    currentServer = TennisRules.participantName(match, serverId),
                    currentServerSide = serverSide,
                    serviceSide = "Right",
                    currentServerParticipantId = serverId,
                    currentReceiver = TennisRules.participantName(match, receiverId),
                    currentReceiverSide = receiverSide,
                    currentReceiverParticipantId = receiverId,
                    serveOrder = TennisRules.openingServeOrder(match.state, serverId),
                    receiverDeuceOrder = TennisRules.openingReceiverDeuceOrder(match.state, serverId, receiverId),
                ),
            )
        }
    }

    /** Padel Golden Point receiver: "Right" (deuce court) or "Left". */
    fun chooseGoldenPointReceiver(court: String) {
        val state = mutableState.value
        if (!state.canPlay || !state.requiresReceiverChoice) return
        mutate { api.eventAction(EventActionRequest(matchId, "receiver_choice", newClientActionId(), side = court)) }
    }

    fun undo() {
        val state = mutableState.value
        if (state.match == null || state.undoLocked) return
        mutate { api.undo(MatchIdRequest(matchId, newClientActionId())) }
    }

    fun endEarly() {
        val state = mutableState.value
        if (state.match == null || state.isComplete || state.isScheduled) return
        val duration = state.timer.matchDurationSeconds
        mutableState.update { it.copy(timer = it.timer.stopped(duration)) }
        durationRecorded = true
        mutate {
            api.endMatch(EndMatchRequest(matchId, endedEarly = true, clientActionId = newClientActionId(), reason = "Ended by operator", matchDurationSeconds = duration))
        }
    }

    fun startScheduled() {
        if (!mutableState.value.isScheduled) return
        mutate(onSuccess = { match ->
            timerStore.clear(matchId)
            mutableState.update { it.copy(timer = initialTimer(match)) }
        }) { api.startScheduledMatch(matchId) }
    }

    fun saveSettings(scoreType: Int, bestOf: Int, player1Shirt: String, player2Shirt: String) {
        mutate {
            api.eventAction(
                EventActionRequest(
                    matchId = matchId,
                    actionType = "match_settings",
                    clientActionId = newClientActionId(),
                    scoreType = scoreType,
                    bestOf = bestOf,
                    player1ShirtColor = player1Shirt,
                    player2ShirtColor = player2Shirt,
                ),
            )
        }
    }

    fun clearError() = mutableState.update { it.copy(errorMessage = null) }

    // Clock ---------------------------------------------------------------

    fun toggleTimer() {
        if (mutableState.value.isComplete || mutableState.value.isScheduled) return
        mutableState.update { it.copy(timer = it.timer.togglePause()) }
        persistTimer()
    }

    fun skipTimedPhase() {
        mutableState.update { it.copy(timer = it.timer.skip()) }
        persistTimer()
    }

    // Internals ------------------------------------------------------------

    private fun mutate(onSuccess: (MatchDetail) -> Unit = {}, call: suspend () -> ApiResult<MatchDetail>) {
        if (mutableState.value.isMutating) return
        mutableState.update { it.copy(isMutating = true, errorMessage = null) }
        viewModelScope.launch {
            when (val result = call()) {
                is ApiResult.Success -> {
                    apply(result.value, bootstrap = false)
                    onSuccess(result.value)
                }
                is ApiResult.Failure -> mutableState.update { it.copy(errorMessage = result.error.message) }
            }
            mutableState.update { it.copy(isMutating = false) }
            persistTimer()
        }
    }

    private fun apply(match: MatchDetail, bootstrap: Boolean) {
        val previous = mutableState.value
        var timer = if (bootstrap) restoredTimer(match) else previous.timer
        val previousGames = previous.match?.state?.gameHistory?.size ?: 0
        val games = match.state?.gameHistory?.size ?: 0
        val complete = ScoringRules.isComplete(match)
        val tennis = TennisRules.isTennis(match)

        if (!bootstrap && !complete && match.state?.tennisTimedBreaks == true) {
            if (tennis) {
                // A break starts once for each newly completed game (changeover or set break),
                // never after an undo takes a game back.
                val signature = TennisRules.gameCompletionSignature(match.state)
                val payload = TennisRules.latestGameCompletion(match.state)?.payload
                val newGame = TennisRules.completedGames(match.state) > TennisRules.completedGames(previous.match?.state)
                if (newGame && signature != null && signature != TennisRules.gameCompletionSignature(previous.match?.state) && payload != null) {
                    TennisRules.breakSeconds(true, payload.completedGameNumber ?: 0, payload.setCompleted == true)
                        ?.let { timer = timer.beginInterval(it) }
                }
            } else if (games > previousGames) {
                timer = timer.beginInterval()
            }
        }
        if (complete) {
            val recorded = match.state?.matchDurationSeconds ?: match.matchDurationSeconds ?: 0
            val final = maxOf(recorded, timer.matchDurationSeconds)
            timer = timer.stopped(final)
            timerStore.clear(matchId)
            if (recorded == 0 && final > 0 && !durationRecorded) recordDuration(final)
            durationRecorded = true
        }

        mutableState.update {
            it.copy(
                isLoading = false,
                match = match,
                timer = timer,
                rail = if (tennis) emptyList() else ScoringRules.pointRail(match),
                canToggleServeSide = !tennis && !ScoringRules.isScheduled(match) &&
                    ScoringRules.canServerChooseSide(match.state?.events.orEmpty(), match.state?.currentServerSide ?: "player1"),
                gamesCompleted = if (tennis) TennisRules.completedGames(match.state) else games,
                tennisPoints = if (tennis) TennisRules.timeline(match.state) else emptyList(),
            )
        }
    }

    private fun recordDuration(seconds: Int) {
        viewModelScope.launch {
            api.eventAction(
                EventActionRequest(matchId, "timer", newClientActionId(), note = "Match duration recorded", matchDurationSeconds = seconds),
            )
        }
    }

    private fun restoredTimer(match: MatchDetail): MatchTimer {
        if (ScoringRules.isScheduled(match) || ScoringRules.isComplete(match)) {
            timerStore.clear(matchId)
            return initialTimer(match)
        }
        val stored = timerStore.load(matchId)
        val optionalPhase = stored?.phase in setOf(TimerPhase.WarmupReady, TimerPhase.WarmupSideOne, TimerPhase.WarmupSideTwo, TimerPhase.Interval)
        if (stored != null && (match.state?.tennisTimedBreaks == true || !optionalPhase)) {
            return stored.advancedTo(nowMillis())
        }
        return initialTimer(match)
    }

    private fun initialTimer(match: MatchDetail) = MatchTimer.initial(
        isScheduled = ScoringRules.isScheduled(match),
        isComplete = ScoringRules.isComplete(match),
        isFresh = ScoringRules.isFresh(match),
        timedBreaks = match.state?.tennisTimedBreaks == true,
        recordedDuration = match.state?.matchDurationSeconds ?: match.matchDurationSeconds ?: 0,
        isTennis = TennisRules.isTennis(match),
    )

    private fun persistTimer() {
        val state = mutableState.value
        val match = state.match ?: return
        if (state.isComplete || ScoringRules.isScheduled(match)) return
        timerStore.save(matchId, state.timer.copy(updatedAtMillis = nowMillis()))
    }

    companion object {
        private const val TICK_MS = 1_000L

        fun factory(matchId: String): ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val container = (this[APPLICATION_KEY] as HitNScoreApplication).container
                ScoringViewModel(matchId, container.api, container.timerStore)
            }
        }
    }
}
