package com.hitnscore.mobile.feature

import com.hitnscore.mobile.data.model.GameHistoryEntry
import com.hitnscore.mobile.data.model.MatchState
import com.hitnscore.mobile.data.model.MatchSummary
import com.hitnscore.mobile.feature.matches.filterHistory
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Test

class HistoryFilterTest {
    private fun match(id: String, sport: String, date: String, p1: String = "Pat", p2: String = "Sam") = MatchSummary(
        id = id,
        player1Name = p1,
        player2Name = p2,
        sport = sport,
        status = "completed",
        completedAt = "${date}T12:00:00+00:00",
        state = MatchState(gameHistory = listOf(GameHistoryEntry(1, 11, 7))),
    )

    private val locked = MatchSummary(id = "locked-history-preview", status = "locked", locked = true)
    private val all = listOf(
        match("a", "squash", "2026-10-01"),
        match("b", "tennis", "2026-10-10", p2 = "Alex"),
        match("c", "squash", "2026-10-20"),
        locked,
    )

    @Test
    fun noFiltersKeepsEverythingIncludingTheLockedPreview() {
        assertEquals(4, filterHistory(all, "", null, null, null).size)
    }

    @Test
    fun searchMatchesNamesAndScores() {
        assertEquals(listOf("b"), filterHistory(all, "alex", null, null, null).map { it.id })
        assertEquals(3, filterHistory(all, "11-7", null, null, null).size)
    }

    @Test
    fun sportAndInclusiveDateRangeCombine() {
        assertEquals(listOf("a", "c"), filterHistory(all, "", "squash", null, null).map { it.id })
        assertEquals(
            listOf("b", "c"),
            filterHistory(all, "", null, LocalDate.parse("2026-10-10"), LocalDate.parse("2026-10-20")).map { it.id },
        )
        assertEquals(listOf("b"), filterHistory(all, "", null, LocalDate.parse("2026-10-10"), null).map { it.id })
    }
}
