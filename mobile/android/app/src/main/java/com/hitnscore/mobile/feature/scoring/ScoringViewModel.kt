package com.hitnscore.mobile.feature.scoring

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchFormatting
import com.hitnscore.mobile.data.remote.HitNScoreApi
import com.hitnscore.mobile.feature.scoring.offline.OfflineActionKind
import com.hitnscore.mobile.feature.scoring.offline.OfflineMatchAction
import com.hitnscore.mobile.feature.scoring.offline.OfflineMatchStore
import com.hitnscore.mobile.feature.scoring.offline.OfflineOwner
import java.time.Instant
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
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
    val isOnline: Boolean = true,
    /** Actions scored on this phone that the server has not confirmed yet. */
    val pendingActions: Int = 0,
    val isSyncing: Boolean = false,
    /** The server refused a queued action; Retry or Discard is offered. */
    val syncFailure: String? = null,
) {
    val isComplete: Boolean get() = match?.let(ScoringRules::isComplete) == true
    val isScheduled: Boolean get() = match?.let(ScoringRules::isScheduled) == true
    val isTennis: Boolean get() = TennisRules.isTennis(match)
    val isDoubles: Boolean get() = TennisRules.isDoubles(match)

    /** Padel Golden Point: points wait until the receiving team picks its receiver. */
    val requiresReceiverChoice: Boolean get() = TennisRules.requiresReceiverChoice(match)

    val scoringAllowed: Boolean get() = match?.scoringAccess?.canScore != false
    val canTakeOverScoring: Boolean get() = match?.scoringAccess?.canTakeOver == true

    val canPlay: Boolean
        get() = match != null && scoringAllowed && !isMutating && !isComplete && !isScheduled && timer.phase == TimerPhase.MatchLive
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
 * Live scorer for squash, racketball, tennis and Padel (M5: offline-first).
 *
 * Every scoring action goes through [OfflineMatchStore]: it is queued with its projected
 * scoreboard, shown immediately, and sent to the backend in order. Online, the queue
 * drains in well under a second; offline, it waits and is sent when the connection
 * returns. The server's response stays authoritative and replaces the projection.
 * Only opening a match for the first time and starting a scheduled match need a connection.
 */
class ScoringViewModel(
    private val matchId: String,
    private val api: HitNScoreApi,
    private val timerStore: MatchTimerStore,
    private val offlineStore: OfflineMatchStore,
    private val isOnline: StateFlow<Boolean>,
    private val owner: () -> OfflineOwner?,
    private val nowMillis: () -> Long = System::currentTimeMillis,
) : ViewModel() {

    private val mutableState = MutableStateFlow(ScoringUiState(isOnline = isOnline.value))
    val uiState: StateFlow<ScoringUiState> = mutableState.asStateFlow()

    private var durationRecorded = false
    private var bootstrapped = false

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
        // Queue, sync progress and server responses all arrive through the store.
        viewModelScope.launch {
            combine(offlineStore.snapshots, offlineStore.isSyncing, offlineStore.syncFailure) { _, syncing, failure ->
                syncing to failure?.takeIf { it.matchId == matchId }?.message
            }.collect { (syncing, failure) ->
                mutableState.update {
                    it.copy(pendingActions = offlineStore.pendingCount(matchId), isSyncing = syncing, syncFailure = failure)
                }
                if (bootstrapped) offlineStore.projectedMatch(matchId, owner())?.let { apply(it, bootstrap = false) }
            }
        }
        viewModelScope.launch {
            isOnline.collect { online ->
                val wasOnline = mutableState.value.isOnline
                mutableState.update { it.copy(isOnline = online) }
                if (online && !wasOnline) syncNow()
            }
        }
    }

    fun load() {
        mutableState.update { it.copy(isLoading = true, errorMessage = null) }
        // Show the copy held on the phone straight away, then refresh it.
        offlineStore.projectedMatch(matchId, owner())?.let { apply(it, bootstrap = !bootstrapped) }
        viewModelScope.launch {
            if (!isOnline.value) {
                mutableState.update {
                    it.copy(isLoading = false, errorMessage = if (it.match == null) OFFLINE_NOT_HELD else null)
                }
                return@launch
            }
            offlineStore.sync(api, owner())
            when (val result = api.match(matchId)) {
                is ApiResult.Success -> {
                    val current = owner()
                    if (current != null) offlineStore.cache(result.value, current)
                    val shown = offlineStore.projectedMatch(matchId, current) ?: result.value
                    apply(shown, bootstrap = !bootstrapped)
                }
                is ApiResult.Failure -> mutableState.update {
                    // With a held copy the scorer keeps working; the error only matters without one.
                    it.copy(isLoading = false, errorMessage = if (it.match == null) result.error.message else null)
                }
            }
        }
    }

    // Scoring actions --------------------------------------------------------

    fun score(side: String) {
        if (!mutableState.value.canScore) return
        enqueue(action(OfflineActionKind.ScorePoint, scorer = side))
    }

    /** A stroke awarded to [side]. */
    fun stroke(side: String) {
        if (!mutableState.value.canScore) return
        enqueue(action(OfflineActionKind.Stroke, playerSide = side))
    }

    /** A let: replay the rally. [side] is the player it was awarded to, or null for a general let. */
    fun let(side: String?) {
        if (!mutableState.value.canScore) return
        enqueue(action(OfflineActionKind.Let, playerSide = side, note = side?.let { "Let awarded to $it" } ?: "General let"))
    }

    fun toggleServeSide() {
        val state = mutableState.value
        if (state.isTennis || !state.canScore || !state.canToggleServeSide) return
        val next = if (state.match?.state?.serviceSide.equals("left", ignoreCase = true)) "Right" else "Left"
        enqueue(action(OfflineActionKind.ServeSide, side = next))
    }

    fun chooseFirstServer(side: String) {
        val match = mutableState.value.match ?: return
        if (!mutableState.value.scoringAllowed || mutableState.value.isMutating) return
        val name = if (side == "player2") match.player2Name else match.player1Name
        enqueue(
            action(
                OfflineActionKind.Server,
                currentServer = name,
                currentServerSide = side,
                serviceSide = ScoringRules.openingServiceSide(match, side),
            ),
            onQueued = { mutableState.update { it.copy(timer = it.timer.beginLive()) } },
        )
    }

    /**
     * Tennis/Padel opening order. Singles: the server (receiver follows). Doubles: the
     * server and the opposing receiver, which fixes the serve rotation and deuce courts.
     */
    fun chooseTennisOpening(serverId: String, receiverId: String) {
        val match = mutableState.value.match ?: return
        if (!mutableState.value.scoringAllowed || mutableState.value.isMutating) return
        val serverSide = TennisRules.sideOf(serverId)
        val receiverSide = TennisRules.sideOf(receiverId)
        if (serverSide == receiverSide) return
        enqueue(
            OfflineMatchAction(
                matchId = matchId,
                kind = OfflineActionKind.Server,
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
            onQueued = { mutableState.update { it.copy(timer = it.timer.beginLive()) } },
        )
    }

    /** Padel Golden Point receiver: "Right" (deuce court) or "Left". */
    fun chooseGoldenPointReceiver(court: String) {
        val state = mutableState.value
        if (!state.canPlay || !state.requiresReceiverChoice) return
        enqueue(action(OfflineActionKind.ReceiverChoice, side = court))
    }

    /**
     * Undo, as iOS: an action not yet sent is simply taken back on the phone. Undoing
     * something the server already has needs a connection.
     */
    fun undo() {
        val state = mutableState.value
        if (state.match == null || !state.scoringAllowed || state.undoLocked) return
        if (offlineStore.undoLastQueued(matchId)) {
            offlineStore.projectedMatch(matchId, owner())?.let { apply(it, bootstrap = false) }
            return
        }
        if (!isOnline.value) {
            mutableState.update { it.copy(errorMessage = UNDO_NEEDS_CONNECTION) }
            return
        }
        enqueue(action(OfflineActionKind.Undo))
    }

    fun endEarly() {
        val state = mutableState.value
        if (state.match == null || !state.scoringAllowed || state.isComplete || state.isScheduled) return
        val duration = state.timer.matchDurationSeconds
        mutableState.update { it.copy(timer = it.timer.stopped(duration)) }
        durationRecorded = true
        enqueue(action(OfflineActionKind.EndMatch, note = "Ended by operator", matchDurationSeconds = duration))
    }

    /** Starting a scheduled match changes the court's schedule, so it needs a connection. */
    fun startScheduled() {
        if (!mutableState.value.scoringAllowed || !mutableState.value.isScheduled || mutableState.value.isMutating) return
        if (!isOnline.value) {
            mutableState.update { it.copy(errorMessage = START_NEEDS_CONNECTION) }
            return
        }
        mutableState.update { it.copy(isMutating = true, errorMessage = null) }
        viewModelScope.launch {
            when (val result = api.startScheduledMatch(matchId)) {
                is ApiResult.Success -> {
                    owner()?.let { offlineStore.cache(result.value, it) }
                    timerStore.clear(matchId)
                    apply(result.value, bootstrap = false)
                    mutableState.update { it.copy(timer = initialTimer(result.value)) }
                }
                is ApiResult.Failure -> mutableState.update { it.copy(errorMessage = result.error.message) }
            }
            mutableState.update { it.copy(isMutating = false) }
            persistTimer()
        }
    }

    fun saveSettings(scoreType: Int, bestOf: Int, player1Shirt: String, player2Shirt: String) {
        if (!mutableState.value.scoringAllowed) return
        enqueue(
            action(
                OfflineActionKind.MatchSettings,
                scoreType = scoreType,
                bestOf = bestOf,
                player1ShirtColor = player1Shirt,
                player2ShirtColor = player2Shirt,
            ),
        )
    }

    /** Try sending queued actions again (after a refusal or once back online). */
    fun retrySync() = syncNow()

    /** Drop actions the server refused and return to the server's score. */
    fun discardPending() {
        offlineStore.discardPending(matchId)
        offlineStore.projectedMatch(matchId, owner())?.let { apply(it, bootstrap = false) }
    }

    fun clearError() = mutableState.update { it.copy(errorMessage = null) }

    // Clock ---------------------------------------------------------------

    fun toggleTimer() {
        if (!mutableState.value.scoringAllowed || mutableState.value.isComplete || mutableState.value.isScheduled) return
        mutableState.update { it.copy(timer = it.timer.togglePause()) }
        persistTimer()
    }

    fun skipTimedPhase() {
        if (!mutableState.value.scoringAllowed) return
        mutableState.update { it.copy(timer = it.timer.skip()) }
        persistTimer()
    }

    fun takeOverScoring() {
        val state = mutableState.value
        if (!state.canTakeOverScoring || state.isMutating || !isOnline.value) {
            if (!isOnline.value) mutableState.update { it.copy(errorMessage = TAKEOVER_NEEDS_CONNECTION) }
            return
        }
        mutableState.update { it.copy(isMutating = true, errorMessage = null) }
        viewModelScope.launch {
            when (val result = api.takeOverMatchScoring(matchId)) {
                is ApiResult.Success -> {
                    owner()?.let { offlineStore.cache(result.value, it) }
                    apply(result.value, bootstrap = false)
                }
                is ApiResult.Failure -> mutableState.update { it.copy(errorMessage = result.error.message) }
            }
            mutableState.update { it.copy(isMutating = false) }
        }
    }

    // Internals ------------------------------------------------------------

    private fun action(
        kind: OfflineActionKind,
        scorer: String? = null,
        playerSide: String? = null,
        note: String? = null,
        side: String? = null,
        currentServer: String? = null,
        currentServerSide: String? = null,
        serviceSide: String? = null,
        matchDurationSeconds: Int? = null,
        scoreType: Int? = null,
        bestOf: Int? = null,
        player1ShirtColor: String? = null,
        player2ShirtColor: String? = null,
    ) = OfflineMatchAction(
        matchId = matchId,
        kind = kind,
        scorer = scorer,
        playerSide = playerSide,
        note = note,
        side = side,
        currentServer = currentServer,
        currentServerSide = currentServerSide,
        serviceSide = serviceSide,
        matchDurationSeconds = matchDurationSeconds,
        scoreType = scoreType,
        bestOf = bestOf,
        player1ShirtColor = player1ShirtColor,
        player2ShirtColor = player2ShirtColor,
    )

    /** Queue, show the projected score at once, then send if online. */
    private fun enqueue(action: OfflineMatchAction, onQueued: () -> Unit = {}) {
        if (!offlineStore.enqueue(action)) {
            mutableState.update { it.copy(errorMessage = NOT_HELD) }
            return
        }
        onQueued()
        offlineStore.projectedMatch(matchId, owner())?.let { apply(it, bootstrap = false) }
        persistTimer()
        syncNow()
    }

    private fun syncNow() {
        if (!isOnline.value) return
        viewModelScope.launch { offlineStore.sync(api, owner()) }
    }

    private fun apply(match: MatchDetail, bootstrap: Boolean) {
        if (bootstrap) bootstrapped = true
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
            if (recorded == 0 && final > 0 && !durationRecorded) {
                durationRecorded = true
                recordDuration(final)
            }
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
                pendingActions = offlineStore.pendingCount(matchId),
            )
        }
    }

    /** The finished match's time is queued like any other action, so it is kept offline too. */
    private fun recordDuration(seconds: Int) {
        val queued = offlineStore.enqueue(
            action(OfflineActionKind.Timer, note = "Match duration recorded", matchDurationSeconds = seconds),
        )
        if (queued) syncNow()
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
        const val OFFLINE_NOT_HELD = "You're offline and this match isn't saved on this phone yet. Open it once while online to score it offline."
        const val NOT_HELD = "This match isn't available for offline scoring on this phone. Reload it while online."
        const val UNDO_NEEDS_CONNECTION = "Only points scored on this phone while offline can be undone until you reconnect."
        const val START_NEEDS_CONNECTION = "Connect to the internet to start a scheduled match."
        const val TAKEOVER_NEEDS_CONNECTION = "Connect to the internet before taking over match scoring."

        fun factory(matchId: String): ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val container = (this[APPLICATION_KEY] as HitNScoreApplication).container
                ScoringViewModel(
                    matchId = matchId,
                    api = container.api,
                    timerStore = container.timerStore,
                    offlineStore = container.offlineMatchStore,
                    isOnline = container.connectivity.isOnline,
                    owner = { container.offlineOwner() },
                )
            }
        }
    }
}
