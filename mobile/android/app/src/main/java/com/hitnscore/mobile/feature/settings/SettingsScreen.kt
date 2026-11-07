package com.hitnscore.mobile.feature.settings

import androidx.annotation.StringRes
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.auth.UserMembership
import com.hitnscore.mobile.core.config.AppEnvironment
import com.hitnscore.mobile.core.designsystem.components.ErrorBanner
import com.hitnscore.mobile.core.designsystem.components.InfoRow
import com.hitnscore.mobile.core.designsystem.components.InnerCard
import com.hitnscore.mobile.core.designsystem.components.SectionCard
import com.hitnscore.mobile.core.session.AccountContextType
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.core.session.planDisplayName
import com.hitnscore.mobile.data.model.ClubRoles
import com.hitnscore.mobile.feature.shell.ShellActions
import com.hitnscore.mobile.feature.shell.ShellHeader
import com.hitnscore.mobile.feature.shell.ShellUiState

/** Settings pages, in the iOS menu order. Club pages are listed for club admins only. */
enum class SettingsPage(val route: String, @StringRes val title: Int, val clubAdminOnly: Boolean = false) {
    Profile("profile", R.string.settings_profile),
    Subscription("subscription", R.string.settings_subscription),
    Association("association", R.string.settings_association),
    GameSettings("game-settings", R.string.settings_game_settings),
    RacketSports("sports", R.string.settings_racket_sports, clubAdminOnly = true),
    About("about", R.string.settings_about),
    Organisation("organisation", R.string.settings_organisation, clubAdminOnly = true),
    Users("users", R.string.settings_users, clubAdminOnly = true),
    Courts("courts", R.string.settings_courts, clubAdminOnly = true),
    ;

    companion object {
        fun fromRoute(route: String?): SettingsPage? = entries.firstOrNull { it.route == route }
    }
}

internal val SessionState.SignedIn.isClubAdmin: Boolean
    get() = activeContext.type == AccountContextType.Club && activeContext.role.equals("admin", ignoreCase = true)

internal val SessionState.SignedIn.isPersonal: Boolean
    get() = activeContext.type == AccountContextType.Personal

@Composable
fun SettingsScreen(
    session: SessionState.SignedIn,
    state: ShellUiState,
    actions: ShellActions,
    biometricUnlockEnabled: Boolean,
    onBiometricUnlockChange: (Boolean) -> Unit,
    onOpenPage: (SettingsPage) -> Unit,
    onSignOut: () -> Unit,
) {
    val accountPages = listOfNotNull(
        SettingsPage.About,
        SettingsPage.Profile,
        SettingsPage.Subscription,
        SettingsPage.Association.takeIf { session.availableContexts.size > 1 },
        SettingsPage.GameSettings,
    )
    val clubPages = if (session.isClubAdmin) {
        listOf(SettingsPage.Organisation, SettingsPage.RacketSports, SettingsPage.Users, SettingsPage.Courts)
    } else {
        emptyList()
    }

    LazyColumn(
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        modifier = Modifier.fillMaxSize(),
    ) {
        item {
            ShellHeader(
                session = session,
                isOnline = state.isOnline,
                hasUnreadNotifications = state.hasUnreadNotifications,
                contextLabel = stringResource(R.string.context_label),
                onOpenNotifications = actions.onOpenNotifications,
                onContextSelected = actions.onContextSelected,
            )
        }
        item { MenuSection(stringResource(R.string.settings_account), accountPages, onOpenPage) }
        if (clubPages.isNotEmpty()) item { MenuSection(stringResource(R.string.settings_club), clubPages, onOpenPage) }
        item {
            QuickUnlockSetting(enabled = biometricUnlockEnabled, onEnabledChange = onBiometricUnlockChange)
        }
        item {
            Text(
                stringResource(R.string.settings_signed_in_as, session.username),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        item {
            OutlinedButton(onClick = onSignOut, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.sign_out))
            }
        }
    }
}

@Composable
private fun MenuSection(title: String, pages: List<SettingsPage>, onOpenPage: (SettingsPage) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(start = 4.dp))
        Surface(shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.surface, modifier = Modifier.fillMaxWidth()) {
            Column {
                pages.forEachIndexed { index, page ->
                    Surface(onClick = { onOpenPage(page) }, color = MaterialTheme.colorScheme.surface) {
                        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(stringResource(page.title), style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                            Icon(painterResource(R.drawable.ic_chevron_right), contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                        }
                    }
                    if (index < pages.lastIndex) HorizontalDivider(Modifier.padding(start = 16.dp), color = MaterialTheme.colorScheme.outlineVariant)
                }
            }
        }
    }
}

