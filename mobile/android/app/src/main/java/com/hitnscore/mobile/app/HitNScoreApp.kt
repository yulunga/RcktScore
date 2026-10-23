package com.hitnscore.mobile.app

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.feature.auth.LoginFrameworkScreen
import com.hitnscore.mobile.feature.shell.AppShellScreen

@Composable
fun HitNScoreApp(viewModel: AppViewModel) {
    val sessionState by viewModel.sessionState.collectAsStateWithLifecycle()

    // Auth gate, like iOS ContentView: sign-in is never left on the back stack.
    AnimatedContent(
        targetState = sessionState,
        contentKey = { it::class },
        transitionSpec = { fadeIn(tween(220)) togetherWith fadeOut(tween(120)) },
        label = "session",
    ) { state ->
        when (state) {
            SessionState.Restoring -> Box(
                Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.background),
            )

            SessionState.SignedOut -> LoginFrameworkScreen(
                onOpenPreview = viewModel::startPreviewSession,
            )

            is SessionState.SignedIn -> AppShellScreen(
                session = state,
                onContextSelected = viewModel::selectContext,
                onSignOut = viewModel::signOut,
            )
        }
    }
}
