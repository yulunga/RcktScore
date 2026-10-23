package com.hitnscore.mobile.app.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import com.hitnscore.mobile.feature.auth.LoginFrameworkScreen
import com.hitnscore.mobile.feature.shell.AppShellScreen

@Composable
fun HitNScoreNavHost(navController: NavHostController) {
    NavHost(
        navController = navController,
        startDestination = AppDestination.Login.route,
    ) {
        composable(AppDestination.Login.route) {
            LoginFrameworkScreen(
                onOpenFramework = {
                    navController.navigate(AppDestination.Home.route) {
                        popUpTo(AppDestination.Login.route) { inclusive = true }
                    }
                },
            )
        }

        AppDestination.topLevel.forEach { destination ->
            composable(destination.route) {
                AppShellScreen(
                    currentDestination = destination,
                    onDestinationSelected = { selected ->
                        navController.navigate(selected.route) {
                            launchSingleTop = true
                            restoreState = true
                            popUpTo(AppDestination.Home.route) { saveState = true }
                        }
                    },
                )
            }
        }
    }
}
