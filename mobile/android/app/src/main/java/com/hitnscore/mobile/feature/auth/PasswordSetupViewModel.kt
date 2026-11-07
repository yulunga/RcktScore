package com.hitnscore.mobile.feature.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.core.auth.PasswordLink
import com.hitnscore.mobile.core.auth.PasswordPolicy
import com.hitnscore.mobile.core.auth.PasswordResetService
import com.hitnscore.mobile.core.network.ApiError
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.core.session.SessionRepository
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.core.session.SignOutReason
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class PasswordSetupStage { Checking, Ready, LinkInvalid, Done }

data class PasswordSetupUiState(
    val link: PasswordLink,
    val stage: PasswordSetupStage = PasswordSetupStage.Checking,
    val password: String = "",
    val confirmation: String = "",
    val passwordVisible: Boolean = false,
    val isSaving: Boolean = false,
    /** Why the link can't be used, or why the server refused the password, in its own words. */
    val errorMessage: String? = null,
    /** The link check failed for lack of a connection; it can be retried. */
    val canRetryCheck: Boolean = false,
) {
    val unmetRules: List<PasswordPolicy.Rule> get() = PasswordPolicy.unmet(password)
    val confirmationMatches: Boolean get() = confirmation.isNotEmpty() && confirmation == password
    val canSave: Boolean get() = stage == PasswordSetupStage.Ready && !isSaving && unmetRules.isEmpty() && confirmationMatches
}

/**
 * Finishes a password reset or a new account's set-up from the emailed link, in the app
 * (the web does the same on `/help`). The link is checked first, then the new password is
 * sent with it. The backend then signs the account out everywhere, so if this phone was
 * signed in it returns to sign-in too.
 */
class PasswordSetupViewModel(
    link: PasswordLink,
    private val service: PasswordResetService,
    private val sessionRepository: SessionRepository,
) : ViewModel() {

    private val mutableState = MutableStateFlow(PasswordSetupUiState(link))
    val uiState: StateFlow<PasswordSetupUiState> = mutableState.asStateFlow()

    init {
        checkLink()
    }

    fun checkLink() {
        mutableState.update { it.copy(stage = PasswordSetupStage.Checking, errorMessage = null, canRetryCheck = false) }
        viewModelScope.launch {
            when (val result = service.validate(mutableState.value.link.token)) {
                is ApiResult.Success -> mutableState.update {
                    if (result.value.valid) it.copy(stage = PasswordSetupStage.Ready) else it.copy(stage = PasswordSetupStage.LinkInvalid)
                }
                is ApiResult.Failure -> mutableState.update {
                    it.copy(
                        stage = PasswordSetupStage.LinkInvalid,
                        errorMessage = result.error.message,
                        canRetryCheck = result.error is ApiError.Network,
                    )
                }
            }
        }
    }

    fun onPasswordChange(value: String) = mutableState.update { it.copy(password = value, errorMessage = null) }

    fun onConfirmationChange(value: String) = mutableState.update { it.copy(confirmation = value, errorMessage = null) }

    fun togglePasswordVisibility() = mutableState.update { it.copy(passwordVisible = !it.passwordVisible) }

    fun save() {
        val state = mutableState.value
        if (!state.canSave) return
        mutableState.update { it.copy(isSaving = true, errorMessage = null) }
        viewModelScope.launch {
            when (val result = service.confirm(state.link.token, state.password)) {
                is ApiResult.Success -> {
                    mutableState.update { it.copy(isSaving = false, stage = PasswordSetupStage.Done, password = "", confirmation = "") }
                    // Every session for this account has been revoked by the backend. A set-up link is
                    // for a brand-new account, so a session on this phone belongs to someone else: keep it.
                    if (!state.link.isAccountSetup && sessionRepository.state.value !is SessionState.SignedOut) {
                        sessionRepository.endSession(SignOutReason.PasswordChanged)
                    }
                }
                is ApiResult.Failure -> mutableState.update { it.copy(isSaving = false, errorMessage = result.error.message) }
            }
        }
    }

    companion object {
        fun factory(link: PasswordLink): ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val container = (this[APPLICATION_KEY] as HitNScoreApplication).container
                PasswordSetupViewModel(link, container.passwordResetService, container.sessionRepository)
            }
        }
    }
}
