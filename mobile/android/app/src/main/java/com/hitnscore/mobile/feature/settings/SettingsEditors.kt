package com.hitnscore.mobile.feature.settings

import androidx.annotation.DrawableRes
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
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
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.components.CardGrid
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

/** A settings section as iOS: soft rounded card, bold heading with an optional icon and action. */
@Composable
internal fun EditorCard(
    title: String? = null,
    @DrawableRes iconRes: Int? = null,
    action: (@Composable () -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Surface(
        shape = RoundedCornerShape(24.dp),
        color = HitNScoreTheme.colors.card,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (title != null || action != null) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (iconRes != null) {
                        Icon(painterResource(iconRes), contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(22.dp))
                        Spacer(Modifier.width(10.dp))
                    }
                    Text(title.orEmpty(), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                    action?.invoke()
                }
            }
            content()
        }
    }
}

/** Grey explanation under a section heading. */
@Composable
internal fun EditorNote(text: String) {
    Text(text, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

/**
 * A labelled field as iOS: grey label above a white rounded box with a light border.
 * [readOnly] shows the value plainly (dark text, not greyed out) until the user taps Edit.
 */
@Composable
internal fun EditorField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    enabled: Boolean = true,
    isError: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
    capitalization: KeyboardCapitalization = KeyboardCapitalization.Words,
    readOnly: Boolean = false,
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(label, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
        val border = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.7f)
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            placeholder = { Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)) },
            singleLine = true,
            enabled = enabled,
            readOnly = readOnly,
            isError = isError && !readOnly,
            shape = RoundedCornerShape(18.dp),
            textStyle = MaterialTheme.typography.bodyLarge,
            colors = OutlinedTextFieldDefaults.colors(
                focusedContainerColor = MaterialTheme.colorScheme.surface,
                unfocusedContainerColor = MaterialTheme.colorScheme.surface,
                disabledContainerColor = MaterialTheme.colorScheme.surface,
                unfocusedBorderColor = border,
                disabledBorderColor = border,
                focusedBorderColor = if (readOnly) border else MaterialTheme.colorScheme.primary,
            ),
            keyboardOptions = KeyboardOptions(
                capitalization = if (keyboardType == KeyboardType.Email) KeyboardCapitalization.None else capitalization,
                autoCorrectEnabled = keyboardType != KeyboardType.Email,
                keyboardType = keyboardType,
                imeAction = ImeAction.Next,
            ),
            modifier = Modifier.fillMaxWidth(),
        )
    }
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
    // Read only until Edit is tapped; a successful save returns to read only.
    var editing by rememberSaveable { mutableStateOf(false) }
    LaunchedEffect(state.saved) { if (state.saved) editing = false }
    val form = state.form
    val busy = state.isSaving || state.isDeleting
    val locked = !editing || busy
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        EditorCard(
            title = stringResource(R.string.settings_profile),
            iconRes = R.drawable.ic_person,
            action = {
                if (editing) {
                    TextButton(onClick = {
                        viewModel.discardChanges()
                        editing = false
                    }, enabled = !busy) { Text(stringResource(R.string.cancel)) }
                } else {
                    FilledTonalButton(onClick = { editing = true }) { Text(stringResource(R.string.settings_edit)) }
                }
            },
        ) {
            EditorNote(stringResource(R.string.settings_profile_body))
            EditorField(stringResource(R.string.setup_first_name), form.firstName, { v -> viewModel.update { it.copy(firstName = v) } }, readOnly = locked, isError = form.firstName.isBlank())
            EditorField(stringResource(R.string.setup_surname), form.surname, { v -> viewModel.update { it.copy(surname = v) } }, readOnly = locked)
            EditorField(stringResource(R.string.settings_email), form.email, { v -> viewModel.update { it.copy(email = v) } }, readOnly = locked, keyboardType = KeyboardType.Email)
            if (state.emailChanged) {
                Text(stringResource(R.string.settings_email_change_note), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            EditorField(stringResource(R.string.settings_telephone), form.telephone, { v -> viewModel.update { it.copy(telephone = v) } }, readOnly = locked, keyboardType = KeyboardType.Phone)
            EditorField(stringResource(R.string.settings_city), form.cityLocation, { v -> viewModel.update { it.copy(cityLocation = v) } }, readOnly = locked)
            EditorField(stringResource(R.string.settings_country_origin), form.country, { v -> viewModel.update { it.copy(country = v) } }, readOnly = locked)
            StatusLine(if (state.saved) SettingsNotice.Saved else if (state.resetSent) SettingsNotice.ResetSent else null, state.errorMessage)
            if (editing) {
                SaveButton(stringResource(R.string.settings_save_profile), enabled = state.canSave, busy = state.isSaving, onClick = viewModel::save)
            }
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
    // Social profiles: each has a switch, and its link can only be entered while it is on.
    val savedSocial = SOCIAL_NETWORKS.associateWith { organization.socialProfiles[it].orEmpty() }
    var socialOn by remember(organization) { mutableStateOf(savedSocial.mapValues { it.value.isNotBlank() }) }
    var social by remember(organization) { mutableStateOf(savedSocial) }
    val socialToSave = SOCIAL_NETWORKS.associateWith { if (socialOn[it] == true) social[it].orEmpty().trim() else "" }
    val changed = name != organization.organizationName || contact != organization.contact || email != organization.email ||
        telephone != organization.telephone || website != organization.webAddress || address != organization.address || postcode != organization.postcode ||
        socialToSave != savedSocial
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
        EditorCard(stringResource(R.string.social_profiles)) {
            EditorNote(stringResource(R.string.social_profiles_body))
            SOCIAL_NETWORKS.forEach { network ->
                val on = socialOn[network] == true
                SwitchLine(stringResource(socialLabel(network)), null, on, enabled = !state.isSaving) { value ->
                    socialOn = socialOn + (network to value)
                }
                if (on) {
                    EditorField(
                        stringResource(R.string.social_link_label, stringResource(socialLabel(network))),
                        social[network].orEmpty(),
                        { value -> social = social + (network to value) },
                        enabled = !state.isSaving,
                        keyboardType = KeyboardType.Uri,
                        capitalization = KeyboardCapitalization.None,
                    )
                }
            }
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
                    socialProfiles = socialToSave,
                ),
            )
        }
    }
}

