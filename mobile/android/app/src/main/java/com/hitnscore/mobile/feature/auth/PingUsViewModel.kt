package com.hitnscore.mobile.feature.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.core.auth.FeedbackRequest
import com.hitnscore.mobile.core.auth.FeedbackService
import com.hitnscore.mobile.core.config.AppEnvironment
import com.hitnscore.mobile.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class PingUsProblem { Name, Email, Message }

data class PingUsUiState(
    val name: String = "",
    val email: String = "",
    val category: String = PingUsViewModel.CATEGORIES.first(),
    val message: String = "",
    val isSending: Boolean = false,
    val problem: PingUsProblem? = null,
    val serverError: String? = null,
    /** The address a reply would go to, once the message is accepted. */
    val sentTo: String? = null,
)

/** "Ping Us" from Need Help on the sign-in screen: feedback emailed to HitnScore (as iOS). */
class PingUsViewModel(private val service: FeedbackService) : ViewModel() {
    private val mutableState = MutableStateFlow(PingUsUiState())
    val uiState: StateFlow<PingUsUiState> = mutableState.asStateFlow()

    fun reset(prefilledEmail: String = "") {
        mutableState.value = PingUsUiState(email = prefilledEmail.trim().takeIf { '@' in it }.orEmpty())
    }

    fun update(transform: (PingUsUiState) -> PingUsUiState) =
        mutableState.update { transform(it).copy(problem = null, serverError = null) }

    fun send() {
        val state = mutableState.value
        if (state.isSending) return
        val name = state.name.trim()
        val email = state.email.trim().lowercase()
        val message = state.message.trim()
        val problem = when {
            name.isEmpty() -> PingUsProblem.Name
            !RegistrationViewModel.isValidEmail(email) -> PingUsProblem.Email
            message.length < 5 -> PingUsProblem.Message
            else -> null
        }
        if (problem != null) {
            mutableState.update { it.copy(problem = problem) }
            return
        }
        mutableState.update { it.copy(isSending = true, problem = null, serverError = null) }
        viewModelScope.launch {
            val result = service.submit(
                FeedbackRequest(
                    name = name,
                    email = email,
                    category = state.category,
                    message = message,
                    version = "HitnScore Android",
                    build = AppEnvironment.versionName,
                    pageUrl = "android-app://login",
                    userAgent = "HitnScore Android App ${AppEnvironment.versionName}",
                ),
            )
            mutableState.update {
                when (result) {
                    is ApiResult.Success -> it.copy(isSending = false, sentTo = email, message = "")
                    is ApiResult.Failure -> it.copy(isSending = false, serverError = result.error.message)
                }
            }
        }
    }

    companion object {
        /** Same subjects as iOS and the web. */
        val CATEGORIES = listOf(
            "General Feedback",
            "Bug / Something not working",
            "Feature Request",
            "UI / Design Suggestion",
            "Performance Issue",
            "Other",
        )

        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val application = this[APPLICATION_KEY] as HitNScoreApplication
                PingUsViewModel(application.container.feedbackService)
            }
        }
    }
}
