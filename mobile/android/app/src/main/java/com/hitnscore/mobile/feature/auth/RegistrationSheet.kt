package com.hitnscore.mobile.feature.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.feature.scoring.Choice
import kotlinx.coroutines.delay

/** With no typing for this long, Want In closes and returns to sign-in. */
internal const val WANT_IN_IDLE_TIMEOUT_MS = 15_000L

/**
 * "Want In": a plain overlay (as the iOS sign-in card) to create a free Personal account or
 * send a club enquiry. Closes by itself after [WANT_IN_IDLE_TIMEOUT_MS] without typing.
 */
@Composable
fun RegistrationSheet(
    onDismiss: () -> Unit,
    viewModel: RegistrationViewModel = viewModel(factory = RegistrationViewModel.Factory),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val currentOnDismiss by rememberUpdatedState(onDismiss)
    // Any change to the form restarts the countdown; never close while sending.
    val activityKey = listOf(state.firstName, state.surname, state.email, state.use, state.clubName, state.humanAnswer, state.confirmedEmail)
    LaunchedEffect(activityKey, state.isSubmitting) {
        if (state.isSubmitting) return@LaunchedEffect
        delay(WANT_IN_IDLE_TIMEOUT_MS)
        currentOnDismiss()
    }

    LoginOverlay(
        onClose = onDismiss,
        closeEnabled = !state.isSubmitting,
        header = { OverlayBrandHeader() },
    ) {
        val confirmed = state.confirmedEmail
        if (confirmed != null) {
            Text(
                stringResource(if (state.confirmedUse == RegistrationUse.Personal) R.string.register_done_personal_title else R.string.register_done_club_title),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
            )
            Text(
                stringResource(
                    if (state.confirmedUse == RegistrationUse.Personal) R.string.register_done_personal else R.string.register_done_club,
                    confirmed,
                ),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            OverlayPrimaryButton(stringResource(R.string.register_back_to_sign_in), onClick = onDismiss)
            return@LoginOverlay
        }

        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(stringResource(R.string.register_title), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Text(stringResource(R.string.register_intro), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        val busy = state.isSubmitting
        OverlayField(state.firstName, { v -> viewModel.update { it.copy(firstName = v) } }, stringResource(R.string.setup_first_name), enabled = !busy, isError = state.problem == RegistrationProblem.FirstName, capitalization = KeyboardCapitalization.Words)
        OverlayField(state.surname, { v -> viewModel.update { it.copy(surname = v) } }, stringResource(R.string.setup_surname), enabled = !busy, isError = state.problem == RegistrationProblem.Surname, capitalization = KeyboardCapitalization.Words)
        OverlayField(state.email, { v -> viewModel.update { it.copy(email = v) } }, stringResource(R.string.register_email), enabled = !busy, isError = state.problem == RegistrationProblem.Email, keyboardType = KeyboardType.Email)
        Text(stringResource(R.string.register_app_use), style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
        val personalLabel = stringResource(R.string.register_use_personal)
        val clubLabel = stringResource(R.string.register_use_club)
        Choice(listOf(0, 1), if (state.use == RegistrationUse.Club) 1 else 0, enabled = !busy, label = { if (it == 1) clubLabel else personalLabel }) { v ->
            viewModel.update { it.copy(use = if (v == 1) RegistrationUse.Club else RegistrationUse.Personal) }
        }
        if (state.use == RegistrationUse.Club) {
            OverlayField(state.clubName, { v -> viewModel.update { it.copy(clubName = v) } }, stringResource(R.string.register_club_name), enabled = !busy, isError = state.problem == RegistrationProblem.ClubName, capitalization = KeyboardCapitalization.Words)
        }
        OverlayField(
            state.humanAnswer,
            { v -> viewModel.update { it.copy(humanAnswer = v.filter(Char::isDigit).take(3)) } },
            stringResource(R.string.register_human_check, state.humanLeft, state.humanRight),
            enabled = !busy,
            isError = state.problem == RegistrationProblem.HumanCheck,
            keyboardType = KeyboardType.Number,
        )
        val message = state.serverError ?: state.problem?.let { problemText(it) }
        message?.let {
            Text(it, color = HitNScoreTheme.colors.brandPink, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
        }
        OverlayPrimaryButton(
            stringResource(if (busy) R.string.register_creating else R.string.register_create_account),
            busy = busy,
            onClick = viewModel::submit,
        )
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
