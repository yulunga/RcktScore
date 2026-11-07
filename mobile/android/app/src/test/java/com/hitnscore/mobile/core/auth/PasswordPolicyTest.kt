package com.hitnscore.mobile.core.auth

import com.hitnscore.mobile.core.auth.PasswordPolicy.Rule
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PasswordPolicyTest {
    @Test
    fun strongPasswordPasses() {
        assertTrue(PasswordPolicy.isValid("Rally-Point7"))
    }

    @Test
    fun eachMissingRuleIsReported() {
        assertEquals(listOf(Rule.Length), PasswordPolicy.unmet("Ab1!x"))
        assertEquals(listOf(Rule.Uppercase), PasswordPolicy.unmet("rally-point7"))
        assertEquals(listOf(Rule.Number), PasswordPolicy.unmet("Rally-Point"))
        assertEquals(listOf(Rule.Symbol), PasswordPolicy.unmet("RallyPoint7"))
    }

    @Test
    fun spacesDoNotCountAsASymbol() {
        assertTrue(Rule.Symbol in PasswordPolicy.unmet("Rally Point7"))
    }

    @Test
    fun commonTermsAreRefusedEvenWhenDisguised() {
        assertEquals(listOf(Rule.NotCommon), PasswordPolicy.unmet("My-Password9"))
        assertEquals(listOf(Rule.NotCommon), PasswordPolicy.unmet("Hit-N-Score1"))
        assertFalse(PasswordPolicy.isValid("Qwerty!234"))
    }

    @Test
    fun emptyPasswordFailsEveryRule() {
        assertEquals(Rule.entries.toList(), PasswordPolicy.unmet(""))
    }
}
