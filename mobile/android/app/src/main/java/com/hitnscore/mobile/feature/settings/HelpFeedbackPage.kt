package com.hitnscore.mobile.feature.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.feature.auth.GUIDES_URL
import com.hitnscore.mobile.feature.auth.OverlayPrimaryButton
import com.hitnscore.mobile.feature.auth.OverlaySecondaryButton
import com.hitnscore.mobile.feature.auth.PingUsOverlay
import com.hitnscore.mobile.feature.auth.PingUsViewModel

/** Settings › Help & Feedback (as iOS): Ping Us the HitnScore team, or open the Guides. */
@Composable
internal fun HelpFeedbackPage(session: SessionState.SignedIn) {
    val uriHandler = LocalUriHandler.current
    val pingUs: PingUsViewModel = viewModel(factory = PingUsViewModel.Factory)
    val pingState by pingUs.uiState.collectAsStateWithLifecycle()
    var showPingUs by rememberSaveable { mutableStateOf(false) }
    EditorCard(stringResource(R.string.settings_help_feedback)) {
        Text(
            stringResource(R.string.settings_help_body),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            OverlayPrimaryButton(stringResource(R.string.ping_us)) {
                pingUs.reset(session.username, personName(session))
                showPingUs = true
            }
            OverlaySecondaryButton(stringResource(R.string.guides)) { uriHandler.openUri(GUIDES_URL) }
        }
    }
    if (showPingUs) {
        PingUsOverlay(pingState, pingUs, onClose = { showPingUs = false })
    }
}
