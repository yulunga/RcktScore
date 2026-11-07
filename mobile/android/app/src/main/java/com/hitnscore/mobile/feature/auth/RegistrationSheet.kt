package com.hitnscore.mobile.feature.auth

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.feature.scoring.Choice

/** "Join Hit n Score": a free Personal account, or a club enquiry (iOS `registerInterestCard`). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RegistrationSheet(
    onDismiss: () -> Unit,
    viewModel: RegistrationViewModel = viewModel(factory = RegistrationViewModel.Factory),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    ModalBottomSheet(
        onDismissRequest = { if (!state.isSubmitting) onDismiss() },
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
    ) {
        Column(
            Modifier
                .verticalScroll(rememberScrollState())
                .imePadding()
                .navigationBarsPadding()
                .padding(horizontal = 24.dp)
                .padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(stringResource(R.string.register_title), style = MaterialTheme.typography.headlineSmall)
            val confirmed = state.confirmedEmail
            if (confirmed != null) {
                Text(
                    stringResource(if (state.confirmedUse == RegistrationUse.Personal) R.string.register_done_personal_title else R.string.register_done_club_title),
                    style = MaterialTheme.typography.titleMedium,
                )
                Text(
                    stringResource(
                        if (state.confirmedUse == RegistrationUse.Personal) R.string.register_done_personal else R.string.register_done_club,
                        confirmed,
                    ),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Button(onClick = onDismiss, modifier = Modifier.fillMaxWidth().height(52.dp), shape = RoundedCornerShape(16.dp)) {
                    Text(stringResource(R.string.register_back_to_sign_in))
                }
                return@Column
            }

            Text(stringResource(R.string.register_intro), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            TextButton(
                onClick = { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(WEBSITE))) },
                modifier = Modifier.padding(start = 0.dp),
            ) {
                Text(stringResource(R.string.register_website), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold)
            }

            val nameOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, autoCorrectEnabled = false, imeAction = ImeAction.Next)
            OutlinedTextField(
                value = state.firstName,
                onValueChange = { v -> viewModel.update { it.copy(firstName = v) } },
                label = { Text(stringResource(R.string.setup_first_name)) },
                singleLine = true,
                isError = state.problem == RegistrationProblem.FirstName,
                enabled = !state.isSubmitting,
                keyboardOptions = nameOptions,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = state.surname,
                onValueChange = { v -> viewModel.update { it.copy(surname = v) } },
                label = { Text(stringResource(R.string.setup_surname)) },
                singleLine = true,
                isError = state.problem == RegistrationProblem.Surname,
                enabled = !state.isSubmitting,
                keyboardOptions = nameOptions,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = state.email,
                onValueChange = { v -> viewModel.update { it.copy(email = v) } },
                label = { Text(stringResource(R.string.register_email)) },
                placeholder = { Text(stringResource(R.string.login_username_hint)) },
                singleLine = true,
                isError = state.problem == RegistrationProblem.Email,
                enabled = !state.isSubmitting,
                keyboardOptions = KeyboardOptions(autoCorrectEnabled = false, keyboardType = KeyboardType.Email, imeAction = ImeAction.Next),
                modifier = Modifier.fillMaxWidth(),
            )
            Text(stringResource(R.string.register_app_use), style = MaterialTheme.typography.labelLarge)
            val personalLabel = stringResource(R.string.register_use_personal)
            val clubLabel = stringResource(R.string.register_use_club)
            Choice(listOf(0, 1), if (state.use == RegistrationUse.Club) 1 else 0, enabled = !state.isSubmitting, label = { if (it == 1) clubLabel else personalLabel }) { v ->
                viewModel.update { it.copy(use = if (v == 1) RegistrationUse.Club else RegistrationUse.Personal) }
            }
            if (state.use == RegistrationUse.Club) {
                OutlinedTextField(
                    value = state.clubName,
                    onValueChange = { v -> viewModel.update { it.copy(clubName = v) } },
                    label = { Text(stringResource(R.string.register_club_name)) },
                    singleLine = true,
                    isError = state.problem == RegistrationProblem.ClubName,
                    enabled = !state.isSubmitting,
                    keyboardOptions = nameOptions,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            OutlinedTextField(
                value = state.humanAnswer,
                onValueChange = { v -> viewModel.update { it.copy(humanAnswer = v.filter(Char::isDigit).take(3)) } },
                label = { Text(stringResource(R.string.register_human_check, state.humanLeft, state.humanRight)) },
                singleLine = true,
                isError = state.problem == RegistrationProblem.HumanCheck,
                enabled = !state.isSubmitting,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
                modifier = Modifier.fillMaxWidth(),
            )

            val message = state.serverError ?: state.problem?.let { problemText(it) }
            message?.let {
                Text(it, color = HitNScoreTheme.colors.brandPink, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
            }

            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                OutlinedButton(onClick = onDismiss, enabled = !state.isSubmitting, modifier = Modifier.weight(1f).height(52.dp), shape = RoundedCornerShape(16.dp)) {
                    Text(stringResource(R.string.cancel))
                }
                Button(onClick = viewModel::submit, enabled = !state.isSubmitting, modifier = Modifier.weight(1.4f).height(52.dp), shape = RoundedCornerShape(16.dp)) {
                    if (state.isSubmitting) {
                        CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.5.dp, color = MaterialTheme.colorScheme.onPrimary)
                    } else {
                        Text(stringResource(if (state.use == RegistrationUse.Personal) R.string.register_create_personal else R.string.register_send_club))
                    }
                }
            }
        }
    }
}

@Composable
private fun problemText(problem: RegistrationProblem): String = stringResource(
    when (problem) {
        RegistrationProblem.FirstName -> R.string.register_need_first_name
        RegistrationProblem.Surname -> R.string.register_need_surname
        RegistrationProblem.Email -> R.string.register_need_email
        RegistrationProblem.ClubName -> R.string.register_need_club
        RegistrationProblem.HumanCheck -> R.string.register_human_wrong
    },
)

private const val WEBSITE = "https://www.hitnscore.com"
