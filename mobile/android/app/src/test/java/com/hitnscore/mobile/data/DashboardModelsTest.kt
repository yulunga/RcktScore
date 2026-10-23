package com.hitnscore.mobile.data

import com.hitnscore.mobile.core.network.ApiResponseParser
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.data.model.DashboardResponseData
import com.hitnscore.mobile.data.model.MatchFormatting
import com.hitnscore.mobile.data.model.MatchResponseData
import com.hitnscore.mobile.feature.matches.MatchTimeline
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DashboardModelsTest {
    // Same configuration as AppContainer.
    private val parser = ApiResponseParser(Json { ignoreUnknownKeys = true; coerceInputValues = true })

    @Test
    fun decodesDashboardIncludingLockedPreviewAndNulls() {
        val dashboard = (parser.parse(200, DashboardFixtures.dashboard, DashboardResponseData.serializer()) as ApiResult.Success)
            .value.dashboard
        assertEquals("personal_free", dashboard.organization?.plan)
        assertEquals(10, dashboard.organization?.entitlements?.historyLimit)
        assertEquals("m-live", dashboard.activeMatches.single().matchId)
        assertEquals("2 - 1", MatchFormatting.gamesLine(dashboard.activeMatches.single().state))
        assertTrue(dashboard.recentMatches.last().locked)
        assertNull(dashboard.recentMatches.first().bestOf)
        assertNull(dashboard.performance)
    }

    @Test
    fun winnerSideComesFromGamesThenName() {
        val recent = (parser.parse(200, DashboardFixtures.dashboard, DashboardResponseData.serializer()) as ApiResult.Success)
            .value.dashboard.recentMatches.first()
        assertEquals(2, MatchFormatting.winnerSide(recent))
        assertEquals("Racketball", MatchFormatting.sportName(recent.sport))
    }

    @Test
    fun timelineGroupsPointsByGameWithDurationsAndRunningScore() {
        val match = (parser.parse(200, DashboardFixtures.squashMatch, MatchResponseData.serializer()) as ApiResult.Success)
            .value.match
        val timeline = MatchTimeline.from(match)

        assertEquals(false, timeline.isTennisStyle)
        assertEquals(listOf(1, 2), timeline.games.map { it.gameNumber })
        val first = timeline.games.first()
        assertEquals(2, first.entries.size)
        assertEquals("1-0", first.entries.first().score)
        assertEquals("R", first.entries.first().serviceSideLabel)
        assertEquals(600, first.durationSeconds)
        assertEquals("1–0", first.gamesScoreAfter)
        assertEquals("2–0", timeline.games.last().gamesScoreAfter)
        assertEquals("player2", timeline.games.last().entries.first().winnerSide)
        // Recorded 30 s is stale; the derived game times win.
        assertEquals(600 + 480, timeline.totalDurationSeconds)
    }

    @Test
    fun tennisScoreLabels() {
        assertEquals("15-0", MatchTimeline.tennisScore(1, 0, tieBreak = false))
        assertEquals("Deuce", MatchTimeline.tennisScore(3, 3, tieBreak = false))
        assertEquals("Advantage-40", MatchTimeline.tennisScore(4, 3, tieBreak = false))
        assertEquals("6-4", MatchTimeline.tennisScore(6, 4, tieBreak = true))
    }

    @Test
    fun fullNameAvoidsRepeatingTheSurname() {
        assertEquals("Pat Player", MatchFormatting.fullName("Pat Player", "Player"))
        assertEquals("Pat Player", MatchFormatting.fullName("Pat", "Player"))
        assertEquals("Player", MatchFormatting.fullName(" ", null))
        assertEquals("01:05", MatchFormatting.clock(65))
        assertEquals("1h 5m", MatchFormatting.duration(3900))
    }
}
