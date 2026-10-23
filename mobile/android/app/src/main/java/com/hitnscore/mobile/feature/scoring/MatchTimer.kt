package com.hitnscore.mobile.feature.scoring

import kotlinx.serialization.Serializable

/** Phases of the scorer's clock, as iOS `MatchTimerPhase`. */
@Serializable
enum class TimerPhase { WarmupReady, WarmupSideOne, WarmupSideTwo, FirstServer, Interval, MatchLive }

/**
 * The scorer's clock. Pure and immutable, so it can be saved, restored after the app
 * is closed, and unit-tested. Squash/racketball: 60 s warm-up per side, then 90 s
 * breaks between games when timed breaks are on. Tennis/Padel: one 5-minute warm-up,
 * 90 s changeovers after odd games and 120 s between sets (as iOS).
 */
@Serializable
data class MatchTimer(
    val phase: TimerPhase = TimerPhase.MatchLive,
    val running: Boolean = false,
    /** Countdown seconds in warm-up and interval phases. */
    val seconds: Int = 0,
    /** Elapsed live match time. */
    val matchDurationSeconds: Int = 0,
    val intervalDurationSeconds: Int = INTERVAL_SECONDS,
    /** Length of each warm-up side. */
    val warmupSeconds: Int = WARMUP_SECONDS,
    /** 2 for squash/racketball (one per side of the court), 1 for tennis/Padel. */
    val warmupSides: Int = 2,
    /** Wall-clock millis when this snapshot was taken, used to catch up after a restart. */
    val updatedAtMillis: Long = 0,
) {
    val displaySeconds: Int
        get() = if (phase == TimerPhase.MatchLive) matchDurationSeconds else seconds

    val isCountdownWarning: Boolean
        get() = running && (phase == TimerPhase.WarmupSideOne || phase == TimerPhase.WarmupSideTwo) && seconds in 1..10

    fun tick(): MatchTimer {
        if (!running) return this
        return when (phase) {
            TimerPhase.MatchLive -> copy(matchDurationSeconds = matchDurationSeconds + 1)
            TimerPhase.WarmupSideOne, TimerPhase.WarmupSideTwo, TimerPhase.Interval -> {
                val next = (seconds - 1).coerceAtLeast(0)
                if (next == 0) copy(seconds = 0).elapsed() else copy(seconds = next)
            }
            TimerPhase.WarmupReady, TimerPhase.FirstServer -> copy(running = false)
        }
    }

    /** A countdown reached zero. */
    private fun elapsed(): MatchTimer = when (phase) {
        TimerPhase.WarmupSideOne ->
            if (warmupSides >= 2) {
                copy(phase = TimerPhase.WarmupSideTwo, seconds = warmupSeconds, running = true)
            } else {
                copy(phase = TimerPhase.FirstServer, seconds = 0, running = false)
            }
        TimerPhase.WarmupSideTwo -> copy(phase = TimerPhase.FirstServer, seconds = 0, running = false)
        TimerPhase.Interval -> copy(phase = TimerPhase.MatchLive, running = true)
        else -> this
    }

    fun startWarmup() = copy(phase = TimerPhase.WarmupSideOne, seconds = warmupSeconds, matchDurationSeconds = 0, running = true)

    /** Skip warm-up (to first server) or skip a break (back to live). */
    fun skip(): MatchTimer = when (phase) {
        TimerPhase.WarmupReady, TimerPhase.WarmupSideOne, TimerPhase.WarmupSideTwo ->
            copy(phase = TimerPhase.FirstServer, seconds = 0, running = false)
        TimerPhase.Interval -> copy(phase = TimerPhase.MatchLive, running = true)
        else -> this
    }

    fun togglePause(): MatchTimer = when (phase) {
        TimerPhase.WarmupReady -> startWarmup()
        TimerPhase.FirstServer -> this
        else -> copy(running = !running)
    }

    fun beginLive() = copy(phase = TimerPhase.MatchLive, running = true)

    fun beginInterval(durationSeconds: Int = INTERVAL_SECONDS) =
        copy(phase = TimerPhase.Interval, seconds = durationSeconds, intervalDurationSeconds = durationSeconds, running = true)

    fun stopped(durationSeconds: Int) = copy(phase = TimerPhase.MatchLive, running = false, matchDurationSeconds = durationSeconds)

    /** Catch up on the seconds that passed while the app was closed. */
    fun advancedTo(nowMillis: Long): MatchTimer {
        if (!running || updatedAtMillis <= 0) return this
        var timer = this
        var remaining = ((nowMillis - updatedAtMillis) / 1000).coerceAtLeast(0)
        // Each countdown phase is at most a few minutes, so this loop is short.
        while (remaining > 0 && timer.running) {
            if (timer.phase == TimerPhase.MatchLive) {
                timer = timer.copy(matchDurationSeconds = timer.matchDurationSeconds + remaining.toInt())
                remaining = 0
            } else {
                timer = timer.tick()
                remaining--
            }
        }
        return timer
    }

    companion object {
        const val WARMUP_SECONDS = 60
        const val INTERVAL_SECONDS = 90
        const val TENNIS_WARMUP_SECONDS = 300
        const val TENNIS_SET_BREAK_SECONDS = 120

        /** Starting clock for a match the scorer has just opened, as iOS `bootstrapTimerIfNeeded`. */
        fun initial(
            isScheduled: Boolean,
            isComplete: Boolean,
            isFresh: Boolean,
            timedBreaks: Boolean,
            recordedDuration: Int,
            isTennis: Boolean = false,
        ): MatchTimer {
            val base = if (isTennis) MatchTimer(warmupSeconds = TENNIS_WARMUP_SECONDS, warmupSides = 1) else MatchTimer()
            return when {
                isScheduled -> base.copy(phase = TimerPhase.MatchLive, running = false)
                isComplete -> base.copy(phase = TimerPhase.MatchLive, running = false, matchDurationSeconds = recordedDuration)
                isFresh && timedBreaks -> base.copy(phase = TimerPhase.WarmupReady, seconds = base.warmupSeconds)
                // Tennis/Padel always confirm the opening server (and receiver for doubles) first.
                isFresh && isTennis -> base.copy(phase = TimerPhase.FirstServer, running = false)
                else -> base.copy(phase = TimerPhase.MatchLive, running = true, matchDurationSeconds = recordedDuration)
            }
        }
    }
}
