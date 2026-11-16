package com.hitnscore.mobile.feature.settings

import androidx.compose.foundation.layout.Arrangement
import com.hitnscore.mobile.core.designsystem.components.InnerCard
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.material3.Icon
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.background
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
internal fun HelpFeedbackPage(session: SessionState.SignedIn, onOpenPrivacy: () -> Unit = {}) {
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
        // Privacy & Data, as iOS: the policy in the app.
        InnerCard(onClick = onOpenPrivacy, shape = RoundedCornerShape(18.dp)) {
            Row(Modifier.fillMaxWidth().padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Box(
                    Modifier.size(36.dp).background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f), CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(painterResource(R.drawable.ic_lock), contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp))
                }
                Column(Modifier.weight(1f)) {
                    Text(stringResource(R.string.privacy_title), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                    Text(stringResource(R.string.privacy_body), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Icon(painterResource(R.drawable.ic_chevron_right), contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            }
        }
    }
    if (showPingUs) {
        PingUsOverlay(pingState, pingUs, onClose = { showPingUs = false })
    }
}
