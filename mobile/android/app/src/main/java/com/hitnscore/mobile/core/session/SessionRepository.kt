package com.hitnscore.mobile.core.session

import com.hitnscore.mobile.core.auth.AuthService
import com.hitnscore.mobile.core.auth.OrganizationSelectionPayload
import com.hitnscore.mobile.core.auth.SessionPreferences
import com.hitnscore.mobile.core.auth.SessionStore
import com.hitnscore.mobile.core.auth.StoredSession
import com.hitnscore.mobile.core.network.ApiError
import com.hitnscore.mobile.core.network.ApiResult
import java.time.Instant
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Single source of truth for who is signed in and which account context is active. */
interface SessionRepository {
    val state: StateFlow<SessionState>
    val biometricUnlockEnabled: StateFlow<Boolean>

    /** Bearer token for API calls, or null when signed out. */
    fun currentAccessToken(): String?

    suspend fun restore()
    suspend fun signIn(username: String, password: String, forceLogoutOther: Boolean = false): SignInResult
    fun completeAccountSelection(context: AccountContext): SignInResult
    fun cancelAccountSelection()

    /** Returns null when the request was accepted, otherwise a message to show. */
    suspend fun requestPasswordReset(email: String): String?

    fun selectContext(context: AccountContext)
    fun signOut()
    fun onSessionInvalidated(code: String)
    fun validateExpiry()

    fun setBiometricUnlockEnabled(enabled: Boolean)
    fun lock()
    fun unlock()
}

/**
 * Backend-backed session, mirroring iOS `SessionStore`:
 * expiring token kept encrypted on the device, identity-first memberships,
 * active-session conflict handling, and optional biometric unlock.
 */