/** One settings page with standard back navigation, as iOS. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsPageScreen(
    page: SettingsPage,
    session: SessionState.SignedIn,
    memberships: List<UserMembership>,
    state: ShellUiState,
    onContextSelected: (com.hitnscore.mobile.core.session.AccountContext) -> Unit,
    onBack: () -> Unit,
) {
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(page.title)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(painterResource(R.drawable.ic_arrow_back), contentDescription = stringResource(R.string.back))
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background),
            )
        },
    ) { padding ->
        LazyColumn(
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = padding.calculateTopPadding() + 4.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            when (page) {
                SettingsPage.Profile -> item(key = "profile-${session.username}") {
                    val viewModel: ProfileViewModel = viewModel(key = "profile-${session.username}", factory = ProfileViewModel.Factory)
                    val ui by viewModel.uiState.collectAsStateWithLifecycle()
                    ProfileEditor(ui, viewModel)
                    Note(stringResource(R.string.settings_role_line, session.activeContext.name, roleName(session.activeContext.role)))
                }
                SettingsPage.Subscription -> {
                    val organization = state.dashboard?.organization
                    val isPersonal = session.activeContext.type == AccountContextType.Personal
                    val plan = organization?.plan?.let { planDisplayName(it, isPersonal) } ?: session.activeContext.plan
                    item { InfoRow(stringResource(R.string.settings_plan), plan) }
                    organization?.entitlements?.let { e ->
                        item {
                            InfoRow(
                                stringResource(R.string.settings_history_limit),
                                if (e.historyLimit <= 0 || e.historyLimit >= UNLIMITED_HISTORY) {
                                    stringResource(R.string.settings_history_unlimited)
                                } else {
                                    stringResource(R.string.settings_history_n, e.historyLimit)
                                },
                            )
                        }
                        item {
                            InfoRow(
                                stringResource(R.string.settings_performance),
                                stringResource(if (e.performanceEnabled) R.string.settings_included else R.string.settings_not_included),
                            )
                        }
                    }
                    item { Note(stringResource(R.string.settings_subscription_note)) }
                }
                SettingsPage.Association -> items(session.availableContexts, key = { it.membershipId }) { context ->
                    InnerCard(shape = RoundedCornerShape(16.dp)) {
                        Row(Modifier.padding(horizontal = 14.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text(context.name, style = MaterialTheme.typography.titleMedium)
                                Text(context.plan, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            if (context.membershipId == session.activeContext.membershipId) {
                                Text(stringResource(R.string.settings_active), color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.labelLarge)
                            } else {
                                TextButton(onClick = { onContextSelected(context) }) { Text(stringResource(R.string.settings_switch_to)) }
                            }
                        }
                    }
                }
                SettingsPage.RacketSports, SettingsPage.GameSettings -> clubPage(page, session)
                SettingsPage.About -> {
                    item { InfoRow(stringResource(R.string.settings_version), AppEnvironment.versionName) }
                    item { InfoRow(stringResource(R.string.settings_environment), AppEnvironment.environmentName) }
                }
                SettingsPage.Organisation, SettingsPage.Users, SettingsPage.Courts -> clubPage(page, session)
            }
        }
    }
}

private const val UNLIMITED_HISTORY = 100_000

/**
 * Pages backed by the organisation's settings. Club admins can change everything; a
 * Personal owner changes their own sports and timer defaults; other club members only
 * see Game Settings, read-only, as on iOS.
 */
private fun LazyListScope.clubPage(page: SettingsPage, session: SessionState.SignedIn) {
    val readOnlyGameSettings = page == SettingsPage.GameSettings && !session.isClubAdmin && !session.isPersonal
    if (page.clubAdminOnly && !session.isClubAdmin) {
        item { Note(stringResource(R.string.settings_admin_only)) }
        return
    }
    item(key = "club-${session.activeContext.organizationId}-${page.route}") {
        val organizationId = session.activeContext.organizationId
        val viewModel: OrganizationSettingsViewModel = viewModel(
            key = "org-settings-$organizationId",
            factory = OrganizationSettingsViewModel.factory(organizationId),
        )
        val ui by viewModel.uiState.collectAsStateWithLifecycle()
        val settings = ui.settings
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            ui.errorMessage?.let { ErrorBanner(it, onRetry = viewModel::load) }
            if (ui.isLoading && settings == null) CircularProgressIndicator()
            if (settings != null) {
                when (page) {
                    SettingsPage.Organisation -> {
                        OrganisationEditor(ui, viewModel)
                        InfoRow(stringResource(R.string.settings_plan), planDisplayName(settings.organization.plan, isPersonal = false))
                    }
                    SettingsPage.RacketSports -> {
                        SportsEditor(ui, viewModel, canEdit = true, body = stringResource(R.string.settings_sports_club_body))
                        StatusLine(ui.notice, ui.actionError)
                    }
                    SettingsPage.GameSettings -> {
                        if (session.isPersonal) {
                            SportsEditor(ui, viewModel, canEdit = true, body = stringResource(R.string.settings_sports_personal_body))
                        }
                        TimerDefaultsEditor(ui, viewModel, canEdit = !readOnlyGameSettings)
                        StatusLine(ui.notice, ui.actionError)
                    }
                    SettingsPage.Users -> UsersEditor(ui, viewModel, session.username)
                    SettingsPage.Courts -> CourtsEditor(ui, viewModel)
                    else -> Unit
                }
            }
        }
    }
}

@Composable
private fun roleName(role: String): String = stringResource(
    when (ClubRoles.normalize(role)) {
        ClubRoles.ADMIN -> R.string.role_admin
        ClubRoles.READ_ONLY -> R.string.role_read_only
        else -> R.string.role_scorer
    },
)

@Composable
private fun Note(text: String) {
    Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 6.dp))
}
