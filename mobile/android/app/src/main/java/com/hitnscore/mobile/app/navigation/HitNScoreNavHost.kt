package com.hitnscore.mobile.app.navigation

import android.net.Uri
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
import com.hitnscore.mobile.core.session.AccountContextType
import com.hitnscore.mobile.feature.analytics.AnalyticsScreen
import com.hitnscore.mobile.feature.newmatch.MatchSetupScreen
import com.hitnscore.mobile.feature.newmatch.SetupArgs
import com.hitnscore.mobile.feature.newmatch.SportPickerScreen
import com.hitnscore.mobile.feature.newmatch.enabledSports
import com.hitnscore.mobile.feature.scoring.ScoringScreen
import com.hitnscore.mobile.feature.shell.MatchesCategory
import com.hitnscore.mobile.feature.help.HelpScreen
import com.hitnscore.mobile.feature.home.HomeScreen
import com.hitnscore.mobile.feature.matches.MatchDetailScreen
import com.hitnscore.mobile.feature.matches.MatchesScreen
import com.hitnscore.mobile.feature.notifications.NotificationsScreen
import com.hitnscore.mobile.feature.settings.SettingsPage
import com.hitnscore.mobile.feature.settings.SettingsPageScreen
import com.hitnscore.mobile.feature.settings.SettingsScreen
import com.hitnscore.mobile.feature.shell.ShellActions
import com.hitnscore.mobile.feature.shell.ShellUiState

object ShellRoutes {
    const val NEW_MATCH = "newmatch"
    const val SETUP = "newmatch/{sport}"
    const val SCORE = "score/{matchId}"
    const val MATCH = "match/{matchId}"
    const val NOTIFICATIONS = "notifications"
    const val SETTINGS_PAGE = "settings/{page}"

    fun match(matchId: String) = "match/${Uri.encode(matchId)}"
    fun setup(sport: String) = "newmatch/$sport"
    fun score(matchId: String) = "score/${Uri.encode(matchId)}"

    /** Full-screen flows hide the bottom bar and the Start button. */
    fun isFullScreen(route: String?) = route?.startsWith(NEW_MATCH) == true || route?.startsWith("score/") == true
    fun settingsPage(page: SettingsPage) = "settings/${page.route}"
}

/** Content of the signed-in shell. Only this area changes when switching tabs. */
@Composable
fun HitNScoreTabNavHost(
    navController: NavHostController,
    session: SessionState.SignedIn,
    shellState: ShellUiState,
    actions: ShellActions,
    biometricUnlockEnabled: Boolean,
    onBiometricUnlockChange: (Boolean) -> Unit,
    onMarkNotificationRead: (String) -> Unit,
    onContextSelected: (AccountContext) -> Unit,
    onSignOut: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // Read through updated state so new data recomposes the visible screen without
    // rebuilding the navigation graph (which would reset the selected tab).
    val currentSession by rememberUpdatedState(session)
    val currentState by rememberUpdatedState(shellState)
    val currentActions by rememberUpdatedState(actions)
    val currentBiometric by rememberUpdatedState(biometricUnlockEnabled)
    val currentOnBiometricChange by rememberUpdatedState(onBiometricUnlockChange)
    val currentOnMarkRead by rememberUpdatedState(onMarkNotificationRead)
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
        composable(AppDestination.Home.route) {
            HomeScreen(currentSession, currentState, currentActions)
        }
        composable(AppDestination.Matches.route) {
            MatchesScreen(currentSession, currentState, currentState.isPersonalPlus(currentSession), currentActions)
        }
        composable(AppDestination.Analytics.route) {
            AnalyticsScreen(currentSession, currentState, currentState.isPersonalPlus(currentSession), currentActions)
        }
        composable(AppDestination.Settings.route) {
            SettingsScreen(
                session = currentSession,
                state = currentState,
                actions = currentActions,
                biometricUnlockEnabled = currentBiometric,
                onBiometricUnlockChange = { currentOnBiometricChange(it) },
                onOpenPage = { navController.navigate(ShellRoutes.settingsPage(it)) },
                onSignOut = { currentOnSignOut() },
            )
        }
        composable(AppDestination.Help.route) {
            HelpScreen(currentSession, currentState, currentActions)
        }
        composable(ShellRoutes.NEW_MATCH) {
            SportPickerScreen(
                session = currentSession,
                onContextSelected = { currentOnContextSelected(it) },
                onChoose = { sport -> navController.navigate(ShellRoutes.setup(sport)) },
                onBack = { navController.popBackStack() },
            )
        }
        composable(ShellRoutes.SETUP) { entry ->
            val sport = entry.arguments?.getString("sport").orEmpty()
            val session = currentSession
            val args = SetupArgs(
                sport = sport,
                organizationId = session.activeContext.organizationId,
                isPersonal = session.activeContext.type == AccountContextType.Personal,
                isPersonalPlus = currentState.isPersonalPlus(session),
                sessionSports = session.enabledSports(),
                activeMatches = currentState.dashboard?.activeMatches.orEmpty(),
            )
            MatchSetupScreen(
                args = args,
                onBack = { navController.popBackStack() },
                onOpenMatch = { matchId ->
                    currentActions.onRefresh()
                    navController.navigate(ShellRoutes.score(matchId)) {
                        popUpTo(ShellRoutes.NEW_MATCH) { inclusive = true }
                    }
                },
                onScheduled = {
                    navController.popBackStack(ShellRoutes.NEW_MATCH, inclusive = true)
                    currentActions.onRefresh()
                    currentActions.onShowMatches(MatchesCategory.Scheduled)
                },
            )
        }
        composable(ShellRoutes.SCORE) { entry ->
            val matchId = entry.arguments?.getString("matchId").orEmpty()
            ScoringScreen(
                matchId = matchId,
                isOnline = currentState.isOnline,
                onBack = {
                    currentActions.onRefresh()
                    navController.popBackStack()
                },
                onOpenMatchView = { id ->
                    currentActions.onRefresh()
                    navController.navigate(ShellRoutes.match(id)) {
                        popUpTo(ShellRoutes.SCORE) { inclusive = true }
                    }
                },
            )
        }
        composable(ShellRoutes.MATCH) { entry ->
            val matchId = entry.arguments?.getString("matchId").orEmpty()
            MatchDetailScreen(matchId = matchId, isOnline = currentState.isOnline, onBack = { navController.popBackStack() })
        }
        composable(ShellRoutes.NOTIFICATIONS) {
            NotificationsScreen(
                notifications = currentState.notifications,
                onOpen = { currentOnMarkRead(it) },
                onBack = { navController.popBackStack() },
            )
        }
        composable(ShellRoutes.SETTINGS_PAGE) { entry ->
            val page = SettingsPage.fromRoute(entry.arguments?.getString("page")) ?: SettingsPage.About
            SettingsPageScreen(
                page = page,
                session = currentSession,
                memberships = currentSession.memberships,
                state = currentState,
                onContextSelected = { currentOnContextSelected(it) },
                onBack = { navController.popBackStack() },
            )
        }
    }
}

/** Personal Plus according to the backend dashboard, falling back to the sign-in plan. */
fun ShellUiState.isPersonalPlus(session: SessionState.SignedIn): Boolean =
    planCode?.let { it == "personal_plus" } ?: (session.activeContext.plan == "Personal Plus")

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
