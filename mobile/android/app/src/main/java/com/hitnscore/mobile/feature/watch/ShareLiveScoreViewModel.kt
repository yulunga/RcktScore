package com.hitnscore.mobile.feature.watch

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.data.model.MatchDisplayAccess
import com.hitnscore.mobile.data.remote.MatchWatchApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ShareLiveScoreUiState(
    val isLoading: Boolean = false,
    val access: MatchDisplayAccess? = null,
    val errorMessage: String? = null,
) {
    val viewerCode: String get() = access?.viewerCode.orEmpty()

    /** Club courts with a display code also show the Spectator Display details (as iOS). */
    val showsSpectatorDisplay: Boolean get() = access?.let { it.displayCodeEnabled && it.displayCode.isNotBlank() } == true
}

/** The scorer's side of Score Stream: fetches (and creates) the match's viewing code. */
class ShareLiveScoreViewModel(
    private val matchId: String,
    private val api: MatchWatchApi,
) : ViewModel() {

    private val mutableState = MutableStateFlow(ShareLiveScoreUiState())
    val uiState: StateFlow<ShareLiveScoreUiState> = mutableState.asStateFlow()

    /** Loads once; the code never changes for a match, so later calls are free. */
    fun load() {
        val state = mutableState.value
        if (state.isLoading || state.access != null) return
        mutableState.update { it.copy(isLoading = true, errorMessage = null) }
        viewModelScope.launch {
            when (val result = api.displayAccess(matchId)) {
                is ApiResult.Success -> mutableState.update { ShareLiveScoreUiState(access = result.value) }
                is ApiResult.Failure -> mutableState.update { it.copy(isLoading = false, errorMessage = result.error.message) }
            }
        }
    }

    companion object {
        /** The public spectator scoreboard page (as iOS). */
        const val SCOREBOARD_URL = "https://app.hitnscore.com/scoreboard"

        fun factory(matchId: String): ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val container = (this[APPLICATION_KEY] as HitNScoreApplication).container
                ShareLiveScoreViewModel(matchId, container.matchWatchApi)
            }
        }
    }
}
