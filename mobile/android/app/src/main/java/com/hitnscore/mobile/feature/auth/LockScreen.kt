package com.hitnscore.mobile.feature.auth

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.hitnscore.mobile.R

/** Shown when a valid saved session needs fingerprint, face or screen-lock unlock. */
@Composable
fun LockScreen(
    displayName: String,
    onUnlocked: () -> Unit,
    onUsePassword: () -> Unit,
) {
    val context = LocalContext.current
    val activity = remember(context) { context.findFragmentActivity() }
    val available = remember(context) { BiometricAuth.isAvailable(context) }
    val promptTitle = stringResource(R.string.lock_prompt_title)
    val unavailableMessage = stringResource(R.string.lock_unavailable)
    var errorMessage by rememberSaveable { mutableStateOf<String?>(null) }
    var autoPrompted by rememberSaveable { mutableStateOf(false) }

    val prompt: () -> Unit = {
        if (activity != null && available) {
            BiometricAuth.authenticate(
                activity = activity,
                title = promptTitle,
                onSuccess = onUnlocked,
                onError = { errorMessage = it },
            )
        } else {
            errorMessage = unavailableMessage
        }
    }

    LaunchedEffect(Unit) {
        if (!autoPrompted) {
            autoPrompted = true
            prompt()
        }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .safeDrawingPadding()
                .padding(32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Image(
                painter = painterResource(R.drawable.splash_logo),
                contentDescription = null,
                modifier = Modifier.size(112.dp),
            )
            BrandWordmark(modifier = Modifier.padding(top = 8.dp))
            Text(
                text = stringResource(R.string.lock_welcome, displayName),
                modifier = Modifier.padding(top = 20.dp),
                style = MaterialTheme.typography.titleLarge,
                textAlign = TextAlign.Center,
            )
            Text(
                text = stringResource(R.string.lock_body),
                modifier = Modifier.padding(top = 6.dp),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
            errorMessage?.let {
                Text(
                    text = it,
                    modifier = Modifier.padding(top = 12.dp),
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall,
                    textAlign = TextAlign.Center,
                )
            }
            Button(
                onClick = prompt,
                enabled = available,
                modifier = Modifier
                    .padding(top = 28.dp)
                    .widthIn(max = 360.dp)
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(16.dp),
            ) {
                Text(stringResource(R.string.lock_unlock), style = MaterialTheme.typography.titleMedium)
            }
            TextButton(onClick = onUsePassword, modifier = Modifier.padding(top = 8.dp)) {
                Text(stringResource(R.string.lock_use_password))
            }
        }
    }
}
