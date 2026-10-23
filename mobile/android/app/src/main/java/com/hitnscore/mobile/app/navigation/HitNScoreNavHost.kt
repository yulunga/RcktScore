package com.hitnscore.mobile.app.navigation

import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import com.hitnscore.mobile.core.session.AccountContext
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.feature.shell.TabPlaceholderScreen

/** Content of the signed-in shell. Only this area changes when switching tabs. */
@Composable
fun HitNScoreTabNavHost(
    navController: NavHostController,
    session: SessionState.SignedIn,
    biometricUnlockEnabled: Boolean,
    onBiometricUnlockChange: (Boolean) -> Unit,
    onContextSelected: (AccountContext) -> Unit,
    onSignOut: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // Read through updated state so a context switch recomposes the tab without
    // rebuilding the navigation graph (which would reset the selected tab).
    val currentSession by rememberUpdatedState(session)
    val currentBiometric by rememberUpdatedState(biometricUnlockEnabled)
    val currentOnBiometricChange by rememberUpdatedState(onBiometricUnlockChange)
    val currentOnContextSelected by rememberUpdatedState(onContextSelected)
    val currentOnSignOut by rememberUpdatedState(onSignOut)

    NavHost(
        navController = navController,
        startDestination = AppDestination.Home.route,
        modifier = modifier,
        enterTransition = { fadeIn(tween(TAB_FADE_IN_MS)) },
        exitTransition = { fadeOut(tween(TAB_FADE_OUT_MS)) },
        popEnterTransition = { fadeIn(tween(TAB_FADE_IN_MS)) },
        popExitTransition = { fadeOut(tween(TAB_FADE_OUT_MS)) },
    ) {
        AppDestination.topLevel.forEach { destination ->
            composable(destination.route) {
                TabPlaceholderScreen(
                    destination = destination,
                    session = currentSession,
                    biometricUnlockEnabled = currentBiometric,
                    onBiometricUnlockChange = { currentOnBiometricChange(it) },
                    onContextSelected = { currentOnContextSelected(it) },
                    onSignOut = { currentOnSignOut() },
                )
            }
        }
    }
}

/** Standard bottom-navigation behaviour: one copy of each tab, state saved and restored. */
fun NavHostController.navigateToTab(destination: AppDestination) {
    navigate(destination.route) {
        popUpTo(graph.findStartDestination().id) { saveState = true }
        launchSingleTop = true
        restoreState = true
    }
}

private const val TAB_FADE_IN_MS = 180
private const val TAB_FADE_OUT_MS = 90
