package com.hitnscore.mobile.feature.settings

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.hitnscore.mobile.R
import com.hitnscore.mobile.feature.auth.BiometricAuth
import com.hitnscore.mobile.feature.auth.findFragmentActivity

/**
 * Settings row for fingerprint / face / screen-lock unlock. Turning it on asks the
 * user to authenticate once first, as iOS does for Face ID. Hidden when unavailable.
 */
@Composable
fun QuickUnlockSetting(
    enabled: Boolean,
    onEnabledChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val available = remember(context) { BiometricAuth.isAvailable(context) }
    if (!available && !enabled) return

    val promptTitle = stringResource(R.string.biometric_enable_prompt)
    var errorMessage by remember { mutableStateOf<String?>(null) }

    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface,
    ) {
        Column(Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(stringResource(R.string.biometric_setting_title), style = MaterialTheme.typography.titleMedium)
                    Text(
                        stringResource(R.string.biometric_setting_body),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Switch(
                    checked = enabled,
                    onCheckedChange = { turnOn ->
                        errorMessage = null
                        val activity = context.findFragmentActivity()
                        if (!turnOn) {
                            onEnabledChange(false)
                        } else if (activity != null && available) {
                            BiometricAuth.authenticate(
                                activity = activity,
                                title = promptTitle,
                                onSuccess = { onEnabledChange(true) },
                                onError = { errorMessage = it },
                            )
                        }
                    },
                )
            }
            errorMessage?.let {
                Text(
                    it,
                    modifier = Modifier.padding(top = 8.dp),
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        }
    }
}
