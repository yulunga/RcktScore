package com.hitnscore.mobile.feature.shell

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.hitnscore.mobile.R
import com.hitnscore.mobile.app.navigation.AppDestination
import com.hitnscore.mobile.core.session.AccountContext
import com.hitnscore.mobile.core.session.AccountContextSwitcher
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.feature.settings.QuickUnlockSetting

/** Stand-in for each tab until its iOS-parity feature is built (M2 onward). */
@Composable
fun TabPlaceholderScreen(
    destination: AppDestination,
    session: SessionState.SignedIn,
    biometricUnlockEnabled: Boolean,
    onBiometricUnlockChange: (Boolean) -> Unit,
    onContextSelected: (AccountContext) -> Unit,
    onSignOut: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp, vertical = 16.dp),
    ) {
        AccountContextSwitcher(
            activeContext = session.activeContext,
            availableContexts = session.availableContexts,
            label = stringResource(
                if (destination == AppDestination.Matches) R.string.context_label_matches else R.string.context_label,
            ),
            onContextSelected = onContextSelected,
            modifier = Modifier.fillMaxWidth(),
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                text = stringResource(destination.labelRes),
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.primary,
            )
            if (destination == AppDestination.Home) {
                Text(
                    text = stringResource(R.string.home_welcome, session.displayName),
                    modifier = Modifier.padding(top = 8.dp),
                    style = MaterialTheme.typography.titleMedium,
                )
            }
            Text(
                text = if (destination == AppDestination.Home) {
                    stringResource(R.string.home_placeholder, session.activeContext.name)
                } else {
                    stringResource(R.string.tab_placeholder)
                },
                modifier = Modifier.padding(top = 12.dp),
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (destination == AppDestination.Settings) {
                Text(
                    text = stringResource(R.string.settings_signed_in_as, session.username),
                    modifier = Modifier.padding(top = 20.dp),
                    style = MaterialTheme.typography.bodyMedium,
                )
                QuickUnlockSetting(
                    enabled = biometricUnlockEnabled,
                    onEnabledChange = onBiometricUnlockChange,
                    modifier = Modifier.padding(top = 16.dp),
                )
                OutlinedButton(onClick = onSignOut, modifier = Modifier.padding(top = 24.dp)) {
                    Text(stringResource(R.string.sign_out))
                }
            }
        }
    }
}
