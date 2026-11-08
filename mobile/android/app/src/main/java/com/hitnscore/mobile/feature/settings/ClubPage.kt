package com.hitnscore.mobile.feature.settings

import androidx.annotation.DrawableRes
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.components.CardGrid
import com.hitnscore.mobile.core.designsystem.components.ErrorBanner
import com.hitnscore.mobile.core.designsystem.components.InfoRow
import com.hitnscore.mobile.core.designsystem.components.InnerCard
import com.hitnscore.mobile.core.session.AccountContext
import com.hitnscore.mobile.data.model.ClubRoles
import com.hitnscore.mobile.data.model.MatchFormatting

/**
 * A club from Settings › Association, as the web client: everyone sees the club profile
 * (address, contact, website, socials) read only; club admins also get Edit club profile,
 * Courts, Users and Club Settings for that club, without switching account.
 */
@Composable
fun ClubPage(club: AccountContext, onOpenPage: (SettingsPage, Int) -> Unit) {
    val isAdmin = ClubRoles.normalize(club.role) == ClubRoles.ADMIN
    val viewModel: OrganizationSettingsViewModel = viewModel(
        key = "org-settings-${club.organizationId}",
        factory = OrganizationSettingsViewModel.factory(club.organizationId),
    )
    val ui by viewModel.uiState.collectAsStateWithLifecycle()
    val organization = ui.settings?.organization
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        ui.errorMessage?.let { ErrorBanner(it, onRetry = viewModel::load) }
        if (ui.isLoading && organization == null) CircularProgressIndicator()
        if (organization != null) {
            EditorCard(stringResource(R.string.club_profile), iconRes = R.drawable.ic_club) {
                Text(stringResource(R.string.club_your_role, roleText(club.role)), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
                ProfileRow(R.string.settings_name, organization.organizationName)
                ProfileRow(R.string.settings_contact, organization.contact)
                ProfileRow(R.string.settings_email, organization.email)
                ProfileRow(R.string.settings_telephone, organization.telephone)
                ProfileRow(R.string.settings_website, organization.webAddress)
                ProfileRow(R.string.settings_address, listOf(organization.address, organization.postcode).filter { it.isNotBlank() }.joinToString(", "))
                ProfileRow(R.string.club_sports, organization.enabledSports.joinToString(", ") { MatchFormatting.sportName(it) })
                organization.socialProfiles.filterValues { it.isNotBlank() }.forEach { (network, link) ->
                    InfoRow(socialName(network), link)
                }
            }
            if (isAdmin) {
                Text(stringResource(R.string.club_manage), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                val actions = listOf(
                    Triple(SettingsPage.Organisation, R.string.club_edit_profile, R.drawable.ic_club),
                    Triple(SettingsPage.Courts, R.string.settings_courts, R.drawable.ic_tab_matches),
                    Triple(SettingsPage.Users, R.string.settings_users, R.drawable.ic_person),
                    Triple(SettingsPage.RacketSports, R.string.settings_club_settings, R.drawable.ic_tune),
                )
                CardGrid(actions, columns = 2) { (page, label, icon) ->
                    ActionTile(label, icon) { onOpenPage(page, club.organizationId) }
                }
            } else {
                EditorNote(stringResource(R.string.club_member_note))
            }
        }
    }
}

@Composable
private fun ProfileRow(label: Int, value: String) {
    InfoRow(stringResource(label), value.ifBlank { stringResource(R.string.not_added) })
}

@Composable
private fun ActionTile(label: Int, @DrawableRes icon: Int, onClick: () -> Unit) {
    InnerCard(onClick = onClick, shape = RoundedCornerShape(18.dp)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(painterResource(icon), contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(22.dp))
            Spacer(Modifier.width(10.dp))
            Text(stringResource(label), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
            Icon(painterResource(R.drawable.ic_chevron_right), contentDescription = null, tint = MaterialTheme.colorScheme.primary)
        }
    }
}

@Composable
internal fun roleText(role: String): String = stringResource(
    when (ClubRoles.normalize(role)) {
        ClubRoles.ADMIN -> R.string.role_admin
        ClubRoles.READ_ONLY -> R.string.role_read_only
        else -> R.string.role_scorer
    },
)

private fun socialName(network: String): String = when (network.lowercase()) {
    "x" -> "X"
    "youtube" -> "YouTube"
    else -> network.replaceFirstChar { it.uppercase() }
}
