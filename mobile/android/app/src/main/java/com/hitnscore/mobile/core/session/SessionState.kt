package com.hitnscore.mobile.core.session

sealed interface SessionState {
    /** Reading any stored session. The splash screen stays up during this state. */
    data object Restoring : SessionState

    data object SignedOut : SessionState

    data class SignedIn(
        val activeContext: AccountContext,
        val availableContexts: List<AccountContext>,
        /** True for the placeholder preview session used until sign-in ships in M1. */
        val isPreview: Boolean,
    ) : SessionState
}
