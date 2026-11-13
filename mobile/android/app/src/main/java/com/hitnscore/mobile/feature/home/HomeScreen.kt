package com.hitnscore.mobile.feature.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.components.CardGrid
import com.hitnscore.mobile.core.designsystem.components.EmptyState
import com.hitnscore.mobile.core.designsystem.components.ErrorBanner
import com.hitnscore.mobile.core.designsystem.components.OfflineState
import com.hitnscore.mobile.core.designsystem.components.SectionCard
import com.hitnscore.mobile.core.designsystem.components.SkeletonRows
import com.hitnscore.mobile.core.session.AccountContextType
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.data.model.MatchSummary
import com.hitnscore.mobile.feature.matches.ActiveMatchCard
import com.hitnscore.mobile.feature.matches.LockedHistoryCard
import com.hitnscore.mobile.feature.matches.RecentMatchCard
import com.hitnscore.mobile.feature.matches.ScheduledMatchCard
import com.hitnscore.mobile.feature.scoring.offline.OfflineOwner
import com.hitnscore.mobile.feature.scoring.offline.toSummary
import com.hitnscore.mobile.feature.shell.MatchesCategory
import com.hitnscore.mobile.feature.shell.ShellActions
import com.hitnscore.mobile.feature.shell.ShellHeader
import com.hitnscore.mobile.feature.shell.ShellUiState

private const val HOME_ITEMS = 3

/** Home: up to three active, scheduled and readable recent matches, plus any locked-history prompt. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(session: SessionState.SignedIn, state: ShellUiState, actions: ShellActions) {
    val dashboard = state.dashboard
    val isClub = session.activeContext.type == AccountContextType.Club
    // Matches held on the phone, so scoring can carry on without a connection (M5).
    val context = LocalContext.current
    val offlineStore = remember(context) { (context.applicationContext as HitNScoreApplication).container.offlineMatchStore }
    val held by offlineStore.snapshots.collectAsStateWithLifecycle()
    val offlineMatches = remember(held, session.username, session.activeContext.organizationId) {
        offlineStore.cachedActiveMatches(OfflineOwner(session.username, session.activeContext.organizationId)).map { it.toSummary() }
    }

    PullToRefreshBox(
        isRefreshing = state.isRefreshing,
        onRefresh = actions.onRefresh,
        modifier = Modifier.fillMaxSize(),
    ) {
        LazyColumn(
            // Bottom breathing room above the persistent navigation bar.
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 96.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            item(key = "header") {
                ShellHeader(
                    session = session,
                    isOnline = state.isOnline,
                    hasUnreadNotifications = state.hasUnreadNotifications,
                    onOpenNotifications = actions.onOpenNotifications,
                    onContextSelected = actions.onContextSelected,
                    onSignOut = actions.onSignOut,
                )
            }
            state.errorMessage?.let { message ->
                item(key = "error") { ErrorBanner(message, onRetry = actions.onRefresh) }
            }
            if (!state.isOnline && offlineMatches.isNotEmpty()) {
                item(key = "offline") {
                    SectionCard(title = stringResource(R.string.section_continue_offline), iconRes = R.drawable.ic_wifi_off) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            offlineMatches.forEach { match -> ActiveMatchCard(match) { actions.onOpenMatch(match) } }
                        }
                    }
                }
            }
            item(key = "active") {
                SectionCard(
                    title = stringResource(R.string.section_active_matches),
                    iconRes = R.drawable.ic_live_stream,
                    onTitleClick = { actions.onShowMatches(MatchesCategory.Current) },
                ) {
                    MatchSection(
                        matches = dashboard?.activeMatches.orEmpty().take(HOME_ITEMS),
                        isLoading = state.isLoading,
                        emptyText = stringResource(R.string.empty_active),
                    ) { ActiveMatchCard(it) { actions.onOpenMatch(it) } }
                }
            }
            if (isClub) {
                item(key = "scheduled") {
                    SectionCard(
                        title = stringResource(R.string.section_scheduled_matches),
                        iconRes = R.drawable.ic_calendar_clock,
                        onTitleClick = { actions.onShowMatches(MatchesCategory.Scheduled) },
                    ) {
                        MatchSection(
                            matches = dashboard?.scheduledMatches.orEmpty().take(HOME_ITEMS),
                            isLoading = state.isLoading,
                            emptyText = stringResource(R.string.empty_scheduled),
                        ) { ScheduledMatchCard(it) }
                    }
                }
            }
            item(key = "recent") {
                SectionCard(
                    title = stringResource(R.string.section_recent_matches),
                    iconRes = R.drawable.ic_date_range,
                    onTitleClick = { actions.onShowMatches(MatchesCategory.History) },
                ) {
                    if (!state.isOnline) {
                        OfflineState(stringResource(R.string.offline_history))
                    } else {
                        MatchSection(
                            matches = homeRecentMatches(dashboard?.recentMatches.orEmpty()),
                            isLoading = state.isLoading,
                            emptyText = stringResource(R.string.empty_recent),
                        ) { match ->
                            if (match.locked) {
                                LockedHistoryCard(onViewPlan = actions.onOpenSubscription)
                            } else {
                                RecentMatchCard(match) { actions.onOpenMatch(match) }
                            }
                        }
                    }
                }
            }
        }
    }
}

internal fun homeRecentMatches(matches: List<MatchSummary>): List<MatchSummary> =
    matches.filterNot { it.locked }.take(HOME_ITEMS) + matches.firstOrNull { it.locked }.let(::listOfNotNull)

@Composable
fun MatchSection(
    matches: List<MatchSummary>,
    isLoading: Boolean,
    emptyText: String,
    row: @Composable (MatchSummary) -> Unit,
) {
    when {
        isLoading && matches.isEmpty() -> SkeletonRows()
        matches.isEmpty() -> EmptyState(emptyText)
        // Two cards per row on tablets.
        else -> CardGrid(matches) { row(it) }
    }
}
