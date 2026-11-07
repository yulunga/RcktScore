package com.hitnscore.mobile.feature.auth

import com.hitnscore.mobile.core.auth.RegisterInterestRequest
import com.hitnscore.mobile.core.auth.RegisterInterestResponse
import com.hitnscore.mobile.core.auth.RegistrationService
import com.hitnscore.mobile.core.network.ApiError
import com.hitnscore.mobile.core.network.ApiResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class RegistrationViewModelTest {
    private class FakeService(var result: ApiResult<RegisterInterestResponse> = ApiResult.Success(RegisterInterestResponse(true, true))) : RegistrationService {
        val requests = mutableListOf<RegisterInterestRequest>()
        override suspend fun registerInterest(request: RegisterInterestRequest): ApiResult<RegisterInterestResponse> {
            requests += request
            return result
        }
    }

    @Before
    fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())

    @After
    fun tearDown() = Dispatchers.resetMain()

    private fun RegistrationViewModel.fill(answerCorrectly: Boolean = true) = update {
        it.copy(
            firstName = " Pat ",
            surname = "Player",
            email = " Pat@Example.com ",
            humanAnswer = if (answerCorrectly) (it.humanLeft + it.humanRight).toString() else "99",
        )
    }

    @Test
    fun personalSignUpSendsTrimmedLowercaseDetails() {
        val service = FakeService()
        val viewModel = RegistrationViewModel(service)
        viewModel.fill()
        viewModel.submit()
        val request = service.requests.single()
        assertEquals("Pat", request.firstName)
        assertEquals("pat@example.com", request.email)
        assertEquals("personal", request.useType)
        assertEquals("", request.clubName)
        assertEquals("pat@example.com", viewModel.uiState.value.confirmedEmail)
    }

    @Test
    fun clubEnquiryNeedsAClubName() {
        val service = FakeService()
        val viewModel = RegistrationViewModel(service)
        viewModel.fill()
        viewModel.update { it.copy(use = RegistrationUse.Club) }
        viewModel.submit()
        assertEquals(RegistrationProblem.ClubName, viewModel.uiState.value.problem)
        assertTrue(service.requests.isEmpty())
    }

    @Test
    fun wrongHumanCheckIsRefusedAndClearedForANewSum() {
        val service = FakeService()
        val viewModel = RegistrationViewModel(service)
        viewModel.fill(answerCorrectly = false)
        viewModel.submit()
        assertEquals(RegistrationProblem.HumanCheck, viewModel.uiState.value.problem)
        assertEquals("", viewModel.uiState.value.humanAnswer)
        assertTrue(service.requests.isEmpty())
    }

    @Test
    fun serverRefusalIsShownAndNothingIsConfirmed() {
        val service = FakeService(ApiResult.Failure(ApiError.Server(409, "ACCOUNT_ALREADY_REGISTERED", "This email already has a Personal account.")))
        val viewModel = RegistrationViewModel(service)
        viewModel.fill()
        viewModel.submit()
        assertEquals("This email already has a Personal account.", viewModel.uiState.value.serverError)
        assertNull(viewModel.uiState.value.confirmedEmail)
    }
}
