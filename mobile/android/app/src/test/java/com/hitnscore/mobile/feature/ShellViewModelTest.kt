package com.hitnscore.mobile.feature

import com.hitnscore.mobile.core.connectivity.ConnectivityMonitor
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.core.session.AccountContext
import com.hitnscore.mobile.core.session.AccountContextType
import com.hitnscore.mobile.core.session.SessionRepository
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.core.session.SignInResult
import com.hitnscore.mobile.data.model.AppNotification
import com.hitnscore.mobile.data.model.Dashboard
import com.hitnscore.mobile.data.model.CreateMatchRequest
import com.hitnscore.mobile.data.model.EndMatchRequest
import com.hitnscore.mobile.data.model.EventActionRequest
import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchIdRequest
import com.hitnscore.mobile.data.model.MatchSetupLookups
import com.hitnscore.mobile.data.model.ScorePointRequest
import com.hitnscore.mobile.data.model.MatchSummary
import com.hitnscore.mobile.data.model.OrganizationSettings
import com.hitnscore.mobile.data.model.OrganizationSummary
import com.hitnscore.mobile.data.remote.HitNScoreApi
import com.hitnscore.mobile.feature.shell.ShellViewModel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ShellViewModelTest {
    private val personal = AccountContext(1, 50011, "Pat Player", AccountContextType.Personal, "admin", "Personal Free")
    private val club = AccountContext(2, 42, "Demo Club", AccountContextType.Club, "user", "Club Pro")

    private class FakeSession(initial: SessionState) : SessionRepository {
        val mutable = MutableStateFlow(initial)
        override val state: StateFlow<SessionState> = mutable
        override val biometricUnlockEnabled = MutableStateFlow(false)
        override fun currentAccessToken(): String? = "t"
        override suspend fun restore() = Unit
        override suspend fun signIn(username: String, password: String, forceLogoutOther: Boolean) = SignInResult.Success
        override fun completeAccountSelection(context: AccountContext) = SignInResult.Success
        override fun cancelAccountSelection() = Unit
        override suspend fun requestPasswordReset(email: String): String? = null
        override fun selectContext(context: AccountContext) {
            val s = mutable.value as SessionState.SignedIn
            mutable.value = s.copy(activeContext = context)
        }
        override fun signOut() { mutable.value = SessionState.SignedOut() }
        override fun onSessionInvalidated(code: String) = Unit
        override fun validateExpiry() = Unit
        override fun setBiometricUnlockEnabled(enabled: Boolean) = Unit
        override fun lock() = Unit
        override fun unlock() = Unit
    }

    private class FakeApi : HitNScoreApi {
        val pending = mutableMapOf<Int, CompletableDeferred<ApiResult<Dashboard>>>()
        val readCalls = mutableListOf<String>()
        override suspend fun dashboard(organizationId: Int) =
            pending.getOrPut(organizationId) { CompletableDeferred() }.await()
        override suspend fun match(matchId: String): ApiResult<MatchDetail> = error("unused")
        override suspend fun notifications(organizationId: Int): ApiResult<List<AppNotification>> =
            ApiResult.Success(listOf(AppNotification(id = "n$organizationId", title = "Welcome")))
        override suspend fun markNotificationRead(notificationId: String, organizationId: Int): ApiResult<Boolean> {
            readCalls += notificationId
            return ApiResult.Success(true)
        }
        override suspend fun organizationSettings(organizationId: Int): ApiResult<OrganizationSettings> = error("unused")
        override suspend fun setupLookup(organizationId: Int, query: String): ApiResult<MatchSetupLookups> = error("unused")
        override suspend fun createMatch(request: CreateMatchRequest): ApiResult<MatchDetail> = error("unused")
        override suspend fun startScheduledMatch(matchId: String): ApiResult<MatchDetail> = error("unused")
        override suspend fun scorePoint(request: ScorePointRequest): ApiResult<MatchDetail> = error("unused")
        override suspend fun eventAction(request: EventActionRequest): ApiResult<MatchDetail> = error("unused")
        override suspend fun undo(request: MatchIdRequest): ApiResult<MatchDetail> = error("unused")
        override suspend fun endMatch(request: EndMatchRequest): ApiResult<MatchDetail> = error("unused")
    }

    private class Online(value: Boolean = true) : ConnectivityMonitor {
        override val isOnline = MutableStateFlow(value)
    }

    private fun dashboardFor(orgId: Int) = Dashboard(
        organization = OrganizationSummary(id = orgId),
        recentMatches = listOf(MatchSummary(id = "match-of-$orgId", status = "completed")),
    )

    @Before
    fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())

    @After
    fun tearDown() = Dispatchers.resetMain()

    @Test
    fun switchingContextClearsDataAndIgnoresTheOldResponse() = runTest {
        val session = FakeSession(SessionState.SignedIn("pat", "Pat", personal, listOf(personal, club)))
        val api = FakeApi()
        val viewModel = ShellViewModel(session, api, Online())

        assertTrue(viewModel.uiState.value.isLoading)
        session.selectContext(club)
        // The personal dashboard arrives late, after the switch: it must not be shown.
        api.pending.getValue(50011).complete(ApiResult.Success(dashboardFor(50011)))
        assertEquals(42, viewModel.uiState.value.organizationId)
        assertNull(viewModel.uiState.value.dashboard)

        api.pending.getValue(42).complete(ApiResult.Success(dashboardFor(42)))
        assertEquals("match-of-42", viewModel.uiState.value.dashboard?.recentMatches?.single()?.id)
        assertEquals("n42", viewModel.uiState.value.notifications.single().id)
    }

    @Test
    fun markingANotificationReadUpdatesImmediately() = runTest {
        val session = FakeSession(SessionState.SignedIn("pat", "Pat", personal, listOf(personal)))
        val api = FakeApi()
        val viewModel = ShellViewModel(session, api, Online())
        api.pending.getValue(50011).complete(ApiResult.Success(dashboardFor(50011)))

        assertTrue(viewModel.uiState.value.hasUnreadNotifications)
        viewModel.markNotificationRead("n50011")
        assertEquals(false, viewModel.uiState.value.hasUnreadNotifications)
        assertEquals(listOf("n50011"), api.readCalls)
    }

    @Test
    fun signingOutClearsEverything() = runTest {
        val session = FakeSession(SessionState.SignedIn("pat", "Pat", personal, listOf(personal)))
        val api = FakeApi()
        val viewModel = ShellViewModel(session, api, Online())
        api.pending.getValue(50011).complete(ApiResult.Success(dashboardFor(50011)))

        session.signOut()
        assertNull(viewModel.uiState.value.organizationId)
        assertNull(viewModel.uiState.value.dashboard)
    }
}
