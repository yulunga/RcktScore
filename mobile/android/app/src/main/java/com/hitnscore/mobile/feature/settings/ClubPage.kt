package com.hitnscore.mobile.feature.settings

import android.annotation.SuppressLint
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.annotation.DrawableRes
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.components.CardGrid
import com.hitnscore.mobile.core.designsystem.components.ErrorBanner
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
        // Admins: the club's management pages first.
        if (isAdmin) {
            Text(stringResource(R.string.club_manage), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            val actions = listOf(
                Triple(SettingsPage.Courts, R.string.settings_courts, R.drawable.ic_tab_matches),
                Triple(SettingsPage.Users, R.string.settings_users, R.drawable.ic_person),
                Triple(SettingsPage.RacketSports, R.string.settings_club_settings, R.drawable.ic_tune),
            )
            // One row: icon above the label.
            CardGrid(actions, columns = actions.size) { (page, label, icon) ->
                ActionTile(label, icon) { onOpenPage(page, club.organizationId) }
            }
        }
        ui.errorMessage?.let { ErrorBanner(it, onRetry = viewModel::load) }
        if (ui.isLoading && organization == null) CircularProgressIndicator()
        if (organization != null) {
            // Pencil next to the heading: edit the club profile (admins only).
            val editProfile: (@Composable () -> Unit)? = if (!isAdmin) null else {
                {
                    IconButton(onClick = { onOpenPage(SettingsPage.Organisation, club.organizationId) }) {
                        Icon(painterResource(R.drawable.ic_edit), contentDescription = stringResource(R.string.club_edit_profile), tint = MaterialTheme.colorScheme.primary)
                    }
                }
            }
            EditorCard(
                stringResource(R.string.club_profile),
                iconRes = R.drawable.ic_club,
                action = editProfile,
            ) {
                Text(stringResource(R.string.club_your_role, roleText(club.role)), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
                ProfileRow(R.string.settings_name, organization.organizationName)
                ProfileRow(R.string.settings_contact, organization.contact)
                ProfileRow(R.string.settings_email, organization.email)
                ProfileRow(R.string.settings_telephone, organization.telephone)
                ProfileRow(R.string.settings_website, organization.webAddress)
                ProfileRow(R.string.settings_address, listOf(organization.address, organization.postcode).filter { it.isNotBlank() }.joinToString(", "))
                ProfileRow(R.string.club_sports, organization.enabledSports.joinToString(", ") { MatchFormatting.sportName(it) })
            }
            val address = listOf(organization.organizationName, organization.address, organization.postcode).filter { it.isNotBlank() }.joinToString(", ")
            if (organization.address.isNotBlank() || organization.postcode.isNotBlank()) {
                EditorCard(stringResource(R.string.club_venue_map), iconRes = R.drawable.ic_map) {
                    EditorNote(stringResource(R.string.club_venue_map_body))
                    VenueMap(address)
                }
            }
            // Social profiles under the map, as the web; admins add them from Edit Profile.
            EditorCard(stringResource(R.string.social_profiles), iconRes = R.drawable.ic_share) {
                SOCIAL_NETWORKS.forEach { network ->
                    CompactRow(socialName(network), organization.socialProfiles[network]?.takeIf { it.isNotBlank() } ?: stringResource(R.string.not_added))
                }
                if (isAdmin) EditorNote(stringResource(R.string.social_profiles_admin_note))
            }
            if (!isAdmin) EditorNote(stringResource(R.string.club_member_note))
        }
    }
}

@Composable
private fun ProfileRow(label: Int, value: String) {
    CompactRow(stringResource(label), value.ifBlank { stringResource(R.string.not_added) })
}

/** Small label above a body-size value, with a hairline under it: denser than InfoRow. */
@Composable
private fun CompactRow(label: String, value: String) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.bodyMedium)
        HorizontalDivider(Modifier.padding(top = 8.dp), color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
    }
}

/**
 * Map preview of the club's saved address, as the web: Google Maps' embed page (no API key)
 * in a small WebView. The preview itself isn't interactive (it would fight the page scroll);
 * tapping it, or Open in Maps, opens the address in the phone's maps app.
 */
@SuppressLint("SetJavaScriptEnabled") // Google's embed page needs JavaScript; it loads nothing else.
@Composable
private fun VenueMap(address: String) {
    val context = LocalContext.current
    val openMaps = {
        val uri = Uri.parse("geo:0,0?q=" + Uri.encode(address))
        try {
            context.startActivity(Intent(Intent.ACTION_VIEW, uri))
        } catch (noMapsApp: ActivityNotFoundException) {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/maps/search/?api=1&query=" + Uri.encode(address))))
        }
    }
    // Google only serves the embed page inside an iframe (as the web page does), so the
    // WebView loads a tiny page that holds the map iframe.
    val url = "https://maps.google.com/maps?q=" + Uri.encode(address) + "&z=15&output=embed"
    val html = """
        <!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <style>html,body{margin:0;height:100%;overflow:hidden}iframe{border:0;width:100%;height:100%}</style>
        </head><body><iframe src="$url" loading="lazy" referrerpolicy="no-referrer-when-downgrade"></iframe></body></html>
    """.trimIndent()
    Box(
        Modifier
            .fillMaxWidth()
            .height(220.dp)
            .clip(RoundedCornerShape(18.dp)),
    ) {
        AndroidView(
            factory = { ctx ->
                WebView(ctx).apply {
                    settings.javaScriptEnabled = true
                    settings.domStorageEnabled = true
                    webViewClient = WebViewClient()
                    tag = url
                    loadDataWithBaseURL("https://app.hitnscore.com/", html, "text/html", "utf-8", null)
                }
            },
            update = { view ->
                if (view.tag != url) {
                    view.tag = url
                    view.loadDataWithBaseURL("https://app.hitnscore.com/", html, "text/html", "utf-8", null)
                }
            },
            modifier = Modifier.matchParentSize(),
        )
        // Catches taps so the map opens in the maps app instead of scrolling inside the page.
        Box(Modifier.matchParentSize().clickable(onClickLabel = stringResource(R.string.club_open_in_maps), onClick = openMaps))
    }
    TextButton(onClick = openMaps) {
        Icon(painterResource(R.drawable.ic_map), contentDescription = null, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(6.dp))
        Text(stringResource(R.string.club_open_in_maps))
    }
}

@Composable
private fun ActionTile(label: Int, @DrawableRes icon: Int, onClick: () -> Unit) {
    InnerCard(onClick = onClick, shape = RoundedCornerShape(18.dp)) {
        Column(
            Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 14.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Icon(painterResource(icon), contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(28.dp))
            Text(
                stringResource(label),
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.primary,
                textAlign = TextAlign.Center,
                maxLines = 1,
            )
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
    "x" -> "X / Twitter"
    "youtube" -> "YouTube"
    else -> network.replaceFirstChar { it.uppercase() }
}
