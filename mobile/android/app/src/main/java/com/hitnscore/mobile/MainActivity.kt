package com.hitnscore.mobile

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.hitnscore.mobile.app.AppViewModel
import com.hitnscore.mobile.app.HitNScoreApp
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.core.session.SessionState

class MainActivity : ComponentActivity() {
    private val appViewModel: AppViewModel by viewModels { AppViewModel.Factory }

    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()
        super.onCreate(savedInstanceState)
        // Hold the brand splash until we know whether a session can be restored,
        // so the user never sees the sign-in screen flash before the dashboard.
        splashScreen.setKeepOnScreenCondition {
            appViewModel.sessionState.value is SessionState.Restoring
        }
        enableEdgeToEdge()
        setContent {
            HitNScoreTheme {
                HitNScoreApp(viewModel = appViewModel)
            }
        }
    }
}
