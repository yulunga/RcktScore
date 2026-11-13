package com.hitnscore.mobile.feature.auth

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme

/** The iOS sign-in overlay card: rounded white card, heading and a round × close button. */
@Composable
internal fun LoginOverlay(
    onClose: () -> Unit,
    closeEnabled: Boolean = true,
    title: String? = null,
    header: (@Composable () -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Dialog(
        onDismissRequest = { if (closeEnabled) onClose() },
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Surface(
            shape = RoundedCornerShape(28.dp),
            color = MaterialTheme.colorScheme.surface,
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
            modifier = Modifier
                .padding(horizontal = 20.dp)
                .widthIn(max = 420.dp)
                .fillMaxWidth()
                .imePadding(),
        ) {
            Column(
                Modifier
                    .verticalScroll(rememberScrollState())
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.weight(1f)) {
                        if (header != null) {
                            header()
                        } else if (title != null) {
                            Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                        }
                    }
                    Surface(
                        onClick = onClose,
                        enabled = closeEnabled,
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.25f)),
                        modifier = Modifier.size(44.dp),
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                painterResource(R.drawable.ic_close),
                                contentDescription = stringResource(R.string.close),
                                tint = MaterialTheme.colorScheme.primary,
                            )
                        }
                    }
                }
                content()
            }
        }
    }
}

@Composable
internal fun OverlayPrimaryButton(text: String, enabled: Boolean = true, busy: Boolean = false, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = enabled && !busy,
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.fillMaxWidth().height(52.dp),
    ) {
        if (busy) {
            CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.5.dp, color = MaterialTheme.colorScheme.onPrimary)
        } else {
            Text(text, style = MaterialTheme.typography.titleMedium)
        }
    }
}

@Composable
internal fun OverlaySecondaryButton(text: String, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        shape = RoundedCornerShape(14.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
            contentColor = MaterialTheme.colorScheme.primary,
        ),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.25f)),
        elevation = null,
        modifier = Modifier.fillMaxWidth().height(52.dp),
    ) {
        Text(text, style = MaterialTheme.typography.titleMedium)
    }
}

/** Rounded text field with a grey placeholder, as the iOS overlays. */
@Composable
internal fun OverlayField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    enabled: Boolean = true,
    isError: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
    capitalization: KeyboardCapitalization = KeyboardCapitalization.None,
    singleLine: Boolean = true,
    minHeight: Int = 52,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = { Text(placeholder) },
        singleLine = singleLine,
        enabled = enabled,
        isError = isError,
        shape = RoundedCornerShape(14.dp),
        colors = OutlinedTextFieldDefaults.colors(
            unfocusedBorderColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.25f),
        ),
        keyboardOptions = KeyboardOptions(
            capitalization = capitalization,
            autoCorrectEnabled = false,
            keyboardType = keyboardType,
            imeAction = if (singleLine) ImeAction.Next else ImeAction.Default,
        ),
        modifier = Modifier.fillMaxWidth().heightIn(min = minHeight.dp),
    )
}

@Composable
private fun FieldLabel(text: String) {
    Text(text, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

/** Need Help: Ping Us, Guides, Password Reset (as iOS). */
@Composable
internal fun NeedHelpOverlay(onPingUs: () -> Unit, onGuides: () -> Unit, onPasswordReset: () -> Unit, onClose: () -> Unit) {
    LoginOverlay(onClose = onClose, title = stringResource(R.string.need_help_title)) {
        Text(stringResource(R.string.need_help_body), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        OverlayPrimaryButton(stringResource(R.string.ping_us), onClick = onPingUs)
        OverlaySecondaryButton(stringResource(R.string.guides), onClick = onGuides)
        OverlaySecondaryButton(stringResource(R.string.password_reset), onClick = onPasswordReset)
    }
}

/** Ping Us: name, email, subject and message, sent to the HitnScore team by email. */
@Composable
internal fun PingUsOverlay(state: PingUsUiState, viewModel: PingUsViewModel, onClose: () -> Unit) {
    LoginOverlay(onClose = onClose, closeEnabled = !state.isSending, title = stringResource(R.string.ping_us)) {
        val sentTo = state.sentTo
        if (sentTo != null) {
            Text(stringResource(R.string.ping_us_sent, sentTo), style = MaterialTheme.typography.bodyLarge)
            OverlayPrimaryButton(stringResource(R.string.register_back_to_sign_in), onClick = onClose)
            return@LoginOverlay
        }
        Text(stringResource(R.string.ping_us_body), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        FieldLabel(stringResource(R.string.ping_us_name))
        OverlayField(state.name, { v -> viewModel.update { it.copy(name = v) } }, stringResource(R.string.ping_us_name), enabled = !state.isSending, isError = state.problem == PingUsProblem.Name, capitalization = KeyboardCapitalization.Words)
        FieldLabel(stringResource(R.string.ping_us_email))
        OverlayField(state.email, { v -> viewModel.update { it.copy(email = v) } }, stringResource(R.string.ping_us_email_hint), enabled = !state.isSending, isError = state.problem == PingUsProblem.Email, keyboardType = KeyboardType.Email)
        FieldLabel(stringResource(R.string.ping_us_subject))
        var open by remember { mutableStateOf(false) }
        Box {
            Surface(
                onClick = { open = true },
                enabled = !state.isSending,
                shape = RoundedCornerShape(14.dp),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.25f)),
                color = MaterialTheme.colorScheme.surface,
                modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
            ) {
                Row(Modifier.padding(horizontal = 16.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(state.category, color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                    Icon(painterResource(R.drawable.ic_expand_more), contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                }
            }
            DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
                PingUsViewModel.CATEGORIES.forEach { category ->
                    DropdownMenuItem(text = { Text(category) }, onClick = {
                        open = false
                        viewModel.update { it.copy(category = category) }
                    })
                }
            }
        }
        FieldLabel(stringResource(R.string.ping_us_more))
        OverlayField(state.message, { v -> viewModel.update { it.copy(message = v) } }, "", enabled = !state.isSending, isError = state.problem == PingUsProblem.Message, capitalization = KeyboardCapitalization.Sentences, singleLine = false, minHeight = 140)
        val error = state.serverError ?: state.problem?.let {
            stringResource(
                when (it) {
                    PingUsProblem.Name -> R.string.ping_us_need_name
                    PingUsProblem.Email -> R.string.register_need_email
                    PingUsProblem.Message -> R.string.ping_us_need_more
                },
            )
        }
        error?.let { Text(it, color = HitNScoreTheme.colors.brandPink, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold) }
        OverlayPrimaryButton(stringResource(R.string.ping_us_send), busy = state.isSending, onClick = viewModel::send)
    }
}

/** Small logo + "HitnScore" wordmark, the Want In header (as iOS). */
@Composable
internal fun OverlayBrandHeader() {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Image(
            painter = painterResource(R.drawable.splash_logo),
            contentDescription = null,
            modifier = Modifier.size(48.dp),
        )
        BrandWordmark(modifier = Modifier.padding(start = 8.dp), fontSize = 26.sp)
    }
}
