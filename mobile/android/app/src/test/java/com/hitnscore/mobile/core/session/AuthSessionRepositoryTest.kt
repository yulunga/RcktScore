package com.hitnscore.mobile.core.session

import com.hitnscore.mobile.core.auth.AcceptedResponse
import com.hitnscore.mobile.core.auth.AuthService
import com.hitnscore.mobile.core.auth.LoginFixtures
import com.hitnscore.mobile.core.auth.LoginResponseData
import com.hitnscore.mobile.core.auth.SessionPreferences
import com.hitnscore.mobile.core.auth.SessionStore
import com.hitnscore.mobile.core.auth.StoredSession
import com.hitnscore.mobile.core.network.ApiResponseParser
import com.hitnscore.mobile.core.network.ApiResult
import java.time.Instant
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AuthSessionRepositoryTest {
    private val parser = ApiResponseParser(Json { ignoreUnknownKeys = true })
    private val now = Instant.parse("2026-10-23T12:00:00Z")

    private class FakeAuthService : AuthService {
        var loginResult: ApiResult<LoginResponseData>? = null
        val forceFlags = mutableListOf<Boolean>()
        val loggedOutTokens = mutableListOf<String>()

        override suspend fun login(username: String, password: String, forceLogoutOther: Boolean): ApiResult<LoginResponseData> {
            forceFlags += forceLogoutOther
            return loginResult!!
        }

        override suspend fun logout(sessionToken: String): ApiResult<AcceptedResponse> {
            loggedOutTokens += sessionToken
            return ApiResult.Success(AcceptedResponse(loggedOut = true))
        }

        override suspend fun requestPasswordReset(email: String): ApiResult<AcceptedResponse> =
            ApiResult.Success(AcceptedResponse(accepted = true))
    }

    private class MemoryStore(var saved: StoredSession? = null) : SessionStore {
        override fun load() = saved
        override fun save(session: StoredSession) { saved = session }
        override fun clear() { saved = null }
    }

    private class MemoryPreferences(override var biometricUnlockEnabled: Boolean = false) : SessionPreferences

    private val auth = FakeAuthService()
    private val store = MemoryStore()
    private val preferences = MemoryPreferences()

    private fun TestScope.repository() = AuthSessionRepository(
        authService = auth,
        sessionStore = store,
        preferences = preferences,
        backgroundScope = backgroundScope,
        ioDispatcher = UnconfinedTestDispatcher(testScheduler),
        clock = { now },
    )

    private fun respond(status: Int, body: String) {
        auth.loginResult = parser.parse(status, body, LoginResponseData.serializer())
    }

    @Test
    fun signInStoresTheSessionAndExposesAllMemberships() = runTest {
        respond(200, LoginFixtures.identityFirstSession)
        val repository = repository()

        assertEquals(SignInResult.Success, repository.signIn(" player@example.com ", "pw"))

        val state = repository.state.value as SessionState.SignedIn
        assertEquals("Pat", state.displayName)
        assertEquals(AccountContextType.Personal, state.activeContext.type)
        assertEquals("Personal Plus", state.activeContext.plan)
        assertEquals(listOf("Pat Player", "Demo Racket Club"), state.availableContexts.map { it.name })
        assertEquals("token-abc", repository.currentAccessToken())
        assertEquals("token-abc", store.saved?.token)
    }

    @Test
    fun activeSessionConflictAsksThenRetriesWithForce() = runTest {
        respond(409, LoginFixtures.activeSessionConflict)
        val repository = repository()

        val first = repository.signIn("player@example.com", "pw")
        assertTrue(first is SignInResult.SessionConflict)

        respond(200, LoginFixtures.identityFirstSession)
        assertEquals(SignInResult.Success, repository.signIn("player@example.com", "pw", forceLogoutOther = true))
        assertEquals(listOf(false, true), auth.forceFlags)
    }

    @Test
    fun invalidCredentialsGiveAFriendlyMessage() = runTest {
        respond(401, """{"success":false,"error":{"code":"INVALID_CREDENTIALS","message":"Invalid credentials"}}""")
        val result = repository().signIn("player@example.com", "wrong") as SignInResult.Failed
        assertTrue(result.message.contains("don't match"))
    }

    @Test
    fun legacyOrganizationSelectionCompletesWithTheChosenAccount() = runTest {
        respond(200, LoginFixtures.organizationSelection)
        val repository = repository()

        val choose = repository.signIn("player@example.com", "pw") as SignInResult.ChooseAccount
        val club = choose.choices.first { it.type == AccountContextType.Club }
        assertEquals(SignInResult.Success, repository.completeAccountSelection(club))

        val state = repository.state.value as SessionState.SignedIn
        assertEquals("Demo Racket Club", state.activeContext.name)
        assertEquals("token-xyz", repository.currentAccessToken())
    }

    @Test
    fun restoreHandlesValidExpiredAndLockedSessions() = runTest {
        respond(200, LoginFixtures.identityFirstSession)
        repository().signIn("player@example.com", "pw")
        val saved = store.saved!!

        val restored = repository().also { it.restore() }
        assertTrue(restored.state.value is SessionState.SignedIn)

        preferences.biometricUnlockEnabled = true
        val locked = repository().also { it.restore() }
        assertTrue(locked.state.value is SessionState.Locked)
        locked.unlock()
        assertTrue(locked.state.value is SessionState.SignedIn)

        store.saved = saved.copy(expiresAt = "2026-10-23T11:00:00+00:00")
        val expired = repository().also { it.restore() }
        assertEquals(SessionState.SignedOut(SignOutReason.Expired), expired.state.value)
        assertNull(store.saved)
    }

    @Test
    fun backendInvalidationSignsOutWithTheReason() = runTest {
        respond(200, LoginFixtures.identityFirstSession)
        val repository = repository()
        repository.signIn("player@example.com", "pw")

        repository.onSessionInvalidated("SESSION_REPLACED")

        assertEquals(SessionState.SignedOut(SignOutReason.Replaced), repository.state.value)
        assertNull(repository.currentAccessToken())
        assertNull(store.saved)
    }

    @Test
    fun switchingContextPersistsAndSignOutTellsTheBackend() = runTest {
        respond(200, LoginFixtures.identityFirstSession)
        val repository = repository()
        repository.signIn("player@example.com", "pw")

        val club = (repository.state.value as SessionState.SignedIn).availableContexts.last()
        repository.selectContext(club)
        assertEquals(club, (repository.state.value as SessionState.SignedIn).activeContext)
        assertEquals(42, store.saved?.activeMembership?.organizationId)

        repository.signOut()
        runCurrent()
        assertEquals(SessionState.SignedOut(SignOutReason.UserRequested), repository.state.value)
        assertEquals(listOf("token-abc"), auth.loggedOutTokens)
    }
}
