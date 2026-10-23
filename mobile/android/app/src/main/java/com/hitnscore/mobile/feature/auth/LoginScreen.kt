package com.hitnscore.mobile.feature.auth

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
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.config.AppEnvironment
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.core.session.AccountContext
import com.hitnscore.mobile.core.session.SignOutReason

@Composable
fun LoginScreen(
    signOutReason: SignOutReason,
    viewModel: LoginViewModel = viewModel(factory = LoginViewModel.Factory),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val focusManager = LocalFocusManager.current

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(MaterialTheme.colorScheme.primaryContainer, MaterialTheme.colorScheme.background),
                ),
            ),
        contentAlignment = Alignment.TopCenter,
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .safeDrawingPadding()
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Image(
                painter = painterResource(R.drawable.splash_logo),
                contentDescription = null,
                modifier = Modifier.size(132.dp),
            )
            BrandWordmark(modifier = Modifier.padding(top = 8.dp, bottom = 20.dp))

            Surface(
                modifier = Modifier
                    .widthIn(max = 420.dp)
                    .fillMaxWidth(),
                shape = RoundedCornerShape(28.dp),
                color = MaterialTheme.colorScheme.surface,
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
                shadowElevation = 6.dp,
            ) {
                Column(modifier = Modifier.padding(24.dp)) {
                    OutlinedTextField(
                        value = state.username,
                        onValueChange = viewModel::onUsernameChange,
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag(TestTags.USERNAME),
                        label = { Text(stringResource(R.string.login_username)) },
                        placeholder = { Text(stringResource(R.string.login_username_hint)) },
                        singleLine = true,
                        enabled = !state.isSigningIn,
                        shape = RoundedCornerShape(14.dp),
                        keyboardOptions = KeyboardOptions(
                            capitalization = KeyboardCapitalization.None,
                            autoCorrectEnabled = false,
                            keyboardType = KeyboardType.Email,
                            imeAction = ImeAction.Next,
                        ),
                    )
                    Spacer(Modifier.height(14.dp))
                    OutlinedTextField(
                        value = state.password,
                        onValueChange = viewModel::onPasswordChange,
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag(TestTags.PASSWORD),
                        label = { Text(stringResource(R.string.login_password)) },
                        placeholder = { Text(stringResource(R.string.login_password_hint)) },
                        singleLine = true,
                        enabled = !state.isSigningIn,
                        shape = RoundedCornerShape(14.dp),
                        visualTransformation = if (state.passwordVisible) {
                            VisualTransformation.None
                        } else {
                            PasswordVisualTransformation()
                        },
                        trailingIcon = {
                            IconButton(onClick = viewModel::togglePasswordVisibility) {
                                Icon(
                                    painter = painterResource(
                                        if (state.passwordVisible) R.drawable.ic_visibility_off else R.drawable.ic_visibility,
                                    ),
                                    contentDescription = stringResource(
                                        if (state.passwordVisible) R.string.login_hide_password else R.string.login_show_password,
                                    ),
                                )
                            }
                        },
                        keyboardOptions = KeyboardOptions(
                            autoCorrectEnabled = false,
                            keyboardType = KeyboardType.Password,
                            imeAction = ImeAction.Done,
                        ),
                        keyboardActions = KeyboardActions(
                            onDone = {
                                focusManager.clearFocus()
                                viewModel.signIn()
                            },
                        ),
                    )

                    val message = state.errorMessage
                    val notice = signOutNotice(signOutReason)
                    when {
                        message != null -> MessageText(message, isError = true)
                        !AppEnvironment.isConfigured -> MessageText(
                            stringResource(R.string.login_environment_missing, AppEnvironment.environmentName),
                            isError = true,
                        )
                        notice != null -> MessageText(notice, isError = false)
                    }

                    Button(
                        onClick = {
                            focusManager.clearFocus()
                            viewModel.signIn()
                        },
                        enabled = state.canSubmit,
                        modifier = Modifier
                            .padding(top = 20.dp)
                            .fillMaxWidth()
                            .height(52.dp)
                            .testTag(TestTags.SIGN_IN),
                        shape = RoundedCornerShape(16.dp),
                    ) {
                        if (state.isSigningIn) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(22.dp),
                                strokeWidth = 2.5.dp,
                                color = MaterialTheme.colorScheme.onPrimary,
                            )
                        } else {
                            Text(stringResource(R.string.login_sign_in), style = MaterialTheme.typography.titleMedium)
                        }
                    }

                    TextButton(
                        onClick = viewModel::openPasswordReset,
                        modifier = Modifier
                            .padding(top = 8.dp)
                            .align(Alignment.CenterHorizontally),
                    ) {
                        Text(
                            text = stringResource(R.string.login_need_help),
                            color = HitNScoreTheme.colors.brandPink,
                            style = MaterialTheme.typography.labelLarge,
                        )
                    }
                }
            }

            if (!AppEnvironment.isProduction) {
                Text(
                    text = stringResource(R.string.login_build_info, AppEnvironment.versionName, AppEnvironment.environmentName),
                    modifier = Modifier.padding(top = 16.dp),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }

    state.conflictMessage?.let { message ->
        AlertDialog(
            onDismissRequest = viewModel::dismissConflict,
            title = { Text(stringResource(R.string.conflict_title)) },
            text = { Text(message) },
            confirmButton = {
                TextButton(onClick = viewModel::confirmSignOutOtherDevice) {
                    Text(stringResource(R.string.conflict_confirm))
                }
            },
            dismissButton = {
                TextButton(onClick = viewModel::dismissConflict) { Text(stringResource(R.string.cancel)) }
            },
        )
    }

    if (state.accountChoices.isNotEmpty()) {
        AccountChoiceDialog(
            choices = state.accountChoices,
            onChoose = viewModel::chooseAccount,
            onCancel = viewModel::cancelAccountChoice,
        )
    }

    state.passwordReset?.let { reset ->
        PasswordResetDialog(
            state = reset,
            onEmailChange = viewModel::onResetEmailChange,
            onSend = viewModel::sendPasswordReset,
            onClose = viewModel::closePasswordReset,
        )
    }
}

