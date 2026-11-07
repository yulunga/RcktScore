package com.hitnscore.mobile.feature.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.core.session.SessionRepository
import com.hitnscore.mobile.data.model.ClubRoles
import com.hitnscore.mobile.data.model.CourtRequest
import com.hitnscore.mobile.data.model.CreateOrganizationUserRequest
import com.hitnscore.mobile.data.model.OrganizationDetailsRequest
import com.hitnscore.mobile.data.model.OrganizationSettings
import com.hitnscore.mobile.data.model.UpdateOrganizationUserRequest
import com.hitnscore.mobile.data.remote.HitNScoreApi
import com.hitnscore.mobile.data.remote.SettingsApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** What a successful change reports back, shown as a short confirmation line. */
enum class SettingsNotice { Saved, UserInvited, UserUpdated, UserRemoved, ResetSent, CourtSaved, CourtRemoved, DisplayCodeIssued }

data class OrganizationSettingsUiState(
    val isLoading: Boolean = true,
    val settings: OrganizationSettings? = null,
    /** Loading failed: shown with a retry button. */
    val errorMessage: String? = null,
    val isSaving: Boolean = false,
    /** A change the server refused, in its own words. */
    val actionError: String? = null,
    val notice: SettingsNotice? = null,
)

/**
 * Club organisation, sports, timer defaults, users and courts (M6), one instance per
 * organisation. Each change is sent to the same route iOS and the web use, then the
 * settings are refreshed from the server so every page shows what the server holds.
 */
class OrganizationSettingsViewModel(
    private val organizationId: Int,
    private val api: HitNScoreApi,
    private val settingsApi: SettingsApi,
    private val sessionRepository: SessionRepository,
) : ViewModel() {
    private val mutableState = MutableStateFlow(OrganizationSettingsUiState())
    val uiState: StateFlow<OrganizationSettingsUiState> = mutableState.asStateFlow()

    init {
        load()
    }

    fun load() {
        mutableState.update { it.copy(isLoading = true, errorMessage = null) }
        viewModelScope.launch {
            when (val result = api.organizationSettings(organizationId)) {
                is ApiResult.Success -> mutableState.update { it.copy(isLoading = false, settings = result.value) }
                is ApiResult.Failure -> mutableState.update { it.copy(isLoading = false, errorMessage = result.error.message) }
            }
        }
    }

    fun clearMessages() = mutableState.update { it.copy(actionError = null, notice = null) }

    fun saveDetails(request: OrganizationDetailsRequest) = change(SettingsNotice.Saved) {
        settingsApi.updateOrganization(organizationId, request).also { result ->
            if (result is ApiResult.Success) mutableState.update { it.copy(settings = result.value) }
        }
    }

    fun saveSports(sports: List<String>) = change(SettingsNotice.Saved) {
        settingsApi.updateOrganization(organizationId, OrganizationDetailsRequest(enabledSports = sports)).also { result ->
            if (result is ApiResult.Success) {
                mutableState.update { it.copy(settings = result.value) }
                sessionRepository.updateEnabledSports(organizationId, result.value.organization.enabledSports)
            }
        }
    }

    fun saveTimerDefaults(defaults: Map<String, Boolean>) = change(SettingsNotice.Saved) {
        settingsApi.updateOrganization(organizationId, OrganizationDetailsRequest(timedBreakDefaults = defaults)).also { result ->
            if (result is ApiResult.Success) mutableState.update { it.copy(settings = result.value) }
        }
    }

    /** Adds a member (an invitation email lets them set their password) or updates one. */
    fun saveUser(userId: Int?, firstName: String, surname: String, email: String, role: String) {
        val normalizedRole = ClubRoles.normalize(role)
        if (userId == null) {
            change(SettingsNotice.UserInvited, reload = true) {
                settingsApi.createUser(
                    CreateOrganizationUserRequest(organizationId, email.trim().lowercase(), normalizedRole, firstName.trim(), surname.trim()),
                )
            }
        } else {
            change(SettingsNotice.UserUpdated, reload = true) {
                settingsApi.updateUser(
                    userId,
                    UpdateOrganizationUserRequest(organizationId, email.trim().lowercase(), normalizedRole, firstName.trim(), surname.trim()),
                )
            }
        }
    }

    /** Removes the member from this club only; their account and other clubs are kept. */
    fun removeUser(userId: Int) = change(SettingsNotice.UserRemoved, reload = true) { settingsApi.deleteUser(userId, organizationId) }

    /** Club admins can't set passwords (B17); the member gets a secure reset link instead. */
    fun sendPasswordReset(email: String) {
        if (mutableState.value.isSaving) return
        mutableState.update { it.copy(isSaving = true, actionError = null, notice = null) }
        viewModelScope.launch {
            val error = sessionRepository.requestPasswordReset(email)
            mutableState.update {
                it.copy(isSaving = false, actionError = error, notice = if (error == null) SettingsNotice.ResetSent else null)
            }
        }
    }

    fun saveCourt(courtId: Int?, name: String, alias: String, sport: String?) {
        val request = CourtRequest(organizationId, name.trim(), alias.trim(), sport)
        change(SettingsNotice.CourtSaved, reload = true) {
            if (courtId == null) settingsApi.createCourt(request) else settingsApi.updateCourt(courtId, request)
        }
    }

    fun removeCourt(courtId: Int) = change(SettingsNotice.CourtRemoved, reload = true) { settingsApi.deleteCourt(courtId, organizationId) }

    /** Issues a new scoreboard code for a court; the old one stops working. */
    fun newDisplayCode(courtId: Int) = change(SettingsNotice.DisplayCodeIssued, reload = true) {
        settingsApi.newDisplayCode(courtId, organizationId)
    }

    private fun change(notice: SettingsNotice, reload: Boolean = false, call: suspend () -> ApiResult<*>) {
        if (mutableState.value.isSaving) return
        mutableState.update { it.copy(isSaving = true, actionError = null, notice = null) }
        viewModelScope.launch {
            when (val result = call()) {
                is ApiResult.Success -> {
                    if (reload) {
                        (api.organizationSettings(organizationId) as? ApiResult.Success)?.let { fresh ->
                            mutableState.update { it.copy(settings = fresh.value) }
                        }
                    }
                    mutableState.update { it.copy(isSaving = false, notice = notice) }
                }
                is ApiResult.Failure -> mutableState.update { it.copy(isSaving = false, actionError = result.error.message) }
            }
        }
    }

    companion object {
        fun factory(organizationId: Int): ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val container = (this[APPLICATION_KEY] as HitNScoreApplication).container
                OrganizationSettingsViewModel(organizationId, container.api, container.settingsApi, container.sessionRepository)
            }
        }
    }
}
