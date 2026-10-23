package com.hitnscore.mobile.core.designsystem.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val ColorWhite = Color.White

private val LightColors = lightColorScheme(
    primary = BrandBlue,
    secondary = BrandPink,
    tertiary = BrandNavy,
    background = LightBackground,
    surface = ColorWhite,
)

private val DarkColors = darkColorScheme(
    primary = BrandBlue,
    secondary = BrandPink,
    tertiary = BrandNavy,
    background = DarkBackground,
    surface = DarkSurface,
)

@Composable
fun HitNScoreTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        typography = HitNScoreTypography,
        content = content,
    )
}
