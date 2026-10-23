package com.hitnscore.mobile.app.navigation

sealed class AppDestination(
    val route: String,
    val label: String,
    val shortLabel: String,
) {
    data object Login : AppDestination("login", "Sign in", "Sign in")
    data object Home : AppDestination("home", "Home", "H")
    data object Matches : AppDestination("matches", "Matches", "M")
    data object Analytics : AppDestination("analytics", "Analytics", "A")
    data object Settings : AppDestination("settings", "Settings", "S")
    data object Help : AppDestination("help", "Need Help", "?")

    companion object {
        val topLevel = listOf(Home, Matches, Analytics, Settings, Help)
    }
}
