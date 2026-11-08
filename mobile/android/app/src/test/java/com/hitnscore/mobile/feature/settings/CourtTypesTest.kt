package com.hitnscore.mobile.feature.settings

import com.hitnscore.mobile.feature.newmatch.courtSportKey
import org.junit.Assert.assertEquals
import org.junit.Test

class CourtTypesTest {
    @Test
    fun racketballUsesSquashCourts() {
        assertEquals(CourtTypes.SQUASH, CourtTypes.of("racketball"))
        assertEquals(CourtTypes.SQUASH, CourtTypes.of("Squash"))
        assertEquals(courtSportKey("squash"), courtSportKey("racketball"))
    }

    @Test
    fun onlyTypesForEnabledSportsAreOffered() {
        assertEquals(listOf("squash", "tennis"), CourtTypes.available(listOf("racketball", "tennis")))
        assertEquals(listOf("squash", "tennis", "padel"), CourtTypes.available(listOf("squash", "racketball", "tennis", "padel")))
        assertEquals(emptyList<String>(), CourtTypes.available(emptyList()))
    }
}
