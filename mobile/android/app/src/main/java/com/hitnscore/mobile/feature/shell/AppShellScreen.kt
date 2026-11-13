package com.hitnscore.mobile.feature.shell

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.app.navigation.AppDestination
import com.hitnscore.mobile.app.navigation.HitNScoreTabNavHost
import com.hitnscore.mobile.app.navigation.ShellRoutes
import com.hitnscore.mobile.app.navigation.navigateToTab
import com.hitnscore.mobile.core.session.AccountContext
import com.hitnscore.mobile.core.session.AccountContextType
import com.hitnscore.mobile.feature.tournaments.TournamentsViewModel
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.data.model.ClubRoles
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
    val tournamentsViewModel: TournamentsViewModel = viewModel(factory = TournamentsViewModel.Factory)
    val tournamentsState by tournamentsViewModel.uiState.collectAsStateWithLifecycle()
    val clubKeys = session.availableContexts
        .filter { it.type == AccountContextType.Club }
        .map { it.organizationId to it.name }
    LaunchedEffect(clubKeys, shellState.isOnline) {
        if (shellState.isOnline) tournamentsViewModel.load(clubKeys)
    }
    val tabs = if (tournamentsState.hasTournamentClubs) AppDestination.withTournaments else AppDestination.topLevel
    val currentRoute = backStackEntry?.destination?.route
    // Read-only club members can follow matches but not score them (B18, as iOS and web).
    val canManageMatches = ClubRoles.canManageMatches(session.activeContext.role)
    val canManageState = rememberUpdatedState(canManageMatches)
    val currentOnSignOut by rememberUpdatedState(onSignOut)

    val actions = remember(navController, shellViewModel) {
        ShellActions(
            onRefresh = shellViewModel::refresh,
            // Live and scheduled matches open the scorer; finished ones (and read-only members) open the match view.
            onOpenMatch = { match ->
                val completed = match.status.equals("completed", ignoreCase = true)
                val route = if (completed || !canManageState.value) ShellRoutes.match(match.matchId) else ShellRoutes.score(match.matchId)
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
            onWatchMatch = { code -> navController.navigate(ShellRoutes.watch(code)) },
            onSignOut = { currentOnSignOut() },
        )
    }

    val fullScreen = ShellRoutes.isFullScreen(currentRoute)

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = {
            if (!fullScreen) NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
                tabs.forEach { destination ->
                    // Play sits between Home and Matches and starts a new match (replaces the
                    // floating Start button). Read-only club members can't start matches (B18).
                    if (destination == AppDestination.Matches && canManageMatches) {
                        PlayItem(onClick = { navController.navigate(ShellRoutes.NEW_MATCH) { launchSingleTop = true } })
                    }
                    NavigationBarItem(
                        colors = tabColors(),
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
            tournamentsState = tournamentsState,
            onDismissNotifications = shellViewModel::dismissNotifications,
            onContextSelected = onContextSelected,
            onSignOut = onSignOut,
            modifier = Modifier
                .padding(contentPadding)
                .consumeWindowInsets(contentPadding),
        )
    }
}

/** As iOS: grey icons and labels, the selected tab in brand blue, no highlight pill. */
@Composable
private fun tabColors() = NavigationBarItemDefaults.colors(
    selectedIconColor = MaterialTheme.colorScheme.primary,
    selectedTextColor = MaterialTheme.colorScheme.primary,
    unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
    unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant,
    indicatorColor = Color.Transparent,
)

/** The Play button in the bottom bar: a grey circle with a pink play triangle (as iOS). */
@Composable
private fun RowScope.PlayItem(onClick: () -> Unit) {
    NavigationBarItem(
        selected = false,
        onClick = onClick,
        colors = tabColors(),
        icon = {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    painterResource(R.drawable.ic_play_ring),
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Icon(
                    painterResource(R.drawable.ic_play_triangle),
                    contentDescription = null,
                    tint = HitNScoreTheme.colors.brandPink,
                )
            }
        },
        label = { Text(stringResource(R.string.tab_play), maxLines = 1, overflow = TextOverflow.Ellipsis) },
        modifier = Modifier.testTag(ShellTags.PLAY),
    )
}

object ShellTags {
    const val PLAY = "shell_play"
}
