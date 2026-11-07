package com.hitnscore.mobile.feature.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.core.auth.RegisterInterestRequest
import com.hitnscore.mobile.core.auth.RegistrationService
import com.hitnscore.mobile.core.config.AppEnvironment
import com.hitnscore.mobile.core.network.ApiResult
import kotlin.random.Random
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class RegistrationUse(val apiValue: String) { Personal("personal"), Club("club") }

/** Problems the form reports before sending, shown in brand pink as on iOS. */
enum class RegistrationProblem { FirstName, Surname, Email, ClubName, HumanCheck }

data class RegistrationUiState(
    val firstName: String = "",
    val surname: String = "",
    val email: String = "",
    val use: RegistrationUse = RegistrationUse.Personal,
    val clubName: String = "",
    val humanLeft: Int = 3,
    val humanRight: Int = 4,
    val humanAnswer: String = "",
    val isSubmitting: Boolean = false,
    val problem: RegistrationProblem? = null,
    /** Message from the server when it refused the request (e.g. already registered). */
    val serverError: String? = null,
    /** Set once the request is accepted: the email the confirmation went to. */
    val confirmedEmail: String? = null,
    val confirmedUse: RegistrationUse = RegistrationUse.Personal,
)

/**
 * "Want In": create a free Personal account, or register a club's interest, as the
 * iOS sign-in screen does. The account is created on the server, which emails a link
 * to verify the address and set a password; the user then signs in as normal.
 */
class RegistrationViewModel(private val service: RegistrationService) : ViewModel() {

    private val mutableState = MutableStateFlow(newHumanCheck(RegistrationUiState()))
    val uiState: StateFlow<RegistrationUiState> = mutableState.asStateFlow()

    fun update(transform: (RegistrationUiState) -> RegistrationUiState) =
        mutableState.update { transform(it).copy(problem = null, serverError = null) }

    /** Clears the form for the next time it opens. */
    fun reset(prefilledEmail: String = "") {
        mutableState.value = newHumanCheck(RegistrationUiState(email = prefilledEmail.trim().takeIf { '@' in it }.orEmpty()))
    }

    fun submit() {
        val state = mutableState.value
        if (state.isSubmitting) return
        val firstName = state.firstName.trim()
        val surname = state.surname.trim()
        val email = state.email.trim().lowercase()
        val clubName = state.clubName.trim()
        val problem = when {
            firstName.isEmpty() -> RegistrationProblem.FirstName
            surname.isEmpty() -> RegistrationProblem.Surname
            !isValidEmail(email) -> RegistrationProblem.Email
            state.use == RegistrationUse.Club && clubName.isEmpty() -> RegistrationProblem.ClubName
            state.humanAnswer.trim() != (state.humanLeft + state.humanRight).toString() -> RegistrationProblem.HumanCheck
            else -> null
        }
        if (problem != null) {
            mutableState.update {
                val checked = it.copy(problem = problem)
                // A wrong answer gets a fresh sum, as iOS.
                if (problem == RegistrationProblem.HumanCheck) newHumanCheck(checked).copy(humanAnswer = "") else checked
            }
            return
        }
        mutableState.update { it.copy(isSubmitting = true, problem = null, serverError = null) }
        viewModelScope.launch {
            val result = service.registerInterest(
                RegisterInterestRequest(
                    firstName = firstName,
                    surname = surname,
                    email = email,
                    useType = state.use.apiValue,
                    clubName = if (state.use == RegistrationUse.Club) clubName else "",
                    pageUrl = "android-app://login",
                    userAgent = "HitnScore Android App ${AppEnvironment.versionName}",
                ),
            )
            mutableState.update {
                when (result) {
                    is ApiResult.Success -> it.copy(isSubmitting = false, confirmedEmail = email, confirmedUse = state.use)
                    is ApiResult.Failure -> it.copy(isSubmitting = false, serverError = result.error.message)
                }
            }
        }
    }

    private fun newHumanCheck(state: RegistrationUiState) =
        state.copy(humanLeft = Random.nextInt(1, 10), humanRight = Random.nextInt(1, 10))

    companion object {
        private val EMAIL = Regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")

        fun isValidEmail(value: String): Boolean = EMAIL.matches(value)

        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val application = this[APPLICATION_KEY] as HitNScoreApplication
                RegistrationViewModel(application.container.registrationService)
            }
        }
    }
}
