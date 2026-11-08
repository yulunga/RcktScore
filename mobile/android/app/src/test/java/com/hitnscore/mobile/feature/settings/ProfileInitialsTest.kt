package com.hitnscore.mobile.feature.settings

import org.junit.Assert.assertEquals
import org.junit.Test

class ProfileInitialsTest {
    @Test
    fun firstTwoNamesGiveTheInitials() {
        assertEquals("PP", profileInitials("pat  player"))
        assertEquals("MJ", profileInitials("Mary Jane Smith"))
        assertEquals("C", profileInitials(" Court1 "))
    }

    @Test
    fun noNameFallsBackToTheBrand() {
        assertEquals("HS", profileInitials("  "))
    }
}
