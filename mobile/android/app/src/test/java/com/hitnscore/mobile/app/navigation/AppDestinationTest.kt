package com.hitnscore.mobile.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AppDestinationTest {
    @Test
    fun topLevelDestinationsMatchTheCurrentIosNavigation() {
        assertEquals(
            listOf("Home", "Matches", "Analytics", "Settings", "Need Help"),
            AppDestination.topLevel.map { it.label },
        )
    }

    @Test
    fun routesAreUnique() {
        val routes = AppDestination.topLevel.map { it.route }
        assertTrue(routes.size == routes.toSet().size)
    }
}
