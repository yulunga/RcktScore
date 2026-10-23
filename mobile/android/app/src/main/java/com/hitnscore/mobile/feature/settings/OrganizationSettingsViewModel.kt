package com.hitnscore.mobile.feature.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.data.model.OrganizationSettings
import com.hitnscore.mobile.data.remote.HitNScoreApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class OrganizationSettingsUiState(
    val isLoading: Boolean = true,
    val settings: OrganizationSettings? = null,
    val errorMessage: String? = null,
)

/** Club organisation, users and courts (read-only until M6). One instance per organisation. */
class OrganizationSettingsViewModel(
    private val organizationId: Int,
    private val api: HitNScoreApi,
) : ViewModel() {
    private val mutableState = MutableStateFlow(OrganizationSettingsUiState())
    val uiState: StateFlow<OrganizationSettingsUiState> = mutableState.asStateFlow()

    init {
        load()
    }

    fun load() {
        mutableState.value = mutableState.value.copy(isLoading = true, errorMessage = null)
        viewModelScope.launch {
            mutableState.value = when (val result = api.organizationSettings(organizationId)) {
                is ApiResult.Success -> OrganizationSettingsUiState(isLoading = false, settings = result.value)
                is ApiResult.Failure -> mutableState.value.copy(isLoading = false, errorMessage = result.error.message)
            }
        }
    }

    companion object {
        fun factory(organizationId: Int): ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val container = (this[APPLICATION_KEY] as HitNScoreApplication).container
                OrganizationSettingsViewModel(organizationId, container.api)
            }
        }
    }
}
