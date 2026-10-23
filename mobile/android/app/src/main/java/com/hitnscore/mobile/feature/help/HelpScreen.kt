package com.hitnscore.mobile.feature.help

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.components.SectionCard
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.feature.shell.ShellActions
import com.hitnscore.mobile.feature.shell.ShellHeader
import com.hitnscore.mobile.feature.shell.ShellUiState

/** Need Help tab. Feedback, help articles and privacy pages arrive in M6. */
@Composable
fun HelpScreen(session: SessionState.SignedIn, state: ShellUiState, actions: ShellActions) {
    LazyColumn(
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
        modifier = Modifier.fillMaxSize(),
    ) {
        item {
            ShellHeader(
                session = session,
                isOnline = state.isOnline,
                hasUnreadNotifications = state.hasUnreadNotifications,
                contextLabel = stringResource(R.string.context_label),
                onOpenNotifications = actions.onOpenNotifications,
                onContextSelected = actions.onContextSelected,
            )
        }
        item {
            SectionCard(title = stringResource(R.string.tab_help), iconRes = R.drawable.ic_tab_help) {
                Text(stringResource(R.string.help_placeholder), color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
