package com.hitnscore.mobile.core.session

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import com.hitnscore.mobile.R

@Composable
fun AccountContextSwitcher(
    activeContext: AccountContext,
    availableContexts: List<AccountContext>,
    label: String,
    onContextSelected: (AccountContext) -> Unit,
    modifier: Modifier = Modifier,
) {
    var expanded by rememberSaveable { mutableStateOf(false) }
    val switchDescription = stringResource(R.string.context_switch_description, activeContext.name)
    Column(modifier = modifier) {
        OutlinedButton(
            modifier = Modifier
                .fillMaxWidth()
                .semantics { contentDescription = switchDescription },
            enabled = availableContexts.size > 1,
            onClick = { expanded = true },
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(label, style = MaterialTheme.typography.labelMedium)
                Text(activeContext.name, style = MaterialTheme.typography.labelLarge)
            }
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            availableContexts.forEach { context ->
                DropdownMenuItem(
                    text = {
                        Column {
                            Text(context.name)
                            Text(context.plan, style = MaterialTheme.typography.labelSmall)
                        }
                    },
                    enabled = context.organizationId != activeContext.organizationId,
                    onClick = {
                        expanded = false
                        onContextSelected(context)
                    },
                )
            }
        }
    }
}
