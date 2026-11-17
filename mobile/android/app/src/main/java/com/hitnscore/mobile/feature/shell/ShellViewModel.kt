package com.hitnscore.mobile.feature.shell

import com.hitnscore.mobile.feature.scoring.ScoringRules
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.core.connectivity.ConnectivityMonitor
import com.hitnscore.mobile.core.network.ApiError
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.core.session.SessionRepository
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.data.model.AppNotification
import com.hitnscore.mobile.data.model.Dashboard
import com.hitnscore.mobile.data.remote.HitNScoreApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class MatchesCategory { Current, Scheduled, History }

data class ShellUiState(
    /** The organisation the data below belongs to. Never shown for another organisation. */
    val organizationId: Int? = null,
    val isOnline: Boolean = true,
    /** First load for this organisation, with nothing to show yet. */
    val isLoading: Boolean = false,
    /** A user-requested refresh (pull to refresh) is running. */
    val isRefreshing: Boolean = false,
    val errorMessage: String? = null,
    val dashboard: Dashboard? = null,
    val notifications: List<AppNotification> = emptyList(),
    /** The scheduled match being started from its Play button. */
    val startingMatchId: String? = null,
    val deletingScheduledMatchId: String? = null,
    /** A delete in Notifications failed; the messages are back in the list. */
    val notificationError: String? = null,
    val matchesCategory: MatchesCategory = MatchesCategory.Current,
) {
    val hasUnreadNotifications: Boolean
        get() = notifications.any { !it.isRead }

    val planCode: String?
        get() = dashboard?.organization?.plan?.lowercase()
}

/**
 * Data for the signed-in shell: dashboard, matches and notifications for the active
 * account context. Switching context clears everything before loading the new
 * organisation, so one account's matches can never appear under another.
 */
