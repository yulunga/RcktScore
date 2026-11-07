package com.hitnscore.mobile

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.fragment.app.FragmentActivity
import com.hitnscore.mobile.app.AppViewModel
import com.hitnscore.mobile.app.HitNScoreApp
import com.hitnscore.mobile.core.auth.PasswordLink
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.core.session.SessionState

/** FragmentActivity (a ComponentActivity) because BiometricPrompt requires it. */
class MainActivity : FragmentActivity() {
    private val appViewModel: AppViewModel by viewModels { AppViewModel.Factory }

    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()
        super.onCreate(savedInstanceState)
        // A web Help link (no reset token) that Android sent here: hand it back to the browser.
        if (savedInstanceState == null && forwardWebLink(intent)) {
            finish()
            return
        }
        // Hold the brand splash until we know whether a session can be restored,
        // so the user never sees the sign-in screen flash before the dashboard.
        splashScreen.setKeepOnScreenCondition {
            appViewModel.sessionState.value is SessionState.Restoring
        }
        enableEdgeToEdge()
        // A password set-up/reset link from email (App Links). Not re-read after rotation.
        if (savedInstanceState == null) deliverPasswordLink(intent)
        setContent {
            HitNScoreTheme {
                HitNScoreApp(viewModel = appViewModel)
            }
        }
    }

    /** singleTop: a link tapped while the app is open arrives here. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (!forwardWebLink(intent)) deliverPasswordLink(intent)
    }

    private fun deliverPasswordLink(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        (application as HitNScoreApplication).container.passwordLinks.deliver(PasswordLink.from(intent.data))
    }

    /**
     * The app claims `https://app.hitnscore.com/help` for password links, but the website also
     * links there (Help, privacy, cookies). Those open in the browser instead. Returns true
     * when [intent] was such a link.
     */
    private fun forwardWebLink(intent: Intent?): Boolean {
        val uri = intent?.data ?: return false
        if (intent.action != Intent.ACTION_VIEW || PasswordLink.from(uri) != null) return false
        val browser = packageManager.resolveActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse("https://www.hitnscore.com")),
            PackageManager.MATCH_DEFAULT_ONLY,
        )?.activityInfo?.packageName?.takeIf { it != "android" && it != packageName }
        val view = Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE)
        if (browser != null) view.setPackage(browser)
        return try {
            startActivity(view)
            true
        } catch (noBrowser: ActivityNotFoundException) {
            false
        }
    }

    override fun onStart() {
        super.onStart()
        appViewModel.onAppForegrounded()
    }

    override fun onStop() {
        super.onStop()
        if (!isChangingConfigurations) appViewModel.onAppBackgrounded()
    }
}
