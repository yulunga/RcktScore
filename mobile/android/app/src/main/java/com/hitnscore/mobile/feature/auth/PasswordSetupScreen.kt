package com.hitnscore.mobile.feature.auth

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.auth.PasswordLink
import com.hitnscore.mobile.core.auth.PasswordPolicy
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme

/**
 * "Create your password" (new account) or "Choose a new password" (reset), opened from the
 * emailed link. Shown over whatever the app was showing; closing it returns there.
 */
@Composable
fun PasswordSetupScreen(
    link: PasswordLink,
    onClose: () -> Unit,
    viewModel: PasswordSetupViewModel = viewModel(key = "password-${link.token}", factory = PasswordSetupViewModel.factory(link)),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    BackHandler(enabled = !state.isSaving, onBack = onClose)
    Box(
        Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(MaterialTheme.colorScheme.primaryContainer, MaterialTheme.colorScheme.background))),
        contentAlignment = Alignment.TopCenter,
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .safeDrawingPadding()
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                IconButton(onClick = onClose, enabled = !state.isSaving) {
                    Icon(painterResource(R.drawable.ic_close), contentDescription = stringResource(R.string.close))
                }
            }
            Image(painterResource(R.drawable.splash_logo), contentDescription = null, modifier = Modifier.size(96.dp))
            BrandWordmark(modifier = Modifier.padding(top = 4.dp, bottom = 16.dp))
            Surface(
                modifier = Modifier.widthIn(max = 420.dp).fillMaxWidth(),
                shape = RoundedCornerShape(28.dp),
                color = MaterialTheme.colorScheme.surface,
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
                shadowElevation = 6.dp,
            ) {
                Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    when (state.stage) {
                        PasswordSetupStage.Checking -> Checking()
                        PasswordSetupStage.LinkInvalid -> LinkInvalid(state, onRetry = viewModel::checkLink, onClose = onClose)
                        PasswordSetupStage.Ready -> PasswordForm(state, viewModel)
                        PasswordSetupStage.Done -> Done(state.link.isAccountSetup, onClose)
                    }
                }
            }
        }
    }
}

@Composable
private fun Checking() {
    Row(verticalAlignment = Alignment.CenterVertically) {
        CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.5.dp)
        Spacer(Modifier.width(14.dp))
        Text(stringResource(R.string.password_link_checking), style = MaterialTheme.typography.bodyLarge)
    }
}

