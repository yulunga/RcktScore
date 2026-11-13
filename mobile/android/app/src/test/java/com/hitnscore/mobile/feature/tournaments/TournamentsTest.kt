package com.hitnscore.mobile.feature.tournaments

import com.hitnscore.mobile.data.model.TournamentSummary
import org.junit.Assert.assertEquals
import org.junit.Test

class TournamentsTest {
    @Test
    fun statusLabelsMatchIos() {
        assertEquals("Registration", TournamentsViewModel.statusLabel("registration"))
        assertEquals("Live", TournamentsViewModel.statusLabel("draw_published"))
        assertEquals("In Progress", TournamentsViewModel.statusLabel("IN_PROGRESS"))
        assertEquals("Completed Early", TournamentsViewModel.statusLabel("completed_early"))
    }

    @Test
    fun sortedByStartDateThenName() {
        val items = listOf(
            ClubTournament("A", TournamentSummary(id = "1", name = "Zeta", startsOn = "2027-01-05")),
            ClubTournament("A", TournamentSummary(id = "2", name = "Alpha")),
            ClubTournament("B", TournamentSummary(id = "3", name = "beta", startsOn = "2027-01-05")),
        )
        assertEquals(listOf("3", "1", "2"), TournamentsViewModel.sortTournaments(items).map { it.tournament.id })
    }

    @Test
    fun detailLineShowsSportDatesAndEntries() {
        val t = TournamentSummary(id = "1", sport = "squash", startsOn = "2027-05-03", endsOn = "2027-05-05", entryCount = 1)
        assertEquals("Squash · 3 May 2027–5 May 2027 · 1 entry", detailLine(t))
        assertEquals("Tennis · 12 entries", detailLine(t.copy(sport = "tennis", startsOn = null, entryCount = 12)))
    }
}
