package com.hitnscore.mobile.core.session

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PreviewSessionRepositoryTest {
    @Test
    fun restoreMovesFromRestoringToSignedOut() = runTest {
        val repository = PreviewSessionRepository()
        assertEquals(SessionState.Restoring, repository.state.value)
        repository.restore()
        assertEquals(SessionState.SignedOut, repository.state.value)
    }

    @Test
    fun previewSessionHasNoTokenAndCanSwitchContext() = runTest {
        val repository = PreviewSessionRepository()
        repository.restore()
        repository.startPreviewSession()
        assertNull(repository.currentAccessToken())

        val club = PreviewSessionRepository.previewContexts.last()
        repository.selectContext(club)
        val state = repository.state.value as SessionState.SignedIn
        assertEquals(club, state.activeContext)
        assertTrue(state.isPreview)
    }

    @Test
    fun unknownContextIsIgnoredAndSignOutClearsSession() = runTest {
        val repository = PreviewSessionRepository()
        repository.startPreviewSession()
        val stranger = AccountContext(99, 99, "Other", AccountContextType.Club, "member", "Club Pro")
        repository.selectContext(stranger)
        assertEquals(
            PreviewSessionRepository.previewContexts.first(),
            (repository.state.value as SessionState.SignedIn).activeContext,
        )
        repository.signOut()
        assertEquals(SessionState.SignedOut, repository.state.value)
    }
}
