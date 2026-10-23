package com.hitnscore.mobile.app.navigation

import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.runtime.Composable
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
    onContextSelected: (AccountContext) -> Unit,
    onSignOut: () -> Unit,
    modifier: Modifier = Modifier,
) {
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
                    session = session,
                    onContextSelected = onContextSelected,
                    onSignOut = onSignOut,
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
