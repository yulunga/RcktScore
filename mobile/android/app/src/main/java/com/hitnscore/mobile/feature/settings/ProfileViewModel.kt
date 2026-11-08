package com.hitnscore.mobile.feature.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.core.session.AccountContextType
import com.hitnscore.mobile.core.session.ProfileUpdate
import com.hitnscore.mobile.core.session.SessionRepository
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.core.session.SignOutReason
import com.hitnscore.mobile.data.model.PersonalProfileRequest
import com.hitnscore.mobile.data.remote.HitNScoreApi
import com.hitnscore.mobile.data.remote.SettingsApi
import com.hitnscore.mobile.feature.auth.RegistrationViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ProfileForm(
    val firstName: String = "",
    val surname: String = "",
    val email: String = "",
    val telephone: String = "",
    val country: String = "",
    val cityLocation: String = "",
)

data class ProfileUiState(
    val form: ProfileForm = ProfileForm(),
    val original: ProfileForm = ProfileForm(),
    val isSaving: Boolean = false,
    val saved: Boolean = false,
    val resetSent: Boolean = false,
    val errorMessage: String? = null,
    /** The user owns a Personal account, which is the only kind they can delete here. */
    val canDeleteAccount: Boolean = false,
    val isDeleting: Boolean = false,
) {
    val hasChanges: Boolean get() = form != original
    val emailChanged: Boolean get() = !form.email.trim().equals(original.email.trim(), ignoreCase = true)
    val canSave: Boolean
        get() = hasChanges && !isSaving && form.firstName.isNotBlank() && RegistrationViewModel.isValidEmail(form.email.trim())
}

/**
 * Profile editing and Personal-account deletion (M6), using `PUT /personal_profile` and
 * `DELETE /personal_account` like iOS. A changed email becomes the sign-in name and the
 * backend signs out every device, so the app returns to sign-in with an explanation.
 */
class ProfileViewModel(
    private val sessionRepository: SessionRepository,
    private val api: HitNScoreApi,
    private val settingsApi: SettingsApi,
    /** Forgets what the phone holds for a deleted account (its local profile photo). */
    private val onAccountDeleted: suspend (username: String) -> Unit = {},
) : ViewModel() {

    private val mutableState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = mutableState.asStateFlow()

    private val session: SessionState.SignedIn? get() = sessionRepository.state.value as? SessionState.SignedIn

    init {
        val signedIn = session
        if (signedIn != null) {
            val membership = signedIn.memberships.firstOrNull { it.id == signedIn.activeContext.membershipId }
            val form = ProfileForm(
                firstName = membership?.firstName.orEmpty(),
                surname = membership?.surname.orEmpty(),
                email = membership?.email?.takeIf { it.isNotBlank() } ?: signedIn.username,
                telephone = membership?.telephone.orEmpty(),
                country = membership?.country.orEmpty(),
            )
            mutableState.value = ProfileUiState(
                form = form,
                original = form,
                canDeleteAccount = signedIn.availableContexts.any { it.type == AccountContextType.Personal },
            )
            loadDirectoryDetails(signedIn)
        }
    }

    /** Admins and Personal owners also receive the city/location saved on the server. */
    private fun loadDirectoryDetails(signedIn: SessionState.SignedIn) {
        viewModelScope.launch {
            val settings = (api.organizationSettings(signedIn.activeContext.organizationId) as? ApiResult.Success)?.value ?: return@launch
            val me = settings.users.firstOrNull { it.username.equals(signedIn.username, ignoreCase = true) } ?: return@launch
            mutableState.update { state ->
                // Never overwrite something the user has started typing.
                if (state.hasChanges) return@update state
                val form = state.form.copy(
                    firstName = me.firstName.ifBlank { state.form.firstName },
                    surname = me.surname.ifBlank { state.form.surname },
                    telephone = me.telephone.ifBlank { state.form.telephone },
                    country = me.country.ifBlank { state.form.country },
                    cityLocation = me.cityLocation,
                )
                state.copy(form = form, original = form)
            }
        }
    }

    /** Cancel editing: back to the saved details. */
    fun discardChanges() = mutableState.update { it.copy(form = it.original, errorMessage = null) }

    fun update(transform: (ProfileForm) -> ProfileForm) =
        mutableState.update { it.copy(form = transform(it.form), saved = false, errorMessage = null, resetSent = false) }

    fun save() {
        val state = mutableState.value
        val signedIn = session ?: return
        if (!state.canSave) return
        val form = state.form
        mutableState.update { it.copy(isSaving = true, errorMessage = null, saved = false) }
        viewModelScope.launch {
            val result = settingsApi.updateProfile(
                signedIn.activeContext.organizationId,
                PersonalProfileRequest(
                    firstName = form.firstName.trim(),
                    surname = form.surname.trim(),
                    email = form.email.trim().lowercase(),
                    telephone = form.telephone.trim(),
                    country = form.country.trim(),
                    cityLocation = form.cityLocation.trim(),
                ),
            )
            when (result) {
                is ApiResult.Success -> {
                    if (state.emailChanged) {
                        // The backend has revoked every session for the old address.
                        sessionRepository.endSession(SignOutReason.EmailChanged)
                    } else {
                        sessionRepository.updateLocalProfile(
                            ProfileUpdate(form.firstName.trim(), form.surname.trim(), form.email.trim().lowercase(), form.telephone.trim(), form.country.trim()),
                        )
                        mutableState.update { it.copy(isSaving = false, saved = true, original = it.form) }
                    }
                }
                is ApiResult.Failure -> mutableState.update { it.copy(isSaving = false, errorMessage = result.error.message) }
            }
        }
    }

    /** Emails a password-reset link to the signed-in address, as iOS Profile does. */
    fun sendPasswordReset() {
        val email = mutableState.value.original.email.ifBlank { session?.username.orEmpty() }
        if (email.isBlank() || mutableState.value.isSaving) return
        mutableState.update { it.copy(isSaving = true, errorMessage = null) }
        viewModelScope.launch {
            val error = sessionRepository.requestPasswordReset(email)
            mutableState.update { it.copy(isSaving = false, resetSent = error == null, errorMessage = error) }
        }
    }

    /**
     * Permanently deletes the Personal account: its matches, memberships (including club
     * associations) and every session. Club-owned matches are kept by the clubs.
     */
    fun deleteAccount() {
        val signedIn = session ?: return
        val personal = signedIn.availableContexts.firstOrNull { it.type == AccountContextType.Personal } ?: return
        if (mutableState.value.isDeleting) return
        mutableState.update { it.copy(isDeleting = true, errorMessage = null) }
        viewModelScope.launch {
            when (val result = settingsApi.deletePersonalAccount(personal.organizationId)) {
                is ApiResult.Success -> {
                    runCatching { onAccountDeleted(signedIn.username) }
                    sessionRepository.endSession(SignOutReason.AccountDeleted)
                }
                is ApiResult.Failure -> mutableState.update { it.copy(isDeleting = false, errorMessage = result.error.message) }
            }
        }
    }

    companion object {
        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val container = (this[APPLICATION_KEY] as HitNScoreApplication).container
                ProfileViewModel(container.sessionRepository, container.api, container.settingsApi) { username ->
                    container.profilePhotos.remove(username)
                }
            }
        }
    }
}
