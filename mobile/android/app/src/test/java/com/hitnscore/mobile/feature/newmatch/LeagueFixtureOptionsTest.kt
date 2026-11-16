package com.hitnscore.mobile.feature.newmatch

import com.hitnscore.mobile.data.model.AssociationCompetition
import com.hitnscore.mobile.data.model.AssociationCompetitionDivision
import com.hitnscore.mobile.data.model.AssociationCompetitionFixture
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LeagueFixtureOptionsTest {
    private val fixtureA = AssociationCompetitionFixture("2026-12-01", "Lincoln", "home")
    private val fixtureB = AssociationCompetitionFixture("2026-11-20", "Newark", "away")

    @Test
    fun onlyLeaguesSwitchedOnForMatchSetupAreOffered() {
        val options = leagueFixtureOptions(
            listOf(
                AssociationCompetition("Notts League", "league", listOf(AssociationCompetitionDivision("Div 1", null, listOf(fixtureA))), matchSetupEnabled = true),
                AssociationCompetition("Hidden League", "league", listOf(AssociationCompetitionDivision("Div 2", null, listOf(fixtureB))), matchSetupEnabled = false),
            ),
        )
        assertEquals(listOf("Notts League"), options.map { it.competitionName })
    }

    @Test
    fun soonestGameFirstAndLegacyFixturesUseGeneral() {
        val options = leagueFixtureOptions(
            listOf(
                AssociationCompetition("Notts League", "league", listOf(AssociationCompetitionDivision("Div 1", null, listOf(fixtureA))), matchSetupEnabled = true),
                AssociationCompetition("Inter-club", "interclub", fixtures = listOf(fixtureB), matchSetupEnabled = true),
            ),
        )
        assertEquals(listOf("2026-11-20", "2026-12-01"), options.map { it.fixture.date })
        assertEquals("Inter-club · General", options.first().heading)
        assertEquals("20 Nov 2026 · Away vs Newark", options.first().detail)
    }

    @Test
    fun noEnabledLeaguesMeansNoOptions() {
        assertTrue(leagueFixtureOptions(emptyList()).isEmpty())
    }
}
