package com.hitnscore.mobile.feature.watch

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.data.model.MatchWatch
import com.hitnscore.mobile.data.remote.MatchWatchApi
import com.hitnscore.mobile.feature.matches.MatchTimeline
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

data class WatchMatchUiState(
    val code: String,
    val isLoading: Boolean = true,
    val watch: MatchWatch? = null,
    val timeline: MatchTimeline? = null,
    val errorMessage: String? = null,
    val isSaving: Boolean = false,
) {
    val isFinished: Boolean get() = watch?.finished == true
}

/**
 * Follows a match by its viewing code (Score Stream), as iOS `RemoteMatchWatchView`: the
 * score is fetched every [refreshMillis] while the screen is visible, until the match ends,
 * then the final result stays. The viewer can't change the match.
 */
class WatchMatchViewModel(
    code: String,
    private val organizationId: Int,
    private val api: MatchWatchApi,
    private val refreshMillis: Long = REFRESH_MILLIS,
) : ViewModel() {

    private val mutableState = MutableStateFlow(WatchMatchUiState(code))
    val uiState: StateFlow<WatchMatchUiState> = mutableState.asStateFlow()

    private var following: Job? = null

    /** Called when the screen becomes visible; refreshes now and then every few seconds. */
    fun startFollowing() {
        if (following?.isActive == true) return
        following = viewModelScope.launch {
            while (isActive) {
                refresh()
                if (mutableState.value.isFinished) break
                delay(refreshMillis)
            }
        }
    }

    /** Called when the screen is hidden, so a phone in a pocket doesn't keep polling. */
    fun stopFollowing() {
        following?.cancel()
        following = null
    }

    fun retry() {
        stopFollowing()
        mutableState.update { it.copy(isLoading = it.watch == null, errorMessage = null) }
        startFollowing()
    }

    suspend fun refresh() {
        when (val result = api.watch(organizationId, mutableState.value.code)) {
            is ApiResult.Success -> mutableState.update {
                it.copy(isLoading = false, watch = result.value, timeline = MatchTimeline.from(result.value.match), errorMessage = null)
            }
            is ApiResult.Failure -> mutableState.update { it.copy(isLoading = false, errorMessage = result.error.message) }
        }
    }

    /** Add to Viewed Matches, so it is listed under Watch a Match on every device. */
    fun save(onSaved: () -> Unit = {}) {
        val state = mutableState.value
        if (state.isSaving || state.watch?.saved == true) return
        mutableState.update { it.copy(isSaving = true) }
        viewModelScope.launch {
            when (val result = api.save(organizationId, state.code)) {
                is ApiResult.Success -> {
                    mutableState.update {
                        it.copy(isSaving = false, watch = result.value, timeline = MatchTimeline.from(result.value.match), errorMessage = null)
                    }
                    onSaved()
                }
                is ApiResult.Failure -> mutableState.update { it.copy(isSaving = false, errorMessage = result.error.message) }
            }
        }
    }

    companion object {
        /** Same refresh rate as iOS. */
        const val REFRESH_MILLIS = 5_000L

        fun factory(code: String, organizationId: Int): ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val container = (this[APPLICATION_KEY] as HitNScoreApplication).container
                WatchMatchViewModel(code, organizationId, container.matchWatchApi)
            }
        }
    }
}
