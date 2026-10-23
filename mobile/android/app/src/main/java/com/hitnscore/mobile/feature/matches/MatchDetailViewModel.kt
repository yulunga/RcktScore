package com.hitnscore.mobile.feature.matches

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.remote.HitNScoreApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class MatchDetailUiState(
    val isLoading: Boolean = true,
    val match: MatchDetail? = null,
    val timeline: MatchTimeline? = null,
    val errorMessage: String? = null,
)

class MatchDetailViewModel(
    private val matchId: String,
    private val api: HitNScoreApi,
) : ViewModel() {

    private val mutableState = MutableStateFlow(MatchDetailUiState())
    val uiState: StateFlow<MatchDetailUiState> = mutableState.asStateFlow()

    init {
        load()
    }

    fun load() {
        mutableState.update { it.copy(isLoading = true, errorMessage = null) }
        viewModelScope.launch {
            when (val result = api.match(matchId)) {
                is ApiResult.Success -> mutableState.update {
                    // The timeline is grouped once here, off the drawing path.
                    MatchDetailUiState(isLoading = false, match = result.value, timeline = MatchTimeline.from(result.value))
                }
                is ApiResult.Failure -> mutableState.update {
                    it.copy(isLoading = false, errorMessage = result.error.message)
                }
            }
        }
    }

    companion object {
        fun factory(matchId: String): ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val container = (this[APPLICATION_KEY] as HitNScoreApplication).container
                MatchDetailViewModel(matchId, container.api)
            }
        }
    }
}