class ShellViewModel(
    private val sessionRepository: SessionRepository,
    private val api: HitNScoreApi,
    private val connectivity: ConnectivityMonitor,
    /** True while queued points are being sent; when it finishes, Home reloads. */
    private val syncing: StateFlow<Boolean>? = null,
    /** A match this phone has already finished (even if its last points are still sending). */
    private val finishedOnThisPhone: (String) -> Boolean = { false },
    /** Changes to matches held on this phone, to re-check [finishedOnThisPhone]. */
    private val localMatchChanges: kotlinx.coroutines.flow.Flow<*>? = null,
) : ViewModel() {

    private val mutableState = MutableStateFlow(ShellUiState(isOnline = connectivity.isOnline.value))
    val uiState: StateFlow<ShellUiState> = mutableState.asStateFlow()

    private var loadJob: Job? = null

    init {
        viewModelScope.launch {
            sessionRepository.state
                .map { (it as? SessionState.SignedIn)?.activeContext?.organizationId }
                .distinctUntilChanged()
                .collect { onOrganizationChanged(it) }
        }
        // A match finished on this phone is only complete on the server once its last points
        // are sent, so reload as soon as sending finishes (it then leaves Active Matches).
        // Finished matches leave Active Matches straight away, without waiting for the server.
        localMatchChanges?.let { changes ->
            viewModelScope.launch {
                changes.collect {
                    mutableState.update { state -> state.copy(dashboard = state.dashboard?.let(::withoutFinished)) }
                }
            }
        }
        syncing?.let { flow ->
            viewModelScope.launch {
                var wasSyncing = flow.value
                flow.collect { now ->
                    if (wasSyncing && !now) refreshQuietly()
                    wasSyncing = now
                }
            }
        }
        viewModelScope.launch {
            connectivity.isOnline.collect { online ->
                val wasOnline = mutableState.value.isOnline
                mutableState.update { it.copy(isOnline = online) }
                if (online && !wasOnline) reload(userInitiated = false)
            }
        }
    }

    fun refresh() = reload(userInitiated = true)

    /**
     * Starts a scheduled match (as iOS Play): the server makes it the court's live match,
     * then [onStarted] opens the scorer. Failures show on Home.
     */
    fun startScheduled(matchId: String, onStarted: (String) -> Unit) {
        if (mutableState.value.startingMatchId != null) return
        if (!mutableState.value.isOnline) {
            mutableState.update { it.copy(errorMessage = "Connect to the internet to start a scheduled match.") }
            return
        }
        mutableState.update { it.copy(startingMatchId = matchId, errorMessage = null) }
        viewModelScope.launch {
            when (val result = api.startScheduledMatch(matchId)) {
                is ApiResult.Success -> {
                    mutableState.update { it.copy(startingMatchId = null) }
                    onStarted(result.value.id)
                    refreshQuietly()
                }
                is ApiResult.Failure -> mutableState.update { it.copy(startingMatchId = null, errorMessage = result.error.message) }
            }
        }
    }

    fun deleteScheduled(matchId: String) {
        if (mutableState.value.deletingScheduledMatchId != null) return
        if (!mutableState.value.isOnline) {
            mutableState.update { it.copy(errorMessage = "Connect to the internet to delete a scheduled match.") }
            return
        }
        mutableState.update { it.copy(deletingScheduledMatchId = matchId, errorMessage = null) }
        viewModelScope.launch {
            when (val result = api.deleteScheduledMatch(matchId)) {
                is ApiResult.Success -> refreshQuietly()
                is ApiResult.Failure -> mutableState.update { it.copy(errorMessage = result.error.message) }
            }
            mutableState.update { it.copy(deletingScheduledMatchId = null) }
        }
    }

    /** Background refresh (no spinner): finished matches leave Active Matches, new ones appear. */
    fun refreshQuietly() {
        if (loadJob?.isActive == true) return
        reload(userInitiated = false)
    }

    fun selectMatchesCategory(category: MatchesCategory) =
        mutableState.update { it.copy(matchesCategory = category) }

    fun markNotificationRead(notificationId: String) {
        val organizationId = mutableState.value.organizationId ?: return
        val target = mutableState.value.notifications.firstOrNull { it.id == notificationId } ?: return
        if (target.isRead) return
        mutableState.update { state ->
            state.copy(notifications = state.notifications.map { if (it.id == notificationId) it.copy(isRead = true) else it })
        }
        viewModelScope.launch {
            if (api.markNotificationRead(notificationId, organizationId) !is ApiResult.Success) {
                // Put it back so the unread badge stays honest.
                mutableState.update { state ->
                    if (state.organizationId != organizationId) return@update state
                    state.copy(notifications = state.notifications.map { if (it.id == notificationId) target else it })
                }
            }
        }
    }

    /** Deletes one or more messages (iOS × and "Delete selected"); failures come back with a note. */
    fun dismissNotifications(ids: Set<String>) {
        val organizationId = mutableState.value.organizationId ?: return
        val removed = mutableState.value.notifications.filter { it.id in ids }
        if (removed.isEmpty()) return
        mutableState.update { state ->
            state.copy(notifications = state.notifications.filterNot { it.id in ids }, notificationError = null)
        }
        viewModelScope.launch {
            val failed = removed.filter { api.dismissNotification(it.id, organizationId) !is ApiResult.Success }
            if (failed.isNotEmpty()) {
                mutableState.update { state ->
                    if (state.organizationId != organizationId) return@update state
                    state.copy(
                        notifications = (state.notifications + failed).sortedByDescending { it.createdAt.orEmpty() },
                        notificationError = "Some notifications could not be deleted. Try again.",
                    )
                }
            }
        }
    }

    private fun onOrganizationChanged(organizationId: Int?) {
        loadJob?.cancel()
        mutableState.update {
            ShellUiState(organizationId = organizationId, isOnline = it.isOnline, matchesCategory = it.matchesCategory)
        }
        if (organizationId != null) reload(userInitiated = false)
    }

    private fun reload(userInitiated: Boolean) {
        val organizationId = mutableState.value.organizationId ?: return
        if (!mutableState.value.isOnline) {
            mutableState.update { it.copy(isLoading = false, isRefreshing = false) }
            return
        }
        loadJob?.cancel()
        mutableState.update {
            it.copy(isLoading = it.dashboard == null, isRefreshing = userInitiated, errorMessage = null)
        }
        loadJob = viewModelScope.launch {
            val dashboardCall = async { api.dashboard(organizationId) }
            val notificationsCall = async { api.notifications(organizationId) }
            val dashboard = dashboardCall.await()
            val notifications = notificationsCall.await()
            mutableState.update { state ->
                if (state.organizationId != organizationId) return@update state
                state.copy(
                    isLoading = false,
                    isRefreshing = false,
                    dashboard = ((dashboard as? ApiResult.Success)?.value ?: state.dashboard)?.let(::withoutFinished),
                    notifications = (notifications as? ApiResult.Success)?.value ?: state.notifications,
                    // Like iOS, connection problems show the offline indicator, not an error banner.
                    errorMessage = (dashboard as? ApiResult.Failure)?.error
                        ?.takeUnless { it is ApiError.Network || it is ApiError.SessionInvalid }
                        ?.message,
                )
            }
        }
    }

    private fun withoutFinished(dashboard: Dashboard): Dashboard {
        val live = dashboard.activeMatches.filterNot { finishedOnThisPhone(it.matchId) }
        return if (live.size == dashboard.activeMatches.size) dashboard else dashboard.copy(activeMatches = live)
    }

    companion object {
        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val container = (this[APPLICATION_KEY] as HitNScoreApplication).container
                ShellViewModel(
                    sessionRepository = container.sessionRepository,
                    api = container.api,
                    connectivity = container.connectivity,
                    syncing = container.offlineMatchStore.isSyncing,
                    finishedOnThisPhone = { id ->
                        container.offlineMatchStore.projectedMatch(id, container.offlineOwner())?.let(ScoringRules::isComplete) == true
                    },
                    localMatchChanges = container.offlineMatchStore.snapshots,
                )
            }
        }
    }
}
