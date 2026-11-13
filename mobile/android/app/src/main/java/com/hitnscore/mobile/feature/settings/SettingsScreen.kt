package com.hitnscore.mobile.feature.settings

import com.hitnscore.mobile.feature.scoring.StrokeLetHelpSetting
import com.hitnscore.mobile.feature.scoring.canUseStrokeLetHelp
import androidx.annotation.StringRes
import androidx.compose.foundation.background
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
import com.hitnscore.mobile.feature.shell.contextTitle
import com.hitnscore.mobile.core.auth.UserMembership
import com.hitnscore.mobile.core.config.AppEnvironment
import com.hitnscore.mobile.core.designsystem.components.ErrorBanner
import com.hitnscore.mobile.core.designsystem.components.InfoRow
import com.hitnscore.mobile.core.designsystem.components.InnerCard
import com.hitnscore.mobile.core.session.AccountContext
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
    RacketSports("sports", R.string.settings_club_settings, clubAdminOnly = true),
    About("about", R.string.settings_about),
    Organisation("organisation", R.string.settings_organisation, clubAdminOnly = true),
    Users("users", R.string.settings_users, clubAdminOnly = true),
    Courts("courts", R.string.settings_courts, clubAdminOnly = true),
    /** One club from Association (not in the menus); its title is the club's name. */
    Club("club", R.string.settings_association),
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
    /** A club page for a given club (as from Association). */
    onOpenClubPage: (SettingsPage, Int) -> Unit = { page, _ -> onOpenPage(page) },
) {
    val accountPages = listOfNotNull(
        SettingsPage.About,
        SettingsPage.Profile,
        SettingsPage.Subscription,
        SettingsPage.Association.takeIf { session.availableContexts.size > 1 },
        SettingsPage.GameSettings,
    )
    // Club admins: the same pages as Association › club, for the active club. Organisation
    // opens that club page (profile, map, socials and the manage tiles).
    val clubPages = if (session.isClubAdmin) {
        listOf(SettingsPage.Organisation, SettingsPage.Users, SettingsPage.Courts, SettingsPage.RacketSports)
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
                onOpenNotifications = actions.onOpenNotifications,
                onContextSelected = actions.onContextSelected,
                onSignOut = actions.onSignOut,
            )
        }
        // As iOS: Settings opens with the player's photo, name and email (every account).
        item(key = "photo-${session.username}") {
            EditorCard {
                ProfilePhotoHeader(
                    username = session.username,
                    personalOrganizationId = session.availableContexts.firstOrNull { it.type == AccountContextType.Personal }?.organizationId,
                    displayName = personName(session),
                    email = session.username,
                    // Under the name: the Personal tier (Personal / Personal+), when they have one.
                    tier = session.availableContexts.firstOrNull { it.type == AccountContextType.Personal }?.let { contextTitle(it) },
                )
            }
        }
        item { MenuSection(stringResource(R.string.settings_account), accountPages, onOpenPage) }
        if (clubPages.isNotEmpty()) {
            item {
                MenuSection(stringResource(R.string.settings_club), clubPages) { page ->
                    onOpenClubPage(if (page == SettingsPage.Organisation) SettingsPage.Club else page, session.activeContext.organizationId)
                }
            }
        }
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
    /** The club a page acts on, from Association; null = the active account. */
    organizationId: Int? = null,
    onOpenPage: (SettingsPage, Int?) -> Unit = { _, _ -> },
) {
    val target = organizationId?.let { id -> session.availableContexts.firstOrNull { it.organizationId == id } } ?: session.activeContext
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text(if (page == SettingsPage.Club) target.name else stringResource(page.title)) },
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
                SettingsPage.Subscription -> item(key = "subscription") {
                    // The dashboard's plan is the freshest for the active Personal account.
                    val activePersonal = session.activeContext.type == AccountContextType.Personal
                    SubscriptionPage(session, personalPlusOverride = state.planCode?.takeIf { activePersonal }?.let { it == "personal_plus" })
                }
                // Only the clubs you belong to, with your role; tap one for its club page.
                SettingsPage.Association -> {
                    val clubs = session.availableContexts.filter { it.type == AccountContextType.Club }
                    if (clubs.isEmpty()) item { Note(stringResource(R.string.association_none)) }
                    if (clubs.any { ClubRoles.normalize(it.role) != ClubRoles.ADMIN }) {
                        item { Note(stringResource(R.string.association_view_only_note)) }
                    }
                    items(clubs, key = { it.membershipId }) { club ->
                        InnerCard(onClick = { onOpenPage(SettingsPage.Club, club.organizationId) }, shape = RoundedCornerShape(18.dp)) {
                            Row(Modifier.padding(horizontal = 16.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f)) {
                                    Text(club.name, style = MaterialTheme.typography.titleMedium)
                                    if (club.membershipId == session.activeContext.membershipId) {
                                        Text(stringResource(R.string.association_active), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    }
                                }
                                Text(
                                    roleName(club.role),
                                    style = MaterialTheme.typography.labelLarge,
                                    color = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier
                                        .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.1f), RoundedCornerShape(50))
                                        .padding(horizontal = 12.dp, vertical = 6.dp),
                                )
                                Icon(painterResource(R.drawable.ic_chevron_right), contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                            }
                        }
                    }
                }
                SettingsPage.Club -> item(key = "club-${target.organizationId}") {
                    ClubPage(target, onOpenPage = { p, org -> onOpenPage(p, org) })
                }
                SettingsPage.RacketSports, SettingsPage.GameSettings -> clubPage(page, target, canUseStrokeLetHelp = session.canUseStrokeLetHelp())
                SettingsPage.About -> {
                    item { InfoRow(stringResource(R.string.settings_version), AppEnvironment.versionName) }
                    item { InfoRow(stringResource(R.string.settings_environment), AppEnvironment.environmentName) }
                }
                SettingsPage.Organisation, SettingsPage.Users, SettingsPage.Courts -> clubPage(page, target, session.username)
            }
        }
    }
}


