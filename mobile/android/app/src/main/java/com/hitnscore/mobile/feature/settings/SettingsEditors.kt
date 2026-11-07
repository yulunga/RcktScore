package com.hitnscore.mobile.feature.settings

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
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
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.data.model.ClubRoles
import com.hitnscore.mobile.data.model.CourtSummary
import com.hitnscore.mobile.data.model.MatchFormatting
import com.hitnscore.mobile.data.model.OrganizationDetailsRequest
import com.hitnscore.mobile.data.model.OrganizationUser
import com.hitnscore.mobile.feature.scoring.Choice

/** The sports HitnScore scores today, in picker order. */
internal val SETTINGS_SPORTS = listOf("squash", "racketball", "tennis", "padel")

// Shared pieces ---------------------------------------------------------------

@Composable
internal fun EditorCard(title: String? = null, content: @Composable ColumnScope.() -> Unit) {
    Surface(
        shape = RoundedCornerShape(20.dp),
        color = HitNScoreTheme.colors.card,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            title?.let { Text(it, style = MaterialTheme.typography.titleMedium) }
            content()
        }
    }
}

@Composable
internal fun EditorField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    enabled: Boolean = true,
    isError: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
    capitalization: KeyboardCapitalization = KeyboardCapitalization.Words,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        singleLine = true,
        enabled = enabled,
        isError = isError,
        keyboardOptions = KeyboardOptions(
            capitalization = if (keyboardType == KeyboardType.Email) KeyboardCapitalization.None else capitalization,
            autoCorrectEnabled = keyboardType != KeyboardType.Email,
            keyboardType = keyboardType,
            imeAction = ImeAction.Next,
        ),
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
internal fun SaveButton(text: String, enabled: Boolean, busy: Boolean, onClick: () -> Unit) {
    Button(onClick = onClick, enabled = enabled && !busy, modifier = Modifier.fillMaxWidth().height(50.dp), shape = RoundedCornerShape(16.dp)) {
        if (busy) {
            CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp, color = MaterialTheme.colorScheme.onPrimary)
        } else {
            Text(text)
        }
    }
}

/** A confirmation (brand blue) or the server's refusal (brand pink). */
@Composable
internal fun StatusLine(notice: SettingsNotice?, error: String?) {
    val text = error ?: notice?.let { noticeText(it) } ?: return
    Text(
        text,
        style = MaterialTheme.typography.bodyMedium,
        fontWeight = FontWeight.SemiBold,
        color = if (error != null) HitNScoreTheme.colors.brandPink else MaterialTheme.colorScheme.primary,
    )
}

@Composable
private fun noticeText(notice: SettingsNotice): String = stringResource(
    when (notice) {
        SettingsNotice.Saved -> R.string.settings_saved
        SettingsNotice.UserInvited -> R.string.settings_user_invited
        SettingsNotice.UserUpdated -> R.string.settings_user_updated
        SettingsNotice.UserRemoved -> R.string.settings_user_removed
        SettingsNotice.ResetSent -> R.string.settings_reset_sent
        SettingsNotice.CourtSaved -> R.string.settings_court_saved
        SettingsNotice.CourtRemoved -> R.string.settings_court_removed
        SettingsNotice.DisplayCodeIssued -> R.string.settings_display_code_issued
    },
)

@Composable
internal fun SwitchLine(title: String, body: String?, checked: Boolean, enabled: Boolean, onChange: (Boolean) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyLarge)
            body?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
        Switch(checked = checked, onCheckedChange = onChange, enabled = enabled)
    }
}