@Composable
private fun LinkInvalid(state: PasswordSetupUiState, onRetry: () -> Unit, onClose: () -> Unit) {
    Text(stringResource(R.string.password_link_invalid_title), style = MaterialTheme.typography.headlineSmall)
    Text(
        state.errorMessage ?: stringResource(R.string.password_link_invalid_body),
        color = HitNScoreTheme.colors.brandPink,
        fontWeight = FontWeight.SemiBold,
    )
    Text(stringResource(R.string.password_link_invalid_help), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    if (state.canRetryCheck) {
        OutlinedButton(onClick = onRetry, modifier = Modifier.fillMaxWidth()) { Text(stringResource(R.string.retry)) }
    }
    Button(onClick = onClose, modifier = Modifier.fillMaxWidth().height(52.dp), shape = RoundedCornerShape(16.dp)) {
        Text(stringResource(R.string.register_back_to_sign_in))
    }
}

@Composable
private fun PasswordForm(state: PasswordSetupUiState, viewModel: PasswordSetupViewModel) {
    val setup = state.link.isAccountSetup
    Text(stringResource(if (setup) R.string.password_setup_title else R.string.password_reset_title), style = MaterialTheme.typography.headlineSmall)
    Text(
        stringResource(if (setup) R.string.password_setup_body else R.string.password_reset_body),
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    val transformation = if (state.passwordVisible) VisualTransformation.None else PasswordVisualTransformation()
    val mismatch = state.confirmation.isNotEmpty() && !state.confirmationMatches
    val mismatchText: (@Composable () -> Unit)? = if (mismatch) {
        { Text(stringResource(R.string.password_mismatch)) }
    } else {
        null
    }
    OutlinedTextField(
        value = state.password,
        onValueChange = viewModel::onPasswordChange,
        label = { Text(stringResource(R.string.password_new)) },
        singleLine = true,
        enabled = !state.isSaving,
        visualTransformation = transformation,
        trailingIcon = {
            IconButton(onClick = viewModel::togglePasswordVisibility) {
                Icon(
                    painterResource(if (state.passwordVisible) R.drawable.ic_visibility_off else R.drawable.ic_visibility),
                    contentDescription = stringResource(if (state.passwordVisible) R.string.login_hide_password else R.string.login_show_password),
                )
            }
        },
        keyboardOptions = KeyboardOptions(autoCorrectEnabled = false, keyboardType = KeyboardType.Password, imeAction = ImeAction.Next),
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.fillMaxWidth().testTag(PasswordSetupTags.NEW),
    )
    OutlinedTextField(
        value = state.confirmation,
        onValueChange = viewModel::onConfirmationChange,
        label = { Text(stringResource(R.string.password_confirm)) },
        singleLine = true,
        enabled = !state.isSaving,
        visualTransformation = transformation,
        isError = mismatch,
        supportingText = mismatchText,
        keyboardOptions = KeyboardOptions(autoCorrectEnabled = false, keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.fillMaxWidth().testTag(PasswordSetupTags.CONFIRM),
    )
    Rules(state.unmetRules, started = state.password.isNotEmpty())
    state.errorMessage?.let {
        Text(it, color = HitNScoreTheme.colors.brandPink, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.bodyMedium)
    }
    Button(
        onClick = viewModel::save,
        enabled = state.canSave,
        modifier = Modifier.fillMaxWidth().height(52.dp).testTag(PasswordSetupTags.SAVE),
        shape = RoundedCornerShape(16.dp),
    ) {
        if (state.isSaving) {
            CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.5.dp, color = MaterialTheme.colorScheme.onPrimary)
        } else {
            Text(stringResource(if (setup) R.string.password_setup_save else R.string.password_reset_save), style = MaterialTheme.typography.titleMedium)
        }
    }
}

/** The backend's password rules, ticked off as they are met (as the web Help page). */
@Composable
private fun Rules(unmet: List<PasswordPolicy.Rule>, started: Boolean) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        PasswordPolicy.Rule.entries.forEach { rule ->
            val met = rule !in unmet
            val color = when {
                met -> HitNScoreTheme.colors.activeStatus
                started -> HitNScoreTheme.colors.brandPink
                else -> MaterialTheme.colorScheme.onSurfaceVariant
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier.size(18.dp).background(color.copy(alpha = if (met) 1f else 0.15f), CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    if (met) Text("✓", color = MaterialTheme.colorScheme.surface, style = MaterialTheme.typography.labelSmall)
                }
                Spacer(Modifier.width(10.dp))
                Text(stringResource(ruleText(rule)), style = MaterialTheme.typography.bodyMedium, color = if (met) MaterialTheme.colorScheme.onSurface else color)
            }
        }
    }
}

private fun ruleText(rule: PasswordPolicy.Rule): Int = when (rule) {
    PasswordPolicy.Rule.Length -> R.string.password_rule_length
    PasswordPolicy.Rule.Uppercase -> R.string.password_rule_uppercase
    PasswordPolicy.Rule.Number -> R.string.password_rule_number
    PasswordPolicy.Rule.Symbol -> R.string.password_rule_symbol
    PasswordPolicy.Rule.NotCommon -> R.string.password_rule_common
}

@Composable
private fun Done(isAccountSetup: Boolean, onClose: () -> Unit) {
    Text(stringResource(if (isAccountSetup) R.string.password_setup_done_title else R.string.password_reset_done_title), style = MaterialTheme.typography.headlineSmall)
    Text(
        stringResource(if (isAccountSetup) R.string.password_setup_done_body else R.string.password_reset_done_body),
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    Button(
        onClick = onClose,
        modifier = Modifier.fillMaxWidth().height(52.dp).testTag(PasswordSetupTags.SIGN_IN),
        shape = RoundedCornerShape(16.dp),
    ) { Text(stringResource(R.string.password_go_to_sign_in)) }
}

/** "Already have the link?": for when the email opened the link in a browser instead of the app. */
@Composable
fun PasteLinkField(value: String, onValueChange: (String) -> Unit, onOpen: () -> Unit, invalid: Boolean) {
    val invalidText: (@Composable () -> Unit)? = if (invalid) {
        { Text(stringResource(R.string.password_paste_link_invalid)) }
    } else {
        null
    }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            label = { Text(stringResource(R.string.password_paste_link)) },
            singleLine = true,
            isError = invalid,
            supportingText = invalidText,
            keyboardOptions = KeyboardOptions(autoCorrectEnabled = false, keyboardType = KeyboardType.Uri, imeAction = ImeAction.Go),
            modifier = Modifier.fillMaxWidth(),
        )
        TextButton(onClick = onOpen, enabled = value.isNotBlank()) { Text(stringResource(R.string.password_paste_link_open)) }
    }
}

object PasswordSetupTags {
    const val NEW = "password.new"
    const val CONFIRM = "password.confirm"
    const val SAVE = "password.save"
    const val SIGN_IN = "password.signIn"
}
