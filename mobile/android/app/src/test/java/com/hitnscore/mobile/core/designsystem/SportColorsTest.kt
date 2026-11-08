package com.hitnscore.mobile.core.designsystem

import com.hitnscore.mobile.core.designsystem.theme.SportColors
import org.junit.Assert.assertEquals
import org.junit.Test

class SportColorsTest {
    @Test
    fun eachSportHasItsBallColour() {
        assertEquals(SportColors.Squash, SportColors.forSport("squash"))
        assertEquals(SportColors.Racketball, SportColors.forSport("Racketball"))
        assertEquals(SportColors.Tennis, SportColors.forSport("tennis"))
        assertEquals(SportColors.Padel, SportColors.forSport("PADEL"))
        assertEquals(SportColors.Squash, SportColors.forSport(null))
    }
}
