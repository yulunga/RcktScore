package com.hitnscore.mobile.feature.scoring

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MatchTimerTest {
    private fun MatchTimer.ticks(n: Int): MatchTimer = (1..n).fold(this) { t, _ -> t.tick() }

    @Test
    fun warmupRunsBothSidesThenWaitsForFirstServer() {
        val start = MatchTimer.initial(isScheduled = false, isComplete = false, isFresh = true, timedBreaks = true, recordedDuration = 0)
        assertEquals(TimerPhase.WarmupReady, start.phase)

        val sideOne = start.togglePause()
        assertEquals(TimerPhase.WarmupSideOne, sideOne.phase)
        val sideTwo = sideOne.ticks(60)
        assertEquals(TimerPhase.WarmupSideTwo, sideTwo.phase)
        assertEquals(60, sideTwo.seconds)
        val firstServer = sideTwo.ticks(60)
        assertEquals(TimerPhase.FirstServer, firstServer.phase)
        assertFalse(firstServer.running)
        // The clock cannot be started from first-server; choosing a server does that.
        assertEquals(firstServer, firstServer.togglePause())
        assertEquals(TimerPhase.MatchLive, firstServer.beginLive().phase)
    }

    @Test
    fun liveClockCountsUpAndPauses() {
        val live = MatchTimer.initial(isScheduled = false, isComplete = false, isFresh = false, timedBreaks = false, recordedDuration = 100)
        assertTrue(live.running)
        assertEquals(103, live.ticks(3).displaySeconds)
        val paused = live.togglePause()
        assertEquals(100, paused.ticks(5).matchDurationSeconds)
    }

    @Test
    fun gameBreakReturnsToLiveAndCanBeSkipped() {
        val live = MatchTimer(phase = TimerPhase.MatchLive, running = true, matchDurationSeconds = 600)
        val interval = live.beginInterval()
        assertEquals(90, interval.displaySeconds)
        val back = interval.ticks(90)
        assertEquals(TimerPhase.MatchLive, back.phase)
        assertEquals(600, back.matchDurationSeconds)
        assertEquals(TimerPhase.MatchLive, interval.skip().phase)
    }

    @Test
    fun catchesUpAfterTheAppWasClosed() {
        val saved = MatchTimer(phase = TimerPhase.MatchLive, running = true, matchDurationSeconds = 60, updatedAtMillis = 1_000_000)
        assertEquals(60 + 45, saved.advancedTo(1_045_000).matchDurationSeconds)

        val breakSaved = MatchTimer(phase = TimerPhase.Interval, running = true, seconds = 30, matchDurationSeconds = 500, updatedAtMillis = 1_000_000)
        val resumed = breakSaved.advancedTo(1_040_000)
        assertEquals(TimerPhase.MatchLive, resumed.phase)
        assertEquals(510, resumed.matchDurationSeconds)
    }

    @Test
    fun scheduledAndCompletedMatchesStartStopped() {
        assertFalse(MatchTimer.initial(isScheduled = true, isComplete = false, isFresh = true, timedBreaks = true, recordedDuration = 0).running)
        val done = MatchTimer.initial(isScheduled = false, isComplete = true, isFresh = false, timedBreaks = false, recordedDuration = 1500)
        assertFalse(done.running)
        assertEquals(1500, done.displaySeconds)
    }

    @Test
    fun tennisWarmupIsOneFiveMinutePeriod() {
        val start = MatchTimer.initial(isScheduled = false, isComplete = false, isFresh = true, timedBreaks = true, recordedDuration = 0, isTennis = true)
        assertEquals(TimerPhase.WarmupReady, start.phase)
        val running = start.togglePause()
        assertEquals(300, running.seconds)
        val next = running.ticks(300)
        assertEquals(TimerPhase.FirstServer, next.phase)
        assertFalse(next.running)
    }

    @Test
    fun freshTennisWithoutTimedBreaksAsksForTheOpeningServer() {
        val start = MatchTimer.initial(isScheduled = false, isComplete = false, isFresh = true, timedBreaks = false, recordedDuration = 0, isTennis = true)
        assertEquals(TimerPhase.FirstServer, start.phase)
        assertFalse(start.running)
    }

    @Test
    fun tennisSetBreakLastsTwoMinutes() {
        val live = MatchTimer.initial(isScheduled = false, isComplete = false, isFresh = false, timedBreaks = true, recordedDuration = 0, isTennis = true)
        val setBreak = live.beginInterval(MatchTimer.TENNIS_SET_BREAK_SECONDS)
        assertEquals(120, setBreak.seconds)
        assertEquals(TimerPhase.MatchLive, setBreak.ticks(120).phase)
    }
}
