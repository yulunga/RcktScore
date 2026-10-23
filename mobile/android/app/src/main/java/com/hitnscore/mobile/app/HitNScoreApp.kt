package com.hitnscore.mobile.app

import androidx.compose.runtime.Composable
import androidx.navigation.compose.rememberNavController
import com.hitnscore.mobile.app.navigation.HitNScoreNavHost

@Composable
fun HitNScoreApp() {
    val navController = rememberNavController()
    HitNScoreNavHost(navController = navController)
}
