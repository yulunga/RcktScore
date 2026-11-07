package com.hitnscore.mobile.core.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PasswordLinkTest {
    private val token = "AbCdEfGh12345678xyz"

    @Test
    fun wholeResetLinkIsRead() {
        val link = PasswordLink.fromText("https://app.hitnscore.com/help?mode=reset&token=$token")
        assertEquals(PasswordLink(token, isAccountSetup = false), link)
    }

    @Test
    fun confirmEmailLinkIsAnAccountSetup() {
        val link = PasswordLink.fromText("  https://app.hitnscore.com/help?mode=confirm-email&token=setup_$token#top \n")
        assertEquals(PasswordLink("setup_$token", isAccountSetup = true), link)
    }

    @Test
    fun encodedTokenIsDecoded() {
        assertEquals("a+b/c=", PasswordLink.fromText("help?mode=reset&token=a%2Bb%2Fc%3D")?.token)
    }

    @Test
    fun bareTokenIsAccepted() {
        assertEquals(PasswordLink(token, false), PasswordLink.fromText(token))
        assertTrue(PasswordLink.fromText("setup_$token")!!.isAccountSetup)
    }

    @Test
    fun linksWithoutATokenOrWithAnotherModeAreRefused() {
        assertNull(PasswordLink.fromText("https://app.hitnscore.com/help?section=privacy"))
        assertNull(PasswordLink.fromText("https://app.hitnscore.com/help?mode=login&token=$token"))
        assertNull(PasswordLink.fromText("https://app.hitnscore.com/help?mode=reset&token="))
        assertNull(PasswordLink.fromText("short"))
        assertNull(PasswordLink.fromText(""))
    }

    @Test
    fun buildTreatsASetupTokenAsSetupEvenWithoutAMode() {
        assertTrue(PasswordLink.build(null, "setup_abc")!!.isAccountSetup)
        assertFalse(PasswordLink.build("reset", "abc")!!.isAccountSetup)
    }

    @Test
    fun inboxIgnoresNullAndClears() {
        val inbox = PasswordLinkInbox()
        inbox.deliver(null)
        assertNull(inbox.pending.value)
        inbox.deliver(PasswordLink(token, false))
        assertEquals(token, inbox.pending.value?.token)
        inbox.clear()
        assertNull(inbox.pending.value)
    }
}
