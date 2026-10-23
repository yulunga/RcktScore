package com.hitnscore.mobile.data.model

import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.time.format.FormatStyle
import java.util.Locale

/** Display rules shared by the dashboard, history and match screens (ported from iOS). */
object MatchFormatting {

    fun sportName(sport: String?): String = when (sport?.lowercase()) {
        "racketball" -> "Racketball"
        "tennis" -> "Tennis"
        "padel" -> "Padel"
        "table_tennis" -> "Table Tennis"
        "badminton" -> "Badminton"
        "pickleball" -> "Pickleball"
        else -> "Squash"
    }

    fun isTennisStyle(sport: String?, state: MatchState?): Boolean =
        sport?.lowercase() in setOf("tennis", "padel") || state?.scoreDisplayMode?.lowercase() == "tennis"

    /** iOS `fullName`: avoids "Pat Smith Smith" when the first-name field already has the surname. */
    fun fullName(firstName: String, surname: String?): String {
        val first = firstName.trim().ifEmpty { "Player" }
        val last = surname?.trim().orEmpty()
        if (last.isEmpty()) return first
        if (first.split(" ").last().equals(last, ignoreCase = true)) return first
        return "$first $last"
    }

    /** 1 or 2 for the winning side of a completed match, or null when unclear. */
    fun winnerSide(match: MatchSummary): Int? {
        val p1 = match.state?.player1GamesWon ?: 0
        val p2 = match.state?.player2GamesWon ?: 0
        if (p1 > p2) return 1
        if (p2 > p1) return 2
        val winner = (match.winnerName ?: match.state?.winnerName)?.lowercase() ?: return null
        return when (winner) {
            match.player1Name.lowercase() -> 1
            match.player2Name.lowercase() -> 2
            else -> null
        }
    }

    fun gamesLine(state: MatchState?): String = "${state?.player1GamesWon ?: 0} - ${state?.player2GamesWon ?: 0}"

    fun matchDate(match: MatchSummary): Instant? = parseInstant(match.completedAt) ?: parseInstant(match.updatedAt)

    fun parseInstant(value: String?): Instant? {
        if (value.isNullOrBlank()) return null
        return try {
            OffsetDateTime.parse(value).toInstant()
        } catch (offsetMissing: DateTimeParseException) {
            try {
                LocalDateTime.parse(value).toInstant(ZoneOffset.UTC)
            } catch (unreadable: DateTimeParseException) {
                null
            }
        }
    }

    fun localDate(instant: Instant, zone: ZoneId = ZoneId.systemDefault()): LocalDate = instant.atZone(zone).toLocalDate()

    fun dayOfMonth(instant: Instant?): String = instant?.let { localDate(it).dayOfMonth.toString() } ?: "--"

    fun monthYear(instant: Instant?): String =
        instant?.let { DateTimeFormatter.ofPattern("MMM yyyy", Locale.getDefault()).format(it.atZone(ZoneId.systemDefault())) }
            ?: "Unknown"

    fun dateOnly(instant: Instant?): String =
        instant?.let { DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).format(it.atZone(ZoneId.systemDefault())) }
            ?: "Not available"

    fun timeOnly(instant: Instant?): String =
        instant?.let { DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).format(it.atZone(ZoneId.systemDefault())) }
            ?: ""

    /** `MM:SS`, as the iOS historic view. */
    fun clock(seconds: Int): String {
        val value = seconds.coerceAtLeast(0)
        return "%02d:%02d".format(value / 60, value % 60)
    }

    /** "1h 05m" style duration for analytics. */
    fun duration(seconds: Int): String {
        val minutes = seconds.coerceAtLeast(0) / 60
        val hours = minutes / 60
        return if (hours > 0) "${hours}h ${minutes % 60}m" else "${minutes}m"
    }

    fun percentage(value: Double?): String = value?.let { "%.1f%%".format(it) } ?: "—"

    /** Text the history search matches against: names, scores and dates. */
    fun searchText(match: MatchSummary): String = listOf(
        match.player1Name,
        match.player1Surname.orEmpty(),
        match.player2Name,
        match.player2Surname.orEmpty(),
        match.winnerName.orEmpty(),
        sportName(match.sport),
        match.state?.gameHistory?.joinToString(" ") { "${it.player1Score}-${it.player2Score}" }.orEmpty(),
        dateOnly(matchDate(match)),
        matchDate(match)?.let { localDate(it).toString() }.orEmpty(),
    ).joinToString(" ").lowercase()
}
