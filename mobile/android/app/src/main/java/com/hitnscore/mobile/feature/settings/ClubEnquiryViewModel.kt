package com.hitnscore.mobile.feature.settings

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
import com.hitnscore.mobile.feature.auth.RegistrationViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ClubEnquiryForm(
    val clubName: String = "",
    val address: String = "",
    val postcode: String = "",
    val email: String = "",
    val website: String = "",
    val telephone: String = "",
)

enum class ClubEnquiryProblem { Incomplete, ClubEmail, AccountEmail }

data class ClubEnquiryUiState(
    /** `club_essentials` or `club_pro` while the enquiry form is open. */
    val plan: String? = null,
    val form: ClubEnquiryForm = ClubEnquiryForm(),
    val problem: ClubEnquiryProblem? = null,
    val isSending: Boolean = false,
    val serverError: String? = null,
    /** The plan and club an enquiry was sent for. */
    val sent: Pair<String, String>? = null,
)

/**
 * Club subscription enquiry from Settings › Subscription, as iOS: the club's details go to
 * `POST /register_interest` (`use_type = club`, `requested_plan`) and the HitnScore team
 * follows up. Nothing is bought in the app.
 */
class ClubEnquiryViewModel(private val service: RegistrationService) : ViewModel() {
    private val mutable = MutableStateFlow(ClubEnquiryUiState())
    val uiState: StateFlow<ClubEnquiryUiState> = mutable.asStateFlow()

    fun open(plan: String, clubName: String) =
        mutable.update { ClubEnquiryUiState(plan = plan, form = ClubEnquiryForm(clubName = clubName)) }

    fun close() = mutable.update { it.copy(plan = null, problem = null, serverError = null) }

    fun dismissSent() = mutable.update { it.copy(sent = null) }

    fun update(transform: (ClubEnquiryForm) -> ClubEnquiryForm) =
        mutable.update { it.copy(form = transform(it.form), problem = null, serverError = null) }

    fun send(firstName: String, surname: String, accountEmail: String) {
        val state = mutable.value
        val plan = state.plan ?: return
        if (state.isSending) return
        val f = state.form.let {
            it.copy(
                clubName = it.clubName.trim(), address = it.address.trim(), postcode = it.postcode.trim(),
                email = it.email.trim().lowercase(), website = it.website.trim(), telephone = it.telephone.trim(),
            )
        }
        val problem = when {
            listOf(f.clubName, f.address, f.postcode, f.website, f.telephone).any { it.isEmpty() } -> ClubEnquiryProblem.Incomplete
            !RegistrationViewModel.isValidEmail(f.email) -> ClubEnquiryProblem.ClubEmail
            !RegistrationViewModel.isValidEmail(accountEmail.trim()) -> ClubEnquiryProblem.AccountEmail
            else -> null
        }
        if (problem != null) {
            mutable.update { it.copy(problem = problem) }
            return
        }
        mutable.update { it.copy(isSending = true, serverError = null) }
        viewModelScope.launch {
            val request = RegisterInterestRequest(
                firstName = firstName,
                surname = surname,
                email = accountEmail.trim().lowercase(),
                useType = "club",
                clubName = f.clubName,
                pageUrl = "android-app://settings/subscription",
                userAgent = "HitnScore Android App ${AppEnvironment.versionName}",
                requestedPlan = plan,
                clubAddress = f.address,
                clubPostcode = f.postcode,
                clubEmail = f.email,
                clubWebsite = f.website,
                clubTelephone = f.telephone,
            )
            when (val result = service.registerInterest(request)) {
                is ApiResult.Success -> mutable.update { ClubEnquiryUiState(sent = plan to f.clubName) }
                is ApiResult.Failure -> mutable.update { it.copy(isSending = false, serverError = result.error.message) }
            }
        }
    }

    companion object {
        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                ClubEnquiryViewModel((this[APPLICATION_KEY] as HitNScoreApplication).container.registrationService)
            }
        }
    }
}