/**
 * Pages backed by the organisation's settings. Club admins can change everything; a
 * Personal owner changes their own sports and timer defaults; other club members only
 * see Game Settings, read-only, as on iOS.
 */
private fun LazyListScope.clubPage(
    page: SettingsPage,
    club: AccountContext,
    signedInUsername: String = "",
    canUseStrokeLetHelp: Boolean = false,
) {
    val isAdmin = club.type == AccountContextType.Club && ClubRoles.normalize(club.role) == ClubRoles.ADMIN
    val isPersonal = club.type == AccountContextType.Personal
    val readOnlyGameSettings = page == SettingsPage.GameSettings && !isAdmin && !isPersonal
    if (page.clubAdminOnly && !isAdmin) {
        item { Note(stringResource(R.string.settings_admin_only)) }
        return
    }
    item(key = "club-${club.organizationId}-${page.route}") {
        val organizationId = club.organizationId
        val viewModel: OrganizationSettingsViewModel = viewModel(
            key = "org-settings-$organizationId",
            factory = OrganizationSettingsViewModel.factory(organizationId),
        )
        val ui by viewModel.uiState.collectAsStateWithLifecycle()
        val settings = ui.settings
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            ui.errorMessage?.let { ErrorBanner(it, onRetry = viewModel::load) }
            if (ui.isLoading && settings == null) CircularProgressIndicator()
            if (settings != null) {
                when (page) {
                    SettingsPage.Organisation -> {
                        OrganisationEditor(ui, viewModel)
                        InfoRow(stringResource(R.string.settings_plan), planDisplayName(settings.organization.plan, isPersonal = false))
                    }
                    // Club Settings: racket sports and automatic match timing.
                    SettingsPage.RacketSports -> {
                        StatusLine(ui.notice, ui.actionError)
                        SportsEditor(ui, viewModel, canEdit = true, body = stringResource(R.string.settings_sports_club_body))
                        TimerDefaultsEditor(ui, viewModel, canEdit = true)
                    }
                    SettingsPage.GameSettings -> {
                        StatusLine(ui.notice, ui.actionError)
                        if (isPersonal) {
                            SportsEditor(
                                ui,
                                viewModel,
                                canEdit = true,
                                body = stringResource(R.string.settings_sports_personal_body),
                                title = stringResource(R.string.settings_personal_sports),
                            )
                        }
                        TimerDefaultsEditor(ui, viewModel, canEdit = !readOnlyGameSettings)
                        EditorCard { StrokeLetHelpSetting(allowed = canUseStrokeLetHelp) }
                    }
                    SettingsPage.Users -> UsersEditor(ui, viewModel, signedInUsername)
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

/** The player's name from any membership (full name, else first + surname), else the username. */
internal fun personName(session: SessionState.SignedIn): String {
    val named = session.memberships.firstNotNullOfOrNull { m ->
        m.fullName?.trim()?.takeIf { it.isNotEmpty() }
            ?: listOfNotNull(m.firstName, m.surname).map(String::trim).filter(String::isNotEmpty).joinToString(" ").takeIf { it.isNotEmpty() }
    }
    return named ?: session.displayName.takeIf { it.isNotBlank() && !it.contains('@') } ?: session.username
}
