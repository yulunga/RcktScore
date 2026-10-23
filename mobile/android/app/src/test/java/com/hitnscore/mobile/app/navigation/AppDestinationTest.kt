package com.hitnscore.mobile.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AppDestinationTest {
    @Test
    fun topLevelDestinationsMatchTheIosTabOrder() {
        assertEquals(
            listOf("home", "matches", "analytics", "settings", "help"),
            AppDestination.topLevel.map { it.route },
        )
    }

    @Test
    fun routesAreUnique() {
        val routes = AppDestination.topLevel.map { it.route }
        assertTrue(routes.size == routes.toSet().size)
    }

    @Test
    fun accessingAnObjectFirstStillYieldsACompleteList() {
        // Guards against the sealed-class initialisation-order bug.
        assertEquals("help", AppDestination.Help.route)
        assertEquals(5, AppDestination.topLevel.map { it.route }.size)
    }
}