@Composable
internal fun ConfirmDialog(title: String, body: String, confirm: String, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = { Text(body) },
        confirmButton = {
            TextButton(onClick = onConfirm) { Text(confirm, color = HitNScoreTheme.colors.completedStatus) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
    )
}

// Profile -------------------------------------------------------------------

@Composable
fun ProfileEditor(state: ProfileUiState, viewModel: ProfileViewModel) {
    var confirmDelete by rememberSaveable { mutableStateOf(0) }
    val form = state.form
    val busy = state.isSaving || state.isDeleting
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        EditorCard {
            EditorField(stringResource(R.string.setup_first_name), form.firstName, { v -> viewModel.update { it.copy(firstName = v) } }, enabled = !busy, isError = form.firstName.isBlank())
            EditorField(stringResource(R.string.setup_surname), form.surname, { v -> viewModel.update { it.copy(surname = v) } }, enabled = !busy)
            EditorField(stringResource(R.string.settings_email), form.email, { v -> viewModel.update { it.copy(email = v) } }, enabled = !busy, keyboardType = KeyboardType.Email)
            if (state.emailChanged) {
                Text(stringResource(R.string.settings_email_change_note), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            EditorField(stringResource(R.string.settings_telephone), form.telephone, { v -> viewModel.update { it.copy(telephone = v) } }, enabled = !busy, keyboardType = KeyboardType.Phone)
            EditorField(stringResource(R.string.settings_city), form.cityLocation, { v -> viewModel.update { it.copy(cityLocation = v) } }, enabled = !busy)
            EditorField(stringResource(R.string.settings_country), form.country, { v -> viewModel.update { it.copy(country = v) } }, enabled = !busy)
            StatusLine(if (state.saved) SettingsNotice.Saved else if (state.resetSent) SettingsNotice.ResetSent else null, state.errorMessage)
            SaveButton(stringResource(R.string.settings_save_profile), enabled = state.canSave, busy = state.isSaving, onClick = viewModel::save)
        }
        EditorCard(stringResource(R.string.settings_password)) {
            Text(stringResource(R.string.settings_password_body), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            OutlinedButton(onClick = viewModel::sendPasswordReset, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.settings_send_reset))
            }
        }
        if (state.canDeleteAccount) {
            EditorCard(stringResource(R.string.settings_delete_title)) {
                Text(stringResource(R.string.settings_delete_body), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                OutlinedButton(
                    onClick = { confirmDelete = 1 },
                    enabled = !busy,
                    border = BorderStroke(1.dp, HitNScoreTheme.colors.completedStatus),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    if (state.isDeleting) {
                        CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                    } else {
                        Text(stringResource(R.string.settings_delete_button), color = HitNScoreTheme.colors.completedStatus)
                    }
                }
            }
        }
    }
    // Two steps, as iOS: "Delete your account?" then "Are you really sure?".
    when (confirmDelete) {
        1 -> ConfirmDialog(
            title = stringResource(R.string.settings_delete_confirm_1_title),
            body = stringResource(R.string.settings_delete_confirm_1_body),
            confirm = stringResource(R.string.settings_continue),
            onConfirm = { confirmDelete = 2 },
            onDismiss = { confirmDelete = 0 },
        )
        2 -> ConfirmDialog(
            title = stringResource(R.string.settings_delete_confirm_2_title),
            body = stringResource(R.string.settings_delete_confirm_2_body),
            confirm = stringResource(R.string.settings_delete_permanently),
            onConfirm = {
                confirmDelete = 0
                viewModel.deleteAccount()
            },
            onDismiss = { confirmDelete = 0 },
        )
    }
}

// Organisation ---------------------------------------------------------------

@Composable
fun OrganisationEditor(state: OrganizationSettingsUiState, viewModel: OrganizationSettingsViewModel) {
    val organization = state.settings?.organization ?: return
    var name by rememberSaveable(organization) { mutableStateOf(organization.organizationName) }
    var contact by rememberSaveable(organization) { mutableStateOf(organization.contact) }
    var email by rememberSaveable(organization) { mutableStateOf(organization.email) }
    var telephone by rememberSaveable(organization) { mutableStateOf(organization.telephone) }
    var website by rememberSaveable(organization) { mutableStateOf(organization.webAddress) }
    var address by rememberSaveable(organization) { mutableStateOf(organization.address) }
    var postcode by rememberSaveable(organization) { mutableStateOf(organization.postcode) }
    val changed = name != organization.organizationName || contact != organization.contact || email != organization.email ||
        telephone != organization.telephone || website != organization.webAddress || address != organization.address || postcode != organization.postcode
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        EditorCard(stringResource(R.string.settings_org_profile)) {
            EditorField(stringResource(R.string.settings_name), name, { name = it }, enabled = !state.isSaving, isError = name.isBlank())
            EditorField(stringResource(R.string.settings_contact), contact, { contact = it }, enabled = !state.isSaving)
            EditorField(stringResource(R.string.settings_email), email, { email = it }, enabled = !state.isSaving, keyboardType = KeyboardType.Email)
            EditorField(stringResource(R.string.settings_telephone), telephone, { telephone = it }, enabled = !state.isSaving, keyboardType = KeyboardType.Phone)
            EditorField(stringResource(R.string.settings_website), website, { website = it }, enabled = !state.isSaving, keyboardType = KeyboardType.Uri, capitalization = KeyboardCapitalization.None)
        }
        EditorCard(stringResource(R.string.settings_org_location)) {
            EditorField(stringResource(R.string.settings_address), address, { address = it }, enabled = !state.isSaving)
            EditorField(stringResource(R.string.settings_postcode), postcode, { postcode = it }, enabled = !state.isSaving, capitalization = KeyboardCapitalization.Characters)
        }
        StatusLine(state.notice, state.actionError)
        SaveButton(
            stringResource(R.string.settings_save_changes),
            enabled = changed && name.isNotBlank(),
            busy = state.isSaving,
        ) {
            viewModel.saveDetails(
                OrganizationDetailsRequest(
                    organizationName = name.trim(),
                    address = address.trim(),
                    postcode = postcode.trim(),
                    contact = contact.trim(),
                    telephone = telephone.trim(),
                    email = email.trim(),
                    webAddress = website.trim(),
                ),
            )
        }
    }
}

// Racket sports and timer defaults ------------------------------------------------

/** Which sports members see when starting a match (club admins; Personal owners for themselves). */
@Composable
fun SportsEditor(state: OrganizationSettingsUiState, viewModel: OrganizationSettingsViewModel, canEdit: Boolean, body: String) {
    val saved = state.settings?.organization?.enabledSports?.map { it.lowercase() }?.toSet() ?: return
    var selected by remember(saved) { mutableStateOf(saved) }
    EditorCard(stringResource(R.string.settings_racket_sports)) {
        Text(body, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        SETTINGS_SPORTS.forEach { sport ->
            SwitchLine(MatchFormatting.sportName(sport), null, sport in selected, enabled = canEdit && !state.isSaving) { on ->
                selected = if (on) selected + sport else selected - sport
            }
        }
        if (canEdit) {
            SaveButton(
                stringResource(R.string.settings_save_sports),
                enabled = selected != saved && selected.isNotEmpty(),
                busy = state.isSaving,
            ) { viewModel.saveSports(SETTINGS_SPORTS.filter { it in selected }) }
        }
    }
}

/** Per sport: whether new matches start with timed warm-up and breaks switched on. */
@Composable
fun TimerDefaultsEditor(state: OrganizationSettingsUiState, viewModel: OrganizationSettingsViewModel, canEdit: Boolean) {
    val organization = state.settings?.organization ?: return
    val saved = SETTINGS_SPORTS.associateWith { organization.timedBreakDefaults[it] ?: false }
    var draft by remember(organization.timedBreakDefaults) { mutableStateOf(saved) }
    val enabled = organization.enabledSports.map { it.lowercase() }
    EditorCard(stringResource(R.string.settings_timer_defaults)) {
        Text(stringResource(R.string.settings_timer_defaults_body), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        SETTINGS_SPORTS.filter { it in enabled }.forEach { sport ->
            val on = draft[sport] == true
            SwitchLine(
                MatchFormatting.sportName(sport),
                stringResource(if (on) R.string.settings_timer_on else R.string.settings_timer_off),
                on,
                enabled = canEdit && !state.isSaving,
            ) { value -> draft = draft + (sport to value) }
        }
        if (canEdit) {
            SaveButton(stringResource(R.string.settings_save_timers), enabled = draft != saved, busy = state.isSaving) {
                viewModel.saveTimerDefaults(draft)
            }
        } else {
            Text(stringResource(R.string.settings_admin_only), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

// Users ---------------------------------------------------------------------------

@Composable
fun UsersEditor(state: OrganizationSettingsUiState, viewModel: OrganizationSettingsViewModel, signedInUsername: String) {
    val users = state.settings?.users ?: return
    var editing by remember { mutableStateOf<OrganizationUser?>(null) }
    var adding by rememberSaveable { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        StatusLine(state.notice, state.actionError)
        Button(onClick = { adding = true }, enabled = !state.isSaving, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp)) {
            Icon(painterResource(R.drawable.ic_add), contentDescription = null, modifier = Modifier.size(18.dp))
            Text(stringResource(R.string.settings_add_user), modifier = Modifier.padding(start = 8.dp))
        }
        EditorCard {
            users.sortedWith(compareBy({ it.firstName.ifBlank { it.username }.lowercase() }, { it.surname.lowercase() })).forEachIndexed { index, user ->
                if (index > 0) HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                Surface(onClick = { editing = user }, color = HitNScoreTheme.colors.card) {
                    Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(MatchFormatting.fullName(user.firstName.ifBlank { user.username }, user.surname), style = MaterialTheme.typography.bodyLarge)
                            Text(user.username, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            Text(roleLabel(user.role), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
                            if (user.status.equals("pending", ignoreCase = true)) {
                                Text(stringResource(R.string.settings_user_pending), style = MaterialTheme.typography.labelSmall, color = HitNScoreTheme.colors.brandPink)
                            }
                        }
                    }
                }
            }
        }
    }
    if (adding) {
        UserDialog(user = null, isSelf = false, busy = state.isSaving, onDismiss = { adding = false }, onSave = { first, last, email, role ->
            adding = false
            viewModel.saveUser(null, first, last, email, role)
        })
    }
    editing?.let { user ->
        UserDialog(
            user = user,
            isSelf = user.username.equals(signedInUsername, ignoreCase = true),
            busy = state.isSaving,
            onDismiss = { editing = null },
            onSave = { first, last, email, role ->
                editing = null
                viewModel.saveUser(user.id, first, last, email, role)
            },
            onSendReset = {
                editing = null
                viewModel.sendPasswordReset(user.username)
            },
            onRemove = {
                editing = null
                viewModel.removeUser(user.id)
            },
        )
    }
}

@Composable
private fun roleLabel(role: String): String = stringResource(
    when (ClubRoles.normalize(role)) {
        ClubRoles.ADMIN -> R.string.role_admin
        ClubRoles.READ_ONLY -> R.string.role_read_only
        else -> R.string.role_scorer
    },
)

/** Add or edit a member. There is no password field: new members set their own (B17). */
@Composable
private fun UserDialog(
    user: OrganizationUser?,
    isSelf: Boolean,
    busy: Boolean,
    onDismiss: () -> Unit,
    onSave: (String, String, String, String) -> Unit,
    onSendReset: () -> Unit = {},
    onRemove: () -> Unit = {},
) {
    var first by rememberSaveable { mutableStateOf(user?.firstName.orEmpty()) }
    var last by rememberSaveable { mutableStateOf(user?.surname.orEmpty()) }
    var email by rememberSaveable { mutableStateOf(user?.username.orEmpty()) }
    var role by rememberSaveable { mutableStateOf(ClubRoles.normalize(user?.role ?: ClubRoles.SCORER)) }
    var confirmRemove by rememberSaveable { mutableStateOf(false) }
    val roles = ClubRoles.all
    val labels = roles.map { roleLabel(it) }
    val valid = first.isNotBlank() && EMAIL_REGEX.matches(email.trim())
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(if (user == null) R.string.settings_add_user else R.string.settings_edit_user)) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                EditorField(stringResource(R.string.setup_first_name), first, { first = it }, enabled = !busy)
                EditorField(stringResource(R.string.setup_surname), last, { last = it }, enabled = !busy)
                EditorField(stringResource(R.string.settings_email), email, { email = it }, enabled = !busy, keyboardType = KeyboardType.Email)
                Text(stringResource(R.string.settings_role), style = MaterialTheme.typography.labelLarge)
                Choice(roles.indices.toList(), roles.indexOf(role), enabled = !busy && !isSelf, label = { labels[it] }) { role = roles[it] }
                Text(
                    stringResource(
                        when (role) {
                            ClubRoles.ADMIN -> R.string.role_admin_body
                            ClubRoles.READ_ONLY -> R.string.role_read_only_body
                            else -> R.string.role_scorer_body
                        },
                    ),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                if (user == null) {
                    Text(stringResource(R.string.settings_invite_note), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else {
                    TextButton(onClick = onSendReset, enabled = !busy) { Text(stringResource(R.string.settings_send_member_reset)) }
                    if (!isSelf) {
                        TextButton(onClick = { confirmRemove = true }, enabled = !busy) {
                            Text(stringResource(R.string.settings_remove_user), color = HitNScoreTheme.colors.completedStatus)
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { onSave(first, last, email, role) }, enabled = valid && !busy) {
                Text(stringResource(if (user == null) R.string.settings_send_invite else R.string.save))
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
    )
    if (confirmRemove && user != null) {
        ConfirmDialog(
            title = stringResource(R.string.settings_remove_user_title),
            body = stringResource(R.string.settings_remove_user_body, MatchFormatting.fullName(user.firstName.ifBlank { user.username }, user.surname)),
            confirm = stringResource(R.string.settings_remove),
            onConfirm = {
                confirmRemove = false
                onRemove()
            },
            onDismiss = { confirmRemove = false },
        )
    }
}

// Courts --------------------------------------------------------------------------

@Composable
fun CourtsEditor(state: OrganizationSettingsUiState, viewModel: OrganizationSettingsViewModel) {
    val courts = state.settings?.courts ?: return
    var editing by remember { mutableStateOf<CourtSummary?>(null) }
    var adding by rememberSaveable { mutableStateOf(false) }
    var confirmCode by remember { mutableStateOf<CourtSummary?>(null) }
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        StatusLine(state.notice, state.actionError)
        Button(onClick = { adding = true }, enabled = !state.isSaving, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp)) {
            Icon(painterResource(R.drawable.ic_add), contentDescription = null, modifier = Modifier.size(18.dp))
            Text(stringResource(R.string.settings_add_court), modifier = Modifier.padding(start = 8.dp))
        }
        if (courts.isEmpty()) {
            Text(stringResource(R.string.settings_courts_empty), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        courts.forEach { court ->
            EditorCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(court.courtName.ifBlank { court.courtAlias }, style = MaterialTheme.typography.titleMedium)
                        Text(
                            listOfNotNull(
                                court.courtAlias.takeIf { it.isNotBlank() && it != court.courtName },
                                court.sport?.let(MatchFormatting::sportName) ?: stringResource(R.string.settings_any_sport),
                            ).joinToString(" · "),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    TextButton(onClick = { editing = court }, enabled = !state.isSaving) { Text(stringResource(R.string.settings_edit)) }
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(stringResource(R.string.settings_display_code), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(
                            court.displayCode?.takeIf { it.isNotBlank() } ?: stringResource(R.string.settings_display_code_none),
                            style = MaterialTheme.typography.titleMedium.copy(fontFeatureSettings = "tnum"),
                        )
                    }
                    OutlinedButton(onClick = { confirmCode = court }, enabled = !state.isSaving) { Text(stringResource(R.string.settings_new_display_code)) }
                }
            }
        }
    }
    if (adding) {
        CourtDialog(court = null, busy = state.isSaving, onDismiss = { adding = false }, onSave = { name, alias, sport ->
            adding = false
            viewModel.saveCourt(null, name, alias, sport)
        })
    }
    editing?.let { court ->
        CourtDialog(
            court = court,
            busy = state.isSaving,
            onDismiss = { editing = null },
            onSave = { name, alias, sport ->
                editing = null
                viewModel.saveCourt(court.id, name, alias, sport)
            },
            onRemove = {
                editing = null
                viewModel.removeCourt(court.id)
            },
        )
    }
    confirmCode?.let { court ->
        ConfirmDialog(
            title = stringResource(R.string.settings_new_display_code),
            body = stringResource(R.string.settings_new_display_code_body, court.courtName),
            confirm = stringResource(R.string.settings_new_display_code_confirm),
            onConfirm = {
                confirmCode = null
                viewModel.newDisplayCode(court.id)
            },
            onDismiss = { confirmCode = null },
        )
    }
}

@Composable
private fun CourtDialog(
    court: CourtSummary?,
    busy: Boolean,
    onDismiss: () -> Unit,
    onSave: (String, String, String?) -> Unit,
    onRemove: () -> Unit = {},
) {
    var name by rememberSaveable { mutableStateOf(court?.courtName.orEmpty()) }
    var alias by rememberSaveable { mutableStateOf(court?.courtAlias.orEmpty()) }
    // Index 0 is "Any sport"; the others follow SETTINGS_SPORTS.
    var sportIndex by rememberSaveable { mutableStateOf(court?.sport?.lowercase()?.let { SETTINGS_SPORTS.indexOf(it) + 1 }?.coerceAtLeast(0) ?: 0) }
    var confirmRemove by rememberSaveable { mutableStateOf(false) }
    val anySport = stringResource(R.string.settings_any_sport)
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(if (court == null) R.string.settings_add_court else R.string.settings_edit_court)) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                EditorField(stringResource(R.string.settings_court_name), name, { name = it }, enabled = !busy)
                EditorField(stringResource(R.string.settings_court_alias), alias, { alias = it }, enabled = !busy)
                Text(stringResource(R.string.settings_court_sport), style = MaterialTheme.typography.labelLarge)
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    (0..SETTINGS_SPORTS.size).forEach { index ->
                        val label = if (index == 0) anySport else MatchFormatting.sportName(SETTINGS_SPORTS[index - 1])
                        Surface(
                            onClick = { sportIndex = index },
                            shape = RoundedCornerShape(12.dp),
                            color = if (sportIndex == index) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.primaryContainer,
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text(
                                label,
                                color = if (sportIndex == index) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onPrimaryContainer,
                                modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                            )
                        }
                    }
                }
                if (court != null) {
                    TextButton(onClick = { confirmRemove = true }, enabled = !busy) {
                        Text(stringResource(R.string.settings_remove_court), color = HitNScoreTheme.colors.completedStatus)
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = { onSave(name, alias, if (sportIndex == 0) null else SETTINGS_SPORTS[sportIndex - 1]) },
                enabled = name.isNotBlank() && !busy,
            ) { Text(stringResource(R.string.save)) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
    )
    if (confirmRemove && court != null) {
        ConfirmDialog(
            title = stringResource(R.string.settings_remove_court_title),
            body = stringResource(R.string.settings_remove_court_body, court.courtName),
            confirm = stringResource(R.string.settings_remove),
            onConfirm = {
                confirmRemove = false
                onRemove()
            },
            onDismiss = { confirmRemove = false },
        )
    }
}

private val EMAIL_REGEX = Regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")
