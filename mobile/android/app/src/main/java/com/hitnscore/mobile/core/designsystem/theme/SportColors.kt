package com.hitnscore.mobile.core.designsystem.theme

import androidx.compose.ui.graphics.Color

/** One colour per racket sport, taken from the ball artwork (match cards' sport strip). */
object SportColors {
    val Squash = Color(0xFF1C2B3A)
    val Racketball = Color(0xFF1565C0)
    val Tennis = Color(0xFF7CB342)
    val Padel = Color(0xFFF08A24)

    fun forSport(sport: String?): Color = when (sport?.lowercase()) {
        "racketball", "racquetball" -> Racketball
        "tennis" -> Tennis
        "padel" -> Padel
        else -> Squash
    }
}
