package com.hitnscore.mobile.feature.shell

import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.hitnscore.mobile.app.navigation.AppDestination
import com.hitnscore.mobile.app.navigation.HitNScoreTabNavHost
import com.hitnscore.mobile.app.navigation.navigateToTab
import com.hitnscore.mobile.core.session.AccountContext
import com.hitnscore.mobile.core.session.SessionState

/**
 * Signed-in shell. One Scaffold and bottom bar for the whole session; only the
 * tab content below it changes, so tab switches are instant and never flicker.
 */
@Composable
fun AppShellScreen(
    session: SessionState.SignedIn,
    onContextSelected: (AccountContext) -> Unit,
    onSignOut: () -> Unit,
) {
    val navController = rememberNavController()
    val backStackEntry by navController.currentBackStackEntryAsState()

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = {
            NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
                AppDestination.topLevel.forEach { destination ->
                    val selected = backStackEntry?.destination?.hierarchy
                        ?.any { it.route == destination.route } == true
                    NavigationBarItem(
                        selected = selected,
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
            onContextSelected = onContextSelected,
            onSignOut = onSignOut,
            modifier = Modifier
                .padding(contentPadding)
                .consumeWindowInsets(contentPadding),
        )
    }
}
