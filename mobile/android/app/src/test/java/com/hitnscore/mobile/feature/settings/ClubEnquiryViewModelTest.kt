package com.hitnscore.mobile.feature.settings

import com.hitnscore.mobile.core.auth.RegisterInterestRequest
import com.hitnscore.mobile.core.auth.RegisterInterestResponse
import com.hitnscore.mobile.core.auth.RegistrationService
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.core.session.AccountContext
import com.hitnscore.mobile.core.session.AccountContextType
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
class ClubEnquiryViewModelTest {
    private class FakeService : RegistrationService {
        val requests = mutableListOf<RegisterInterestRequest>()
        override suspend fun registerInterest(request: RegisterInterestRequest): ApiResult<RegisterInterestResponse> {
            requests += request
            return ApiResult.Success(RegisterInterestResponse(accepted = true))
        }
    }

    @Before
    fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())

    @After
    fun tearDown() = Dispatchers.resetMain()

    @Test
    fun incompleteDetailsAreNotSent() {
        val service = FakeService()
        val viewModel = ClubEnquiryViewModel(service)
        viewModel.open(PlanCodes.CLUB_PRO, "CALSA")
        viewModel.send("Glenn", "Rowe", "glenn@example.com")
        assertEquals(ClubEnquiryProblem.Incomplete, viewModel.uiState.value.problem)
        assertTrue(service.requests.isEmpty())
    }

    @Test
    fun completeEnquiryIsSentAsAClubRegistrationWithThePlan() {
        val service = FakeService()
        val viewModel = ClubEnquiryViewModel(service)
        viewModel.open(PlanCodes.CLUB_PRO, "CALSA")
        viewModel.update {
            it.copy(address = "Main Rd", postcode = "NG23", email = " Club@Calsa.co.uk ", website = "calsa.co.uk", telephone = "01234")
        }
        viewModel.send("Glenn", "Rowe", "glenn@example.com")
        val request = service.requests.single()
        assertEquals("club", request.useType)
        assertEquals("club_pro", request.requestedPlan)
        assertEquals("club@calsa.co.uk", request.clubEmail)
        assertEquals("CALSA", request.clubName)
        assertEquals(PlanCodes.CLUB_PRO to "CALSA", viewModel.uiState.value.sent)
        assertNull(viewModel.uiState.value.plan)
    }

    @Test
    fun planCodesComeFromTheAccountPlan() {
        fun ctx(type: AccountContextType, plan: String) = AccountContext(1, 1, "x", type, "admin", plan)
        assertEquals(PlanCodes.PERSONAL_PLUS, PlanCodes.of(ctx(AccountContextType.Personal, "Personal Plus")))
        assertEquals(PlanCodes.PERSONAL_FREE, PlanCodes.of(ctx(AccountContextType.Personal, "Personal Free")))
        assertEquals(PlanCodes.CLUB_PRO, PlanCodes.of(ctx(AccountContextType.Club, "club_pro")))
        assertEquals(PlanCodes.CLUB_ESSENTIALS, PlanCodes.of(ctx(AccountContextType.Club, "Club Essentials")))
    }
}
