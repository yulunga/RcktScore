package com.hitnscore.mobile.feature.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.core.session.AccountContext
import com.hitnscore.mobile.core.session.SessionRepository
import com.hitnscore.mobile.core.session.SignInResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class PasswordResetUiState(
    val email: String = "",
    val isSending: Boolean = false,
    val sent: Boolean = false,
    val errorMessage: String? = null,
)

data class LoginUiState(
    val username: String = "",
    val password: String = "",
    val passwordVisible: Boolean = false,
    val isSigningIn: Boolean = false,
    val errorMessage: String? = null,
    /** Non-null while the "already signed in elsewhere" question is showing. */
    val conflictMessage: String? = null,
    /** Non-empty while the legacy organisation chooser is showing. */
    val accountChoices: List<AccountContext> = emptyList(),
    val passwordReset: PasswordResetUiState? = null,
) {
    val canSubmit: Boolean
        get() = !isSigningIn && username.isNotBlank() && password.isNotEmpty()
}

class LoginViewModel(private val sessionRepository: SessionRepository) : ViewModel() {

    private val mutableState = MutableStateFlow(LoginUiState())
    val uiState: StateFlow<LoginUiState> = mutableState.asStateFlow()

    fun onUsernameChange(value: String) = mutableState.update { it.copy(username = value, errorMessage = null) }

    fun onPasswordChange(value: String) = mutableState.update { it.copy(password = value, errorMessage = null) }

    fun togglePasswordVisibility() = mutableState.update { it.copy(passwordVisible = !it.passwordVisible) }

    fun signIn() = submit(forceLogoutOther = false)

    fun confirmSignOutOtherDevice() {
        mutableState.update { it.copy(conflictMessage = null) }
        submit(forceLogoutOther = true)
    }

    fun dismissConflict() = mutableState.update { it.copy(conflictMessage = null) }

    fun chooseAccount(context: AccountContext) {
        val result = sessionRepository.completeAccountSelection(context)
        mutableState.update {
            it.copy(
                accountChoices = emptyList(),
                password = if (result is SignInResult.Success) "" else it.password,
                errorMessage = (result as? SignInResult.Failed)?.message,
            )
        }
    }

    fun cancelAccountChoice() {
        sessionRepository.cancelAccountSelection()
        mutableState.update { it.copy(accountChoices = emptyList()) }
    }

    fun openPasswordReset() = mutableState.update {
        it.copy(passwordReset = PasswordResetUiState(email = it.username.trim().takeIf { name -> '@' in name }.orEmpty()))
    }

    fun onResetEmailChange(value: String) = mutableState.update {
        it.copy(passwordReset = it.passwordReset?.copy(email = value, errorMessage = null))
    }

    fun sendPasswordReset() {
        val reset = mutableState.value.passwordReset ?: return
        if (reset.isSending || '@' !in reset.email) return
        mutableState.update { it.copy(passwordReset = reset.copy(isSending = true, errorMessage = null)) }
        viewModelScope.launch {
            val error = sessionRepository.requestPasswordReset(reset.email)
            mutableState.update {
                it.copy(passwordReset = it.passwordReset?.copy(isSending = false, sent = error == null, errorMessage = error))
            }
        }
    }

    fun closePasswordReset() = mutableState.update { it.copy(passwordReset = null) }

    private fun submit(forceLogoutOther: Boolean) {
        val current = mutableState.value
        if (!current.canSubmit) return
        mutableState.update { it.copy(isSigningIn = true, errorMessage = null) }
        viewModelScope.launch {
            val result = sessionRepository.signIn(current.username, current.password, forceLogoutOther)
            mutableState.update {
                when (result) {
                    SignInResult.Success -> it.copy(isSigningIn = false, password = "", passwordVisible = false)
                    is SignInResult.SessionConflict -> it.copy(isSigningIn = false, conflictMessage = result.message)
                    is SignInResult.ChooseAccount -> it.copy(isSigningIn = false, accountChoices = result.choices)
                    is SignInResult.Failed -> it.copy(isSigningIn = false, errorMessage = result.message)
                }
            }
        }
    }

    companion object {
        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val application = this[APPLICATION_KEY] as HitNScoreApplication
                LoginViewModel(application.container.sessionRepository)
            }
        }
    }
}
