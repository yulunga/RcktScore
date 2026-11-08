package com.hitnscore.mobile.feature.newmatch

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** "Me" as referee, matching the web client's New Match page. */
class RefereeSelectionTest {
    private fun state(isPersonal: Boolean = false, me: String = "Glenn Rowe", form: MatchSetupForm = MatchSetupForm()) =
        MatchSetupUiState(
            args = SetupArgs(
                sport = "squash",
                organizationId = 7,
                isPersonal = isPersonal,
                isPersonalPlus = false,
                sessionSports = listOf("squash"),
                activeMatches = emptyList(),
                signedInUser = SignedInPerson(me, "glenn@example.com"),
            ),
            form = form,
        )

    @Test
    fun `signed in player is found ignoring case and spacing`() {
        assertTrue(isSignedInUserPlaying(MatchSetupForm(player1Name = "  glenn ", player1Surname = " ROWE"), "Glenn  Rowe"))
    }

    @Test
    fun `signed in player is found in a doubles position`() {
        val form = MatchSetupForm(doubles = true, player1Name = "A", player2Name = "B", player3Name = "Glenn", player3Surname = "Rowe", player4Name = "D")
        assertTrue(isSignedInUserPlaying(form, "Glenn Rowe"))
    }

    @Test
    fun `someone else playing leaves Me available`() {
        val state = state(form = MatchSetupForm(player1Name = "Alex", player1Surname = "Smith"))
        assertFalse(state.signedInUserIsPlaying)
        assertTrue(state.canRefereeAsMe)
    }

    @Test
    fun `Me is unavailable while playing, for personal matches and without a name`() {
        assertFalse(state(form = MatchSetupForm(player2Name = "Glenn", player2Surname = "Rowe")).canRefereeAsMe)
        assertFalse(state(isPersonal = true).canRefereeAsMe)
        assertFalse(state(me = " ").canRefereeAsMe)
    }

    @Test
    fun `typing your own name as referee while playing blocks the club match`() {
        val form = MatchSetupForm(player1Name = "Glenn", player1Surname = "Rowe", refereeName = " glenn rowe ")
        assertTrue(state(form = form).refereeConflict)
        assertFalse(state(form = form.copy(refereeName = "Pat Ref")).refereeConflict)
        assertFalse(state(isPersonal = true, form = form).refereeConflict)
    }

    @Test
    fun `Me uses the full name, then first name and surname, then the username`() {
        assertEquals("Glenn Rowe", signedInPersonName(" Glenn Rowe ", "G", "R", "g@x.com"))
        assertEquals("Glenn Rowe", signedInPersonName("", " Glenn ", "Rowe", "g@x.com"))
        assertEquals("rackets", signedInPersonName(null, null, null, "rackets@calsa.co.uk"))
    }
}