/** "+" (add) and a filter drop-down with a count: the top row of Courts and Users. */
@Composable
internal fun <T> AddAndFilterRow(
    addLabel: String,
    onAdd: () -> Unit,
    enabled: Boolean,
    options: List<T>,
    selected: T,
    optionLabel: @Composable (T) -> String,
    onSelect: (T) -> Unit,
    count: String,
) {
    var open by remember { mutableStateOf(false) }
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        FilledIconButton(onClick = onAdd, enabled = enabled) {
            Icon(painterResource(R.drawable.ic_add), contentDescription = addLabel)
        }
        if (options.size > 1) {
            Box {
                OutlinedButton(onClick = { open = true }, shape = RoundedCornerShape(50)) {
                    Text(optionLabel(selected))
                    Icon(painterResource(R.drawable.ic_expand_more), contentDescription = null, modifier = Modifier.padding(start = 6.dp).size(18.dp))
                }
                DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
                    options.forEach { option ->
                        DropdownMenuItem(text = { Text(optionLabel(option)) }, onClick = { onSelect(option); open = false })
                    }
                }
            }
        }
        Spacer(Modifier.weight(1f))
        Text(count, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

internal val SOCIAL_NETWORKS = listOf("facebook", "instagram", "x", "youtube")

private fun socialLabel(network: String): Int = when (network) {
    "instagram" -> R.string.social_instagram
    "x" -> R.string.social_x
    "youtube" -> R.string.social_youtube
    else -> R.string.social_facebook
}

// Racket sports and timer defaults ------------------------------------------------

/**
 * Racket sports access, styled as iOS Game Settings: one white card per sport with its ball,
 * "Ready" and a switch. A switch saves straight away (as iOS), keeping at least one sport.
 */
@Composable
fun SportsEditor(state: OrganizationSettingsUiState, viewModel: OrganizationSettingsViewModel, canEdit: Boolean, body: String, title: String? = null) {
    val saved = state.settings?.organization?.enabledSports?.map { it.lowercase() }?.toSet() ?: return
    EditorCard(title ?: stringResource(R.string.settings_racket_sports), iconRes = R.drawable.ic_tune) {
        EditorNote(body)
        SETTINGS_SPORTS.forEach { sport ->
            val on = sport in saved
            SportRow(
                sport = sport,
                checked = on,
                enabled = canEdit && !state.isSaving && !(on && saved.size == 1),
            ) { value ->
                val next = if (value) saved + sport else saved - sport
                if (next.isNotEmpty()) viewModel.saveSports(SETTINGS_SPORTS.filter { it in next })
            }
        }
    }
}

@Composable
private fun SportRow(sport: String, checked: Boolean, enabled: Boolean, onChange: (Boolean) -> Unit) {
    Surface(
        shape = RoundedCornerShape(22.dp),
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(Modifier.padding(horizontal = 14.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(48.dp)
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.08f), RoundedCornerShape(14.dp)),
            ) {
                Image(painterResource(sportBall(sport)), contentDescription = null, modifier = Modifier.size(26.dp))
            }
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(MatchFormatting.sportName(sport), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Text(stringResource(R.string.settings_sport_live), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Switch(checked = checked, onCheckedChange = onChange, enabled = enabled)
        }
    }
}

private fun sportBall(sport: String): Int = when (sport) {
    "racketball" -> R.drawable.sport_ball_racketball
    "tennis" -> R.drawable.sport_ball_tennis
    "padel" -> R.drawable.sport_ball_padel
    else -> R.drawable.sport_ball_squash
}

/**
 * Automatic match timing, as iOS: per sport, whether a new match starts with the timed
 * warm-up and breaks switched on. Match setup reads these (`timed_break_defaults`), and the
 * timer can still be switched on or off for a single match.
 */
@Composable
fun TimerDefaultsEditor(state: OrganizationSettingsUiState, viewModel: OrganizationSettingsViewModel, canEdit: Boolean) {
    val organization = state.settings?.organization ?: return
    val saved = SETTINGS_SPORTS.associateWith { organization.timedBreakDefaults[it] ?: false }
    var draft by remember(organization.timedBreakDefaults) { mutableStateOf(saved) }
    val enabled = organization.enabledSports.map { it.lowercase() }
    EditorCard(stringResource(R.string.settings_timer_defaults), iconRes = R.drawable.ic_timer) {
        EditorNote(stringResource(R.string.settings_timer_defaults_body))
        SETTINGS_SPORTS.filter { it in enabled }.forEach { sport ->
            val on = draft[sport] == true
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(MatchFormatting.sportName(sport), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text(
                        stringResource(if (on) R.string.settings_timer_on else R.string.settings_timer_off),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Switch(checked = on, onCheckedChange = { value -> draft = draft + (sport to value) }, enabled = canEdit && !state.isSaving)
            }
        }
        if (canEdit) {
            Button(
                onClick = { viewModel.saveTimerDefaults(draft) },
                enabled = draft != saved && !state.isSaving,
                shape = RoundedCornerShape(50),
                contentPadding = PaddingValues(horizontal = 28.dp, vertical = 14.dp),
            ) {
                if (state.isSaving) {
                    CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp, color = MaterialTheme.colorScheme.onPrimary)
                } else {
                    Text(stringResource(R.string.settings_save_timers), style = MaterialTheme.typography.titleMedium)
                }
            }
        } else {
            EditorNote(stringResource(R.string.settings_admin_only))
        }
    }
}

// Users ---------------------------------------------------------------------------

@Composable
fun UsersEditor(state: OrganizationSettingsUiState, viewModel: OrganizationSettingsViewModel, signedInUsername: String) {
    val users = state.settings?.users ?: return
    var editing by remember { mutableStateOf<OrganizationUser?>(null) }
    var adding by rememberSaveable { mutableStateOf(false) }
    // Role filter, as Courts: null = everyone.
    var roleFilter by rememberSaveable { mutableStateOf<String?>(null) }
    val shown = users
        .filter { roleFilter == null || ClubRoles.normalize(it.role) == roleFilter }
        .sortedWith(compareBy({ it.firstName.ifBlank { it.username }.lowercase() }, { it.surname.lowercase() }))
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        StatusLine(state.notice, state.actionError)
        AddAndFilterRow(
            addLabel = stringResource(R.string.settings_add_user),
            onAdd = { adding = true },
            enabled = !state.isSaving,
            options = listOf(null) + ClubRoles.all,
            selected = roleFilter,
            optionLabel = { role -> if (role == null) stringResource(R.string.settings_all_members) else roleLabelPlural(role) },
            onSelect = { roleFilter = it },
            count = pluralStringResource(R.plurals.settings_member_count, shown.size, shown.size),
        )
        if (shown.isEmpty()) EditorNote(stringResource(R.string.settings_members_empty))
        CardGrid(shown) { user ->
            EditorCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(
                            MatchFormatting.fullName(user.firstName.ifBlank { user.username }, user.surname),
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        Text(user.username, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                    IconButton(onClick = { editing = user }, enabled = !state.isSaving) {
                        Icon(painterResource(R.drawable.ic_edit), contentDescription = stringResource(R.string.settings_edit_user), tint = MaterialTheme.colorScheme.primary)
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        roleLabel(user.role),
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier
                            .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.1f), RoundedCornerShape(50))
                            .padding(horizontal = 12.dp, vertical = 5.dp),
                    )
                    if (user.status.equals("pending", ignoreCase = true)) {
                        Text(stringResource(R.string.settings_user_pending), style = MaterialTheme.typography.labelMedium, color = HitNScoreTheme.colors.brandPink)
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
private fun roleLabelPlural(role: String): String = stringResource(
    when (ClubRoles.normalize(role)) {
        ClubRoles.ADMIN -> R.string.role_admins
        ClubRoles.READ_ONLY -> R.string.role_viewers
        else -> R.string.role_scorers
    },
)

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
    val enabledSports = state.settings?.organization?.enabledSports.orEmpty().map { it.lowercase() }
    var editing by remember { mutableStateOf<CourtSummary?>(null) }
    var adding by rememberSaveable { mutableStateOf(false) }
    // Filter: only court types the club has courts for and plays (squash covers racketball).
    var typeFilter by rememberSaveable { mutableStateOf<String?>(null) }
    val types = CourtTypes.available(enabledSports).filter { type -> courts.any { CourtTypes.of(it.sport) == type } }
    if (typeFilter != null && typeFilter !in types) typeFilter = null
    val shown = courts.filter { typeFilter == null || it.sport.isNullOrBlank() || CourtTypes.of(it.sport) == typeFilter }
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        StatusLine(state.notice, state.actionError)
        AddAndFilterRow(
            addLabel = stringResource(R.string.settings_add_court),
            onAdd = { adding = true },
            enabled = !state.isSaving,
            options = listOf<String?>(null) + types,
            selected = typeFilter,
            optionLabel = { type -> if (type == null) stringResource(R.string.settings_all_racket_sports) else CourtTypes.label(type) },
            onSelect = { typeFilter = it },
            count = pluralStringResource(R.plurals.settings_court_count, shown.size, shown.size),
        )
        if (shown.isEmpty()) {
            EditorNote(stringResource(R.string.settings_courts_empty))
        }
        CardGrid(shown) { court ->
            EditorCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(court.courtName.ifBlank { court.courtAlias }, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                        Text(
                            listOfNotNull(
                                court.courtAlias.takeIf { it.isNotBlank() && it != court.courtName },
                                court.sport?.takeIf { it.isNotBlank() }?.let { CourtTypes.label(CourtTypes.of(it)) } ?: stringResource(R.string.settings_any_sport),
                            ).joinToString(" · "),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    IconButton(onClick = { editing = court }, enabled = !state.isSaving) {
                        Icon(painterResource(R.drawable.ic_edit), contentDescription = stringResource(R.string.settings_edit_court), tint = MaterialTheme.colorScheme.primary)
                    }
                }
                Column {
                    Text(stringResource(R.string.settings_display_code), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(
                        court.displayCode?.takeIf { it.isNotBlank() } ?: stringResource(R.string.settings_display_code_none),
                        style = MaterialTheme.typography.titleMedium.copy(fontFeatureSettings = "tnum"),
                    )
                }
            }
        }
    }
    if (adding) {
        CourtDialog(court = null, types = CourtTypes.available(enabledSports), busy = state.isSaving, onDismiss = { adding = false }, onSave = { name, alias, sport ->
            adding = false
            viewModel.saveCourt(null, name, alias, sport)
        })
    }
    editing?.let { court ->
        CourtDialog(
            court = court,
            types = CourtTypes.available(enabledSports),
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
            // The scoreboard code changes only from here, after a confirmation.
            onRefreshCode = {
                editing = null
                viewModel.newDisplayCode(court.id)
            },
        )
    }
}

@Composable
private fun CourtDialog(
    court: CourtSummary?,
    types: List<String>,
    busy: Boolean,
    onDismiss: () -> Unit,
    onSave: (String, String, String?) -> Unit,
    onRemove: () -> Unit = {},
    onRefreshCode: () -> Unit = {},
) {
    var name by rememberSaveable { mutableStateOf(court?.courtName.orEmpty()) }
    var alias by rememberSaveable { mutableStateOf(court?.courtAlias.orEmpty()) }
    // The court type is chosen once, when the court is added; it can't change afterwards.
    var type by rememberSaveable { mutableStateOf(types.firstOrNull()) }
    var confirmRemove by rememberSaveable { mutableStateOf(false) }
    var confirmCode by rememberSaveable { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(if (court == null) R.string.settings_add_court else R.string.settings_edit_court)) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                EditorField(stringResource(R.string.settings_court_name), name, { name = it }, enabled = !busy)
                EditorField(stringResource(R.string.settings_court_alias), alias, { alias = it }, enabled = !busy)
                Text(stringResource(R.string.settings_court_type), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                if (court == null) {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        types.forEach { option ->
                            Surface(
                                onClick = { type = option },
                                shape = RoundedCornerShape(12.dp),
                                color = if (type == option) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.primaryContainer,
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                Text(
                                    CourtTypes.label(option),
                                    color = if (type == option) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onPrimaryContainer,
                                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                                )
                            }
                        }
                    }
                    EditorNote(stringResource(R.string.settings_court_type_note))
                } else {
                    Text(
                        court.sport?.takeIf { it.isNotBlank() }?.let { CourtTypes.label(CourtTypes.of(it)) } ?: stringResource(R.string.settings_any_sport),
                        style = MaterialTheme.typography.titleMedium,
                    )
                }
                if (court != null) {
                    // Scoreboard code: shown here and refreshed only from the edit dialog.
                    Text(stringResource(R.string.settings_display_code), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            court.displayCode?.takeIf { it.isNotBlank() } ?: stringResource(R.string.settings_display_code_none),
                            style = MaterialTheme.typography.titleMedium.copy(fontFeatureSettings = "tnum"),
                            modifier = Modifier.weight(1f),
                        )
                        OutlinedButton(onClick = { confirmCode = true }, enabled = !busy) { Text(stringResource(R.string.settings_refresh_code)) }
                    }
                    TextButton(onClick = { confirmRemove = true }, enabled = !busy) {
                        Text(stringResource(R.string.settings_remove_court), color = HitNScoreTheme.colors.completedStatus)
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                // An existing court keeps its sport as saved.
                onClick = { onSave(name, alias, if (court != null) court.sport else type) },
                enabled = name.isNotBlank() && !busy && (court != null || type != null),
            ) { Text(stringResource(R.string.save)) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
    )
    if (confirmCode && court != null) {
        ConfirmDialog(
            title = stringResource(R.string.settings_refresh_code),
            body = stringResource(R.string.settings_new_display_code_body, court.courtName),
            confirm = stringResource(R.string.settings_new_display_code_confirm),
            onConfirm = {
                confirmCode = false
                onRefreshCode()
            },
            onDismiss = { confirmCode = false },
        )
    }
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

/**
 * Court types. Squash and racketball share the same courts, so both are a "Squash court";
 * tennis and Padel have their own. Stored as the backend's sport code.
 */
internal object CourtTypes {
    const val SQUASH = "squash"
    const val TENNIS = "tennis"
    const val PADEL = "padel"

    fun of(sport: String?): String = when (sport?.lowercase()) {
        "racketball", "racquetball", SQUASH -> SQUASH
        TENNIS -> TENNIS
        PADEL -> PADEL
        else -> SQUASH
    }

    /** Court types for the sports the club has switched on. */
    fun available(enabledSports: List<String>): List<String> = listOf(SQUASH, TENNIS, PADEL).filter { type ->
        enabledSports.any { of(it) == type }
    }

    @Composable
    fun label(type: String): String = stringResource(
        when (type) {
            TENNIS -> R.string.court_type_tennis
            PADEL -> R.string.court_type_padel
            else -> R.string.court_type_squash
        },
    )
}
