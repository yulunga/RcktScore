package com.hitnscore.mobile.core.session

/** Why the user was returned to sign-in, so the screen can explain it. */
enum class SignOutReason {
    /** The user chose to sign out. */
    UserRequested,

    /** The server-provided expiry passed. */
    Expired,

    /** The account signed in on another device. */
    Replaced,

    /** The backend ended the session for another reason. */
    Ended,
}

sealed interface SessionState {
    /** Reading any stored session. The splash screen stays up during this state. */
    data object Restoring : SessionState

    data class SignedOut(val reason: SignOutReason = SignOutReason.UserRequested) : SessionState

    /** A valid session exists but biometric / screen-lock unlock is required first. */
    data class Locked(val displayName: String) : SessionState

    data class SignedIn(
        val username: String,
        val displayName: String,
        val activeContext: AccountContext,
        val availableContexts: List<AccountContext>,
    ) : SessionState
}

/** Outcome of a sign-in attempt, for the sign-in screen. */
sealed interface SignInResult {
    data object Success : SignInResult

    /** The account is signed in on another phone. Retry with force to sign that one out. */
    data class SessionConflict(val message: String) : SignInResult

    /** Legacy backend mode: the user must pick an organisation. */
    data class ChooseAccount(val choices: List<AccountContext>) : SignInResult

    data class Failed(val message: String) : SignInResult
}
