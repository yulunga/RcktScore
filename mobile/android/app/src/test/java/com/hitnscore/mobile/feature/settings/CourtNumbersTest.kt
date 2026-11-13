package com.hitnscore.mobile.feature.settings

import com.hitnscore.mobile.data.model.CourtSummary
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CourtNumbersTest {
    private val courts = listOf(
        CourtSummary(id = 1, courtName = "Court-1", sport = "squash"),
        CourtSummary(id = 2, courtName = "Court-3", sport = "racketball"),
        CourtSummary(id = 3, courtName = "Court-1", sport = "tennis"),
    )

    @Test
    fun planLimitsMatchIos() {
        assertEquals(5, CourtTypes.numberLimit("club_essentials"))
        assertEquals(25, CourtTypes.numberLimit("CLUB_PRO"))
        assertNull(CourtTypes.numberLimit("personal_free"))
    }

    @Test
    fun unusedNumbersArePerCourtType() {
        assertEquals(listOf("Court-2", "Court-4", "Court-5"), CourtTypes.numberOptions(courts, 5, "squash", null, ""))
        assertEquals(listOf("Court-2", "Court-3", "Court-4", "Court-5"), CourtTypes.numberOptions(courts, 5, "tennis", null, ""))
    }

    @Test
    fun editingKeepsTheCourtsOwnNumber() {
        assertEquals(listOf("Court-1", "Court-2", "Court-4", "Court-5"), CourtTypes.numberOptions(courts, 5, "squash", 1, "Court-1"))
        assertEquals("Court-9", CourtTypes.numberOptions(courts, 5, "squash", 1, "Court-9").first())
    }
}
