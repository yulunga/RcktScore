package com.hitnscore.mobile.feature.newmatch

import androidx.compose.ui.unit.dp
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SportGridTest {
    @Test
    fun landscapeTabletPutsFourSportsInOneRow() {
        val grid = sportGrid(4, maxW = 700.dp, maxH = 300.dp, gap = 12.dp)
        assertEquals(4, grid.columns)
        assertTrue(grid.tile * 1 <= 300.dp)
    }

    @Test
    fun portraitPhoneUsesTwoByTwo() {
        val grid = sportGrid(4, maxW = 330.dp, maxH = 520.dp, gap = 12.dp)
        assertEquals(2, grid.columns)
    }

    @Test
    fun cardsNeverOverflowTheSpace() {
        listOf(1, 2, 3, 4).forEach { n ->
            val grid = sportGrid(n, maxW = 500.dp, maxH = 260.dp, gap = 12.dp)
            val rows = (n + grid.columns - 1) / grid.columns
            assertTrue(grid.width <= 500.dp)
            assertTrue(grid.tile * rows + 12.dp * (rows - 1) <= 260.dp)
        }
    }
}
