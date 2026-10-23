package com.hitnscore.mobile.feature.shell

import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.hitnscore.mobile.R
import com.hitnscore.mobile.app.navigation.AppDestination
import com.hitnscore.mobile.app.navigation.HitNScoreTabNavHost
import com.hitnscore.mobile.app.navigation.ShellRoutes
import com.hitnscore.mobile.app.navigation.navigateToTab
import com.hitnscore.mobile.core.session.AccountContext
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.feature.settings.SettingsPage

/**
 * Signed-in shell. One Scaffold and bottom bar for the whole session; only the
 * content below it changes, so tab switches are instant and never flicker.
 */
@Composable
fun AppShellScreen(
    session: SessionState.SignedIn,
    biometricUnlockEnabled: Boolean,
    onBiometricUnlockChange: (Boolean) -> Unit,
    onContextSelected: (AccountContext) -> Unit,
    onSignOut: () -> Unit,
    shellViewModel: ShellViewModel = viewModel(factory = ShellViewModel.Factory),
) {
    val navController = rememberNavController()
    val backStackEntry by navController.currentBackStackEntryAsState()
    val shellState by shellViewModel.uiState.collectAsStateWithLifecycle()
    val currentRoute = backStackEntry?.destination?.route

    val actions = remember(navController, shellViewModel) {
        ShellActions(
            onRefresh = shellViewModel::refresh,
            // Live and scheduled matches open the scorer; finished ones open the match view.
            onOpenMatch = { match ->
                val route = if (match.status.equals("completed", ignoreCase = true)) ShellRoutes.match(match.matchId) else ShellRoutes.score(match.matchId)
                navController.navigate(route)
            },
            onOpenNotifications = { navController.navigate(ShellRoutes.NOTIFICATIONS) { launchSingleTop = true } },
            onShowMatches = { category ->
                shellViewModel.selectMatchesCategory(category)
                navController.navigateToTab(AppDestination.Matches)
            },
            onSelectMatchesCategory = shellViewModel::selectMatchesCategory,
            onOpenSubscription = { navController.navigate(ShellRoutes.settingsPage(SettingsPage.Subscription)) },
            onContextSelected = onContextSelected,
        )
    }

    val fullScreen = ShellRoutes.isFullScreen(currentRoute)
    val showStartButton = currentRoute == AppDestination.Home.route || currentRoute == AppDestination.Matches.route

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        floatingActionButton = {
            // Approved UX change 1: a persistent Start button on Home and Matches.
            if (showStartButton) {
                ExtendedFloatingActionButton(
                    onClick = { navController.navigate(ShellRoutes.NEW_MATCH) { launchSingleTop = true } },
                    icon = { Icon(painterResource(R.drawable.ic_add), contentDescription = null) },
                    text = { Text(stringResource(R.string.start_new_match)) },
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                )
            }
        },
        bottomBar = {
            if (!fullScreen) NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
                AppDestination.topLevel.forEach { destination ->
                    NavigationBarItem(
                        selected = currentRoute?.startsWith(destination.route) == true,
                        onClick = { navController.navigateToTab(destination) },
                        icon = { Icon(painterResource(destination.iconRes), contentDescription = null) },
                        label = {
                            Text(
                                text = stringResource(destination.labelRes),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        },
                    )
                }
            }
        },
    ) { contentPadding ->
        HitNScoreTabNavHost(
            navController = navController,
            session = session,
            shellState = shellState,
            actions = actions,
            biometricUnlockEnabled = biometricUnlockEnabled,
            onBiometricUnlockChange = onBiometricUnlockChange,
            onMarkNotificationRead = shellViewModel::markNotificationRead,
            onContextSelected = onContextSelected,
            onSignOut = onSignOut,
            modifier = Modifier
                .padding(contentPadding)
                .consumeWindowInsets(contentPadding),
        )
    }
}