/** "Hit n Score" in brand blue with a pink "n", as on iOS. */
@Composable
fun BrandWordmark(modifier: Modifier = Modifier, fontSize: TextUnit = 30.sp) {
    val blue = MaterialTheme.colorScheme.primary
    val pink = HitNScoreTheme.colors.brandPink
    val hit = stringResource(R.string.brand_hit)
    val n = stringResource(R.string.brand_n)
    val score = stringResource(R.string.brand_score)
    Text(
        text = buildAnnotatedString {
            withStyle(SpanStyle(color = blue)) { append(hit) }
            withStyle(SpanStyle(color = pink)) { append(n) }
            withStyle(SpanStyle(color = blue)) { append(score) }
        },
        modifier = modifier,
        fontSize = fontSize,
        fontWeight = FontWeight.Black,
    )
}

@Composable
private fun signOutNotice(reason: SignOutReason): String? = when (reason) {
    SignOutReason.UserRequested -> null
    SignOutReason.Expired -> stringResource(R.string.login_notice_expired)
    SignOutReason.Replaced -> stringResource(R.string.login_notice_replaced)
    SignOutReason.Ended -> stringResource(R.string.login_notice_ended)
}

@Composable
private fun MessageText(text: String, isError: Boolean) {
    Text(
        text = text,
        modifier = Modifier
            .padding(top = 12.dp)
            .fillMaxWidth()
            .testTag(TestTags.MESSAGE),
        // Slightly larger and bolder for errors so the lighter pink stays readable.
        style = if (isError) {
            MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold)
        } else {
            MaterialTheme.typography.bodySmall
        },
        // Brand pink for sign-in errors, matching the HitNScore palette.
        color = if (isError) HitNScoreTheme.colors.brandPink else MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

@Composable
private fun AccountChoiceDialog(
    choices: List<AccountContext>,
    onChoose: (AccountContext) -> Unit,
    onCancel: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onCancel,
        title = { Text(stringResource(R.string.choose_account_title)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(stringResource(R.string.choose_account_body), style = MaterialTheme.typography.bodyMedium)
                choices.forEach { choice ->
                    Surface(
                        onClick = { onChoose(choice) },
                        shape = RoundedCornerShape(14.dp),
                        color = MaterialTheme.colorScheme.primaryContainer,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(Modifier.weight(1f)) {
                                Text(choice.name, style = MaterialTheme.typography.titleMedium)
                                Text(
                                    choice.plan,
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                            Text("›", style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.primary)
                        }
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onCancel) { Text(stringResource(R.string.cancel)) } },
    )
}

@Composable
private fun PasswordResetDialog(
    state: PasswordResetUiState,
    onEmailChange: (String) -> Unit,
    onSend: () -> Unit,
    onClose: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onClose,
        title = { Text(stringResource(R.string.reset_title)) },
        text = {
            Column {
                if (state.sent) {
                    Text(stringResource(R.string.reset_sent))
                } else {
                    Text(stringResource(R.string.reset_body), style = MaterialTheme.typography.bodyMedium)
                    OutlinedTextField(
                        value = state.email,
                        onValueChange = onEmailChange,
                        modifier = Modifier
                            .padding(top = 12.dp)
                            .fillMaxWidth(),
                        label = { Text(stringResource(R.string.reset_email)) },
                        singleLine = true,
                        enabled = !state.isSending,
                        keyboardOptions = KeyboardOptions(
                            autoCorrectEnabled = false,
                            keyboardType = KeyboardType.Email,
                            imeAction = ImeAction.Send,
                        ),
                        keyboardActions = KeyboardActions(onSend = { onSend() }),
                    )
                    state.errorMessage?.let {
                        Text(
                            it,
                            modifier = Modifier.padding(top = 8.dp),
                            color = HitNScoreTheme.colors.brandPink,
                            style = MaterialTheme.typography.bodySmall,
                        )
                    }
                }
            }
        },
        confirmButton = {
            if (!state.sent) {
                TextButton(onClick = onSend, enabled = !state.isSending && '@' in state.email) {
                    Text(stringResource(R.string.reset_send))
                }
            }
        },
        dismissButton = {
            TextButton(onClick = onClose) {
                Text(stringResource(if (state.sent) R.string.close else R.string.cancel), textAlign = TextAlign.Center)
            }
        },
    )
}

object TestTags {
    const val USERNAME = "login.username"
    const val PASSWORD = "login.password"
    const val SIGN_IN = "login.signIn"
    const val MESSAGE = "login.message"
}