class AuthSessionRepository(
    private val authService: AuthService,
    private val sessionStore: SessionStore,
    private val preferences: SessionPreferences,
    private val backgroundScope: CoroutineScope,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
    private val clock: () -> Instant = Instant::now,
) : SessionRepository {

    private val mutableState = MutableStateFlow<SessionState>(SessionState.Restoring)
    override val state: StateFlow<SessionState> = mutableState.asStateFlow()

    private val mutableBiometric = MutableStateFlow(preferences.biometricUnlockEnabled)
    override val biometricUnlockEnabled: StateFlow<Boolean> = mutableBiometric.asStateFlow()

    @Volatile
    private var session: StoredSession? = null

    @Volatile
    private var pendingSelection: OrganizationSelectionPayload? = null

    override fun currentAccessToken(): String? = session?.token

    override suspend fun restore() {
        if (mutableState.value != SessionState.Restoring) return
        val stored = withContext(ioDispatcher) { sessionStore.load() }
        mutableState.value = when {
            stored == null -> SessionState.SignedOut()
            stored.isExpired(clock()) -> {
                sessionStore.clear()
                SessionState.SignedOut(SignOutReason.Expired)
            }
            else -> {
                session = stored
                if (mutableBiometric.value) SessionState.Locked(stored.displayName) else stored.toSignedIn()
            }
        }
    }

    override suspend fun signIn(username: String, password: String, forceLogoutOther: Boolean): SignInResult {
        val result = authService.login(username.trim(), password, forceLogoutOther)
        if (result is ApiResult.Failure) return result.error.toSignInFailure()

        val data = (result as ApiResult.Success).value
        data.session?.let { payload ->
            val token = payload.sessionToken
            val expiresAt = payload.sessionExpiresAt
            if (token.isNullOrBlank() || expiresAt.isNullOrBlank()) return noSessionReturned()
            val membership = payload.toMembership()
            return activate(
                StoredSession(
                    token = token,
                    expiresAt = expiresAt,
                    username = payload.username,
                    activeMembership = membership,
                    memberships = payload.availableMemberships.orEmpty().ifEmpty { listOf(membership) },
                ),
            )
        }
        data.organizationSelection?.let { selection ->
            if (selection.memberships.isEmpty()) return noSessionReturned()
            pendingSelection = selection
            return SignInResult.ChooseAccount(selection.memberships.map { it.toAccountContext() })
        }
        return noSessionReturned()
    }

    override fun completeAccountSelection(context: AccountContext): SignInResult {
        val selection = pendingSelection ?: return SignInResult.Failed(SELECTION_EXPIRED)
        val membership = selection.memberships.firstOrNull { it.id == context.membershipId }
            ?: return SignInResult.Failed(SELECTION_EXPIRED)
        pendingSelection = null
        return activate(
            StoredSession(
                token = selection.sessionToken,
                expiresAt = selection.sessionExpiresAt,
                username = selection.username,
                activeMembership = membership,
                memberships = selection.memberships,
            ),
        )
    }

    override fun cancelAccountSelection() {
        val selection = pendingSelection ?: return
        pendingSelection = null
        backgroundScope.launch { authService.logout(selection.sessionToken) }
    }

    override suspend fun requestPasswordReset(email: String): String? =
        when (val result = authService.requestPasswordReset(email.trim())) {
            is ApiResult.Success -> null
            is ApiResult.Failure -> result.error.message
        }

    override fun selectContext(context: AccountContext) {
        val current = session ?: return
        val membership = current.memberships.firstOrNull { it.id == context.membershipId } ?: return
        if (membership.id == current.activeMembership.id) return
        val updated = current.copy(activeMembership = membership)
        session = updated
        sessionStore.save(updated)
        if (mutableState.value is SessionState.SignedIn) mutableState.value = updated.toSignedIn()
    }

    override fun signOut() {
        val token = session?.token
        clearLocal(SignOutReason.UserRequested)
        if (token != null) backgroundScope.launch { authService.logout(token) }
    }

    override fun onSessionInvalidated(code: String) {
        if (session == null) return
        clearLocal(
            when (code) {
                "SESSION_EXPIRED" -> SignOutReason.Expired
                "SESSION_REPLACED" -> SignOutReason.Replaced
                else -> SignOutReason.Ended
            },
        )
    }

    override fun validateExpiry() {
        val current = session ?: return
        if (current.isExpired(clock())) clearLocal(SignOutReason.Expired)
    }

    override fun setBiometricUnlockEnabled(enabled: Boolean) {
        preferences.biometricUnlockEnabled = enabled
        mutableBiometric.value = enabled
    }

    override fun lock() {
        val current = session ?: return
        if (mutableBiometric.value && mutableState.value is SessionState.SignedIn) {
            mutableState.value = SessionState.Locked(current.displayName)
        }
    }

    override fun unlock() {
        val current = session ?: return
        if (mutableState.value !is SessionState.Locked) return
        if (current.isExpired(clock())) {
            clearLocal(SignOutReason.Expired)
        } else {
            mutableState.value = current.toSignedIn()
        }
    }

    private fun activate(stored: StoredSession): SignInResult {
        if (stored.isExpired(clock())) return SignInResult.Failed("The new session had already expired. Check the date and time on this phone.")
        session = stored
        sessionStore.save(stored)
        mutableState.value = stored.toSignedIn()
        return SignInResult.Success
    }

    private fun clearLocal(reason: SignOutReason) {
        session = null
        pendingSelection = null
        sessionStore.clear()
        mutableState.value = SessionState.SignedOut(reason)
    }

    private fun noSessionReturned() = SignInResult.Failed("Sign-in did not return a session. Please try again.")

    private fun ApiError.toSignInFailure(): SignInResult = when {
        this is ApiError.Server && code == "ACTIVE_SESSION_EXISTS" -> SignInResult.SessionConflict(message)
        this is ApiError.Server && code == "INVALID_CREDENTIALS" ->
            SignInResult.Failed("That username and password don't match. Please try again.")
        else -> SignInResult.Failed(message)
    }

    private companion object {
        const val SELECTION_EXPIRED = "That choice has expired. Please sign in again."
    }
}

internal fun StoredSession.toSignedIn() = SessionState.SignedIn(
    username = username,
    displayName = displayName,
    activeContext = activeMembership.toAccountContext(),
    availableContexts = memberships.map { it.toAccountContext() },
)
