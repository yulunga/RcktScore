package com.hitnscore.mobile.app.navigation

import androidx.annotation.DrawableRes
import androidx.annotation.StringRes
import com.hitnscore.mobile.R

/** Top-level tabs, in the same order as the iOS app. */
sealed class AppDestination(
    val route: String,
    @param:StringRes val labelRes: Int,
    @param:DrawableRes val iconRes: Int,
) {
    data object Home : AppDestination("home", R.string.tab_home, R.drawable.ic_tab_home)
    data object Matches : AppDestination("matches", R.string.tab_matches, R.drawable.ic_tab_matches)
    data object Analytics : AppDestination("analytics", R.string.tab_analytics, R.drawable.ic_tab_analytics)
    data object Settings : AppDestination("settings", R.string.tab_settings, R.drawable.ic_tab_settings)
    data object Help : AppDestination("help", R.string.tab_help, R.drawable.ic_tab_help)

    companion object {
        // Lazy: an eager list here can capture a null object during sealed-class initialisation.
        val topLevel: List<AppDestination> by lazy { listOf(Home, Matches, Analytics, Settings, Help) }
    }
}
