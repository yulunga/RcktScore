package com.hitnscore.mobile.feature.auth

import com.hitnscore.mobile.core.auth.PasswordConfirmResponse
import com.hitnscore.mobile.core.auth.PasswordLink
import com.hitnscore.mobile.core.auth.PasswordResetService
import com.hitnscore.mobile.core.auth.PasswordValidateResponse
import com.hitnscore.mobile.core.network.ApiError
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.core.session.AccountContext
import com.hitnscore.mobile.core.session.SessionRepository
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.core.session.SignInResult
import com.hitnscore.mobile.core.session.SignOutReason
import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PasswordSetupViewModelTest {
    private class FakeService : PasswordResetService {
        var validateResult: ApiResult<PasswordValidateResponse> = ApiResult.Success(PasswordValidateResponse(valid = true))
        var confirmResult: ApiResult<PasswordConfirmResponse> = ApiResult.Success(PasswordConfirmResponse(reset = true))
        val confirmed = mutableListOf<Pair<String, String>>()
        override suspend fun validate(token: String) = validateResult
        override suspend fun confirm(token: String, password: String): ApiResult<PasswordConfirmResponse> {
            confirmed += token to password
            return confirmResult
        }
    }

    private class FakeSession(initial: SessionState) : SessionRepository {
        val mutable = MutableStateFlow(initial)
        var endedWith: SignOutReason? = null
        override val state: StateFlow<SessionState> = mutable
        override val biometricUnlockEnabled = MutableStateFlow(false)
        override fun currentAccessToken(): String? = null
        override suspend fun restore() = Unit
        override suspend fun signIn(username: String, password: String, forceLogoutOther: Boolean) = SignInResult.Success
        override fun completeAccountSelection(context: AccountContext) = SignInResult.Success
        override fun cancelAccountSelection() = Unit
        override suspend fun requestPasswordReset(email: String): String? = null
        override fun selectContext(context: AccountContext) = Unit
        override fun signOut() { mutable.value = SessionState.SignedOut() }
        override fun endSession(reason: SignOutReason) {
            endedWith = reason
            mutable.value = SessionState.SignedOut(reason)
        }
        override fun onSessionInvalidated(code: String) = Unit
        override fun validateExpiry() = Unit
        override fun setBiometricUnlockEnabled(enabled: Boolean) = Unit
        override fun lock() = Unit
        override fun unlock() = Unit
    }

    private val reset = PasswordLink("reset-token-1234567", isAccountSetup = false)
    private val setup = PasswordLink("setup_token-1234567", isAccountSetup = true)

    @Before
    fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())

    @After
    fun tearDown() = Dispatchers.resetMain()

    private fun PasswordSetupViewModel.enter(password: String = "Rally-Point7", confirmation: String = password) {
        onPasswordChange(password)
        onConfirmationChange(confirmation)
    }

    @Test
    fun validLinkOpensTheForm() {
        val viewModel = PasswordSetupViewModel(reset, FakeService(), FakeSession(SessionState.SignedOut()))
        assertEquals(PasswordSetupStage.Ready, viewModel.uiState.value.stage)
    }

    @Test
    fun usedOrExpiredLinkIsInvalidAndCannotBeRetried() {
        val service = FakeService().apply { validateResult = ApiResult.Success(PasswordValidateResponse(valid = false)) }
        val viewModel = PasswordSetupViewModel(reset, service, FakeSession(SessionState.SignedOut()))
        assertEquals(PasswordSetupStage.LinkInvalid, viewModel.uiState.value.stage)
        assertFalse(viewModel.uiState.value.canRetryCheck)
    }

    @Test
    fun offlineCheckCanBeRetried() {
        val service = FakeService().apply { validateResult = ApiResult.Failure(ApiError.Network(IOException("offline"))) }
        val viewModel = PasswordSetupViewModel(reset, service, FakeSession(SessionState.SignedOut()))
        assertTrue(viewModel.uiState.value.canRetryCheck)
        service.validateResult = ApiResult.Success(PasswordValidateResponse(valid = true))
        viewModel.checkLink()
        assertEquals(PasswordSetupStage.Ready, viewModel.uiState.value.stage)
        assertNull(viewModel.uiState.value.errorMessage)
    }

    @Test
    fun weakOrMismatchedPasswordIsNotSent() {
        val service = FakeService()
        val viewModel = PasswordSetupViewModel(reset, service, FakeSession(SessionState.SignedOut()))
        viewModel.enter(password = "weak")
        viewModel.save()
        viewModel.enter(confirmation = "Rally-Point8")
        assertFalse(viewModel.uiState.value.canSave)
        viewModel.save()
        assertTrue(service.confirmed.isEmpty())
    }

    @Test
    fun resetSavesAndSignsThisPhoneOut() {
        val service = FakeService()
        val session = FakeSession(SessionState.Locked("Pat"))
        val viewModel = PasswordSetupViewModel(reset, service, session)
        viewModel.enter()
        viewModel.save()
        assertEquals(listOf(reset.token to "Rally-Point7"), service.confirmed)
        assertEquals(PasswordSetupStage.Done, viewModel.uiState.value.stage)
        assertEquals("", viewModel.uiState.value.password)
        assertEquals(SignOutReason.PasswordChanged, session.endedWith)
    }

    @Test
    fun accountSetupKeepsAnotherAccountsSession() {
        val session = FakeSession(SessionState.Locked("Pat"))
        val viewModel = PasswordSetupViewModel(setup, FakeService(), session)
        viewModel.enter()
        viewModel.save()
        assertEquals(PasswordSetupStage.Done, viewModel.uiState.value.stage)
        assertNull(session.endedWith)
    }

    @Test
    fun serverRefusalIsShownAndTheFormStays() {
        val service = FakeService().apply {
            confirmResult = ApiResult.Failure(ApiError.Server(400, "WEAK_PASSWORD", "Choose a stronger password."))
        }
        val viewModel = PasswordSetupViewModel(reset, service, FakeSession(SessionState.SignedOut()))
        viewModel.enter()
        viewModel.save()
        assertEquals(PasswordSetupStage.Ready, viewModel.uiState.value.stage)
        assertEquals("Choose a stronger password.", viewModel.uiState.value.errorMessage)
        assertFalse(viewModel.uiState.value.isSaving)
    }
}
