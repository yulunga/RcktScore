package com.hitnscore.mobile.feature.shell

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
        viewModelScope.launch {
            connectivity.isOnline.collect { online ->
                val wasOnline = mutableState.value.isOnline
                mutableState.update { it.copy(isOnline = online) }
                if (online && !wasOnline) reload(userInitiated = false)
            }
        }
    }

    fun refresh() = reload(userInitiated = true)

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
                    dashboard = (dashboard as? ApiResult.Success)?.value ?: state.dashboard,
                    notifications = (notifications as? ApiResult.Success)?.value ?: state.notifications,
                    // Like iOS, connection problems show the offline indicator, not an error banner.
                    errorMessage = (dashboard as? ApiResult.Failure)?.error
                        ?.takeUnless { it is ApiError.Network || it is ApiError.SessionInvalid }
                        ?.message,
                )
            }
        }
    }

    companion object {
        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val container = (this[APPLICATION_KEY] as HitNScoreApplication).container
                ShellViewModel(container.sessionRepository, container.api, container.connectivity)
            }
        }
    }
}
