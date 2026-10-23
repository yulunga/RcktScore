package com.hitnscore.mobile.core.designsystem.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

private val Base = Typography()

/** HitNScore type scale: system font, heavier headings to match the iOS hierarchy. */
internal val HitNScoreTypography = Base.copy(
    displaySmall = Base.displaySmall.copy(fontWeight = FontWeight.Bold),
    headlineMedium = Base.headlineMedium.copy(fontWeight = FontWeight.Bold),
    headlineSmall = Base.headlineSmall.copy(fontWeight = FontWeight.Bold),
    titleLarge = Base.titleLarge.copy(fontWeight = FontWeight.SemiBold),
    titleMedium = Base.titleMedium.copy(fontWeight = FontWeight.SemiBold),
    labelLarge = Base.labelLarge.copy(fontWeight = FontWeight.SemiBold),
)

/**
 * Score numerals use tabular (fixed-width) figures so digits never shift
 * position as the score changes (approved UX change 5).
 */
object ScoreTextStyles {
    private const val TABULAR_FIGURES = "tnum"

    val Large = TextStyle(
        fontWeight = FontWeight.Black,
        fontSize = 72.sp,
        lineHeight = 76.sp,
        letterSpacing = (-1).sp,
        fontFeatureSettings = TABULAR_FIGURES,
    )

    val Medium = TextStyle(
        fontWeight = FontWeight.ExtraBold,
        fontSize = 40.sp,
        lineHeight = 44.sp,
        fontFeatureSettings = TABULAR_FIGURES,
    )

    val Small = TextStyle(
        fontWeight = FontWeight.SemiBold,
        fontSize = 20.sp,
        lineHeight = 24.sp,
        fontFeatureSettings = TABULAR_FIGURES,
    )
}
