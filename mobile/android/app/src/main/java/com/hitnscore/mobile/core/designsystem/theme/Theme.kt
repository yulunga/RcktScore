package com.hitnscore.mobile.core.designsystem.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

// No dynamic (wallpaper) colour: the brand must look the same on every phone, as on iOS.
private val LightColors = lightColorScheme(
    primary = BrandBlue,
    onPrimary = Color.White,
    primaryContainer = LightTint,
    onPrimaryContainer = BrandBlueDeep,
    secondary = BrandPink,
    onSecondary = Color.White,
    tertiary = BrandNavy,
    background = LightBackground,
    surface = Color.White,
    surfaceVariant = LightTint,
    onSurfaceVariant = LightMutedText,
    error = CompletedRed,
)

private val DarkColors = darkColorScheme(
    primary = BrandBlue,
    onPrimary = Color.White,
    primaryContainer = DarkTint,
    onPrimaryContainer = Color(0xFFBFDBFF),
    secondary = BrandPink,
    onSecondary = Color.White,
    tertiary = BrandNavy,
    background = DarkBackground,
    surface = DarkSurface,
    surfaceVariant = DarkTint,
    onSurfaceVariant = DarkMutedText,
    error = CompletedRed,
)

/** Brand colours Material 3 has no slot for. Read via `HitNScoreTheme.colors`. */
@Immutable
data class HitNScoreColors(
    val brandPink: Color,
    val navy: Color,
    val card: Color,
    val activeStatus: Color,
    val completedStatus: Color,
    val gameScore: Color,
)

private val LightExtendedColors = HitNScoreColors(
    brandPink = BrandPink,
    navy = BrandNavy,
    card = LightCard,
    activeStatus = ActiveGreen,
    completedStatus = CompletedRed,
    gameScore = GameScoreMustard,
)

private val DarkExtendedColors = LightExtendedColors.copy(card = DarkSurface)

private val LocalHitNScoreColors = staticCompositionLocalOf { LightExtendedColors }

object HitNScoreTheme {
    val colors: HitNScoreColors
        @Composable
        @ReadOnlyComposable
        get() = LocalHitNScoreColors.current
}

@Composable
fun HitNScoreTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    CompositionLocalProvider(
        LocalHitNScoreColors provides if (darkTheme) DarkExtendedColors else LightExtendedColors,
    ) {
        MaterialTheme(
            colorScheme = if (darkTheme) DarkColors else LightColors,
            typography = HitNScoreTypography,
            content = content,
        )
    }
}
