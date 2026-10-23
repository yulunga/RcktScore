package com.hitnscore.mobile.core.session

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/** Single source of truth for who is signed in and which account context is active. */
interface SessionRepository {
    val state: StateFlow<SessionState>

    /** Bearer token for API calls, or null when signed out. */
    fun currentAccessToken(): String?

    suspend fun restore()

    fun startPreviewSession()

    fun selectContext(context: AccountContext)

    fun signOut()
}

/**
 * In-memory stand-in until M1 adds backend sign-in and encrypted storage.
 * Holds no token, so no authenticated request can be made with it.
 */
class PreviewSessionRepository : SessionRepository {
    private val mutableState = MutableStateFlow<SessionState>(SessionState.Restoring)
    override val state: StateFlow<SessionState> = mutableState.asStateFlow()

    override fun currentAccessToken(): String? = null

    override suspend fun restore() {
        mutableState.update { if (it is SessionState.Restoring) SessionState.SignedOut else it }
    }

    override fun startPreviewSession() {
        mutableState.value = SessionState.SignedIn(
            activeContext = previewContexts.first(),
            availableContexts = previewContexts,
            isPreview = true,
        )
    }

    override fun selectContext(context: AccountContext) {
        mutableState.update { current ->
            if (current is SessionState.SignedIn && context in current.availableContexts) {
                current.copy(activeContext = context)
            } else {
                current
            }
        }
    }

    override fun signOut() {
        mutableState.value = SessionState.SignedOut
    }

    companion object {
        val previewContexts: List<AccountContext> = listOf(
            AccountContext(1, 50_001, "Personal", AccountContextType.Personal, "admin", "Personal Free"),
            AccountContext(2, 42, "Demo Club", AccountContextType.Club, "admin", "Club Essentials"),
        )
    }
}
