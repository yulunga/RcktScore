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

/** Stand-in for each tab until its iOS-parity feature is built (M2 onward). */
@Composable
fun TabPlaceholderScreen(
    destination: AppDestination,
    session: SessionState.SignedIn,
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
                OutlinedButton(onClick = onSignOut, modifier = Modifier.padding(top = 24.dp)) {
                    Text(stringResource(R.string.sign_out))
                }
            }
        }
    }
}
