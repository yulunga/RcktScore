package com.hitnscore.mobile.feature.analytics

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.draw.clip
import androidx.compose.material3.Surface
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.background
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.animateDpAsState
import com.hitnscore.mobile.data.model.AppAnalytics
import androidx.compose.ui.res.painterResource
import androidx.compose.material3.TextButton
import androidx.compose.material3.Icon
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.DropdownMenu
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.components.EmptyState
import com.hitnscore.mobile.core.designsystem.components.InnerCard
import com.hitnscore.mobile.core.designsystem.components.SectionCard
import com.hitnscore.mobile.core.designsystem.components.SkeletonRows
import com.hitnscore.mobile.core.session.AccountContextType
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.data.model.MatchFormatting
import com.hitnscore.mobile.data.model.MatchSummary
import com.hitnscore.mobile.data.model.PersonalPerformance
import com.hitnscore.mobile.feature.shell.ShellActions
import com.hitnscore.mobile.feature.shell.ShellHeader
import com.hitnscore.mobile.feature.shell.ShellUiState

private data class Stat(val title: String, val value: String, val detail: String)

/**
 * Analytics tab. A Personal / Club switch (as iOS) when the user has both kinds of account:
 * Personal Analytics shows the Personal Plus performance report (or basic stats on Personal
 * Free); Club Analytics shows the club's match summary. The other account's figures are
 * fetched without changing the active account.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AnalyticsScreen(
    session: SessionState.SignedIn,
    state: ShellUiState,
    isPersonalPlus: Boolean,
    actions: ShellActions,
    analyticsViewModel: AnalyticsViewModel = viewModel(factory = AnalyticsViewModel.Factory),
) {
    val extra by analyticsViewModel.uiState.collectAsStateWithLifecycle()
    val active = session.activeContext
    val personalContext = session.availableContexts.firstOrNull { it.type == AccountContextType.Personal }
    // The active club, or the first club when a Personal account is active.
    val clubContext = active.takeIf { it.type == AccountContextType.Club }
        ?: session.availableContexts.firstOrNull { it.type == AccountContextType.Club }
    val hasBoth = personalContext != null && clubContext != null
    var showPersonal by rememberSaveable(active.organizationId) { mutableStateOf(active.type == AccountContextType.Personal) }
    if (personalContext == null) showPersonal = false
    if (clubContext == null) showPersonal = true

    val target = if (showPersonal) personalContext else clubContext
    val targetId = target?.organizationId
    val isActiveTarget = targetId == active.organizationId
    LaunchedEffect(targetId, isActiveTarget, state.isOnline) {
        if (targetId != null && !isActiveTarget && state.isOnline) analyticsViewModel.load(targetId)
    }
    val dashboard = if (isActiveTarget) state.dashboard else targetId?.let { extra.dashboards[it] }
    val loading = if (isActiveTarget) state.isLoading && state.dashboard == null else targetId != null && targetId in extra.loading
    val loadError = if (isActiveTarget) null else targetId?.let { extra.errors[it] }

    val plus = isPersonalPlus || personalContext?.plan == "Personal Plus"
    val personalId = personalContext?.organizationId
    LaunchedEffect(personalId, extra.periodDays, showPersonal, state.isOnline) {
        if (showPersonal && personalId != null && state.isOnline) analyticsViewModel.loadAppUsage(personalId)
    }
    val usageKey = personalId?.let { it to extra.periodDays }
    val appUsage = usageKey?.let { extra.appUsage[it] }
    val usageLoading = usageKey != null && usageKey in extra.appUsageLoading
    val performance = dashboard?.performance
    val recent = dashboard?.recentMatches.orEmpty()

    PullToRefreshBox(
        isRefreshing = state.isRefreshing,
        onRefresh = {
            actions.onRefresh()
            if (targetId != null && !isActiveTarget) analyticsViewModel.load(targetId, force = true)
            if (showPersonal && personalId != null) analyticsViewModel.loadAppUsage(personalId, force = true)
        },
        modifier = Modifier.fillMaxSize(),
    ) {
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
            if (hasBoth) {
                item {
                    SegmentedSwitch(
                        options = listOf(stringResource(R.string.analytics_personal), stringResource(R.string.analytics_club)),
                        selectedIndex = if (showPersonal) 0 else 1,
                        onSelect = { showPersonal = it == 0 },
                    )
                }
            }
            item {
                SectionCard(
                    title = stringResource(if (showPersonal) R.string.analytics_personal_title else R.string.analytics_club_title),
                    iconRes = R.drawable.ic_tab_analytics,
                    subtitle = when {
                        showPersonal -> stringResource(R.string.analytics_personal_subtitle)
                        else -> stringResource(R.string.analytics_club_subtitle, target?.name.orEmpty())
                    },
                ) {
                    if (showPersonal) {
                        // As iOS: reporting period, app usage, then the Personal Plus report.
                        PeriodRow(extra.periodDays, analyticsViewModel::selectPeriod)
                        when {
                            appUsage != null -> AppUsage(appUsage)
                            usageLoading -> SkeletonRows(2, height = 112)
                            else -> AppUsage(AppAnalytics())
                        }
                        if (plus) {
                            when {
                                loadError != null -> Text(loadError, color = MaterialTheme.colorScheme.error)
                                loading -> SkeletonRows(2, height = 112)
                                performance == null -> EmptyState(stringResource(R.string.analytics_no_data))
                                else -> PersonalReport(performance)
                            }
                        } else {
                            Text(
                                stringResource(R.string.analytics_free_note),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            PerformanceUpgradeCard(onUpgrade = actions.onOpenSubscription)
                        }
                    } else {
                        when {
                            loadError != null -> Text(loadError, color = MaterialTheme.colorScheme.error)
                            loading -> SkeletonRows(2, height = 112)
                            else -> BasicStats(recent, dashboard?.organization?.completedMatchCount)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PersonalReport(p: PersonalPerformance) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        StatGrid(
            listOf(
                Stat("Matches won", "${p.matchesWon}", "${MatchFormatting.percentage(p.winPercentage)} win rate"),
                Stat("Playing time", MatchFormatting.duration(p.playingTimeSeconds), "${p.matchesPlayed} matches"),
                Stat("Games won", "${p.gamesWon}", "${MatchFormatting.percentage(p.gameWinPercentage)} win rate"),
                Stat("Points won", "${p.pointsWon}", "${MatchFormatting.percentage(p.pointWinPercentage)} win rate"),
                Stat("Close games / sets", "${p.closeGamesWon}/${p.closeGamesPlayed}", MatchFormatting.percentage(p.closeGameWinPercentage)),
                Stat("Points won on serve", "${p.servicePointsWon}", "${MatchFormatting.percentage(p.servicePointWinPercentage)} of serve points"),
                Stat("Current streak", "${p.currentWinStreak}", "Best: ${p.bestWinStreak}"),
                Stat("Points lost on serve", "${p.servicePointsLost}", "From recorded actions"),
            ),
        )
        Group("Progress summaries") {
            Line("This week", "${p.weeklySummary.matchesWon}-${p.weeklySummary.matchesLost}",
                "${p.weeklySummary.matchesPlayed} matches · ${MatchFormatting.duration(p.weeklySummary.playingTimeSeconds)} · ${MatchFormatting.percentage(p.weeklySummary.winPercentage)}")
            HorizontalDivider()
            Line("This month", "${p.monthlySummary.matchesWon}-${p.monthlySummary.matchesLost}",
                "${p.monthlySummary.matchesPlayed} matches · ${MatchFormatting.duration(p.monthlySummary.playingTimeSeconds)} · ${MatchFormatting.percentage(p.monthlySummary.winPercentage)}")
        }
        if (p.monthlyImprovement.isNotEmpty()) {
            Group("Monthly improvement") {
                p.monthlyImprovement.forEach {
                    Line(MatchFormatting.sportName(it.sport), it.percentagePointChange?.let { c -> "%+.1f pts".format(c) } ?: "Not enough data", "${it.currentMonthMatches} this month")
                }
            }
        }
        if (p.sports.isNotEmpty()) {
            Group("By sport") {
                p.sports.forEach {
                    Line(MatchFormatting.sportName(it.sport), "${it.won}-${it.lost}", "${MatchFormatting.percentage(it.winPercentage)} · ${MatchFormatting.duration(it.playingTimeSeconds)}")
                }
            }
        }
        if (p.opponents.isNotEmpty()) {
            Group("Opponents") {
                p.opponents.forEach { Line(it.name, "${it.won}-${it.lost}", "${MatchFormatting.percentage(it.winPercentage)} win rate") }
            }
        }
        if (p.scorelineWins.isNotEmpty()) {
            Group("Winning scorelines") {
                p.scorelineWins.forEach { Line(it.scoreline, "${it.count}", if (it.count == 1) "win" else "wins") }
            }
        }
        if (p.unclassifiedMatchCount > 0) {
            Text(
                stringResource(R.string.analytics_unclassified, p.unclassifiedMatchCount),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

/** "Reporting period" with a drop-down (7 days … All time), as iOS. */
@Composable
private fun PeriodRow(days: Int, onSelect: (Int) -> Unit) {
    var open by remember { mutableStateOf(false) }
    val label = AnalyticsViewModel.PERIODS.firstOrNull { it.first == days }?.second ?: "$days days"
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(stringResource(R.string.analytics_period), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
        Box {
            TextButton(onClick = { open = true }) {
                Text(label, style = MaterialTheme.typography.titleMedium)
                Icon(painterResource(R.drawable.ic_expand_more), contentDescription = null)
            }
            DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
                AnalyticsViewModel.PERIODS.forEach { (value, text) ->
                    DropdownMenuItem(text = { Text(text) }, onClick = {
                        open = false
                        onSelect(value)
                    })
                }
            }
        }
    }
}

/** Matches scored, completion, duration, active days and match setup (iOS Personal Analytics). */
@Composable
private fun AppUsage(a: AppAnalytics) {
    val setup = a.setupCompletion
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        StatGrid(
            listOf(
                Stat("Matches scored", "${a.matchesScored}", "${a.completedMatches} completed"),
                Stat("Completion rate", MatchFormatting.percentage(a.completedMatchRate), "Recorded matches"),
                Stat("Average duration", a.averageMatchDurationSeconds?.let(MatchFormatting::duration) ?: "—", "Completed matches"),
                Stat("Active days", "${a.activeDays ?: 0}", "${a.returningUsageWeeks ?: 0} active weeks"),
                Stat("Setups started", "${setup?.started ?: 0}", "${setup?.completed ?: 0} completed"),
                Stat("Setup abandonment", MatchFormatting.percentage(setup?.abandonmentRate), "${setup?.abandoned ?: 0} abandoned"),
            ),
        )
        val sports = a.matchesBySport.filter { it.count > 0 }
        if (sports.isNotEmpty()) {
            Group("Scoring by sport") {
                sports.forEachIndexed { index, sport ->
                    Line(MatchFormatting.sportName(sport.sport), "${sport.count}", "matches scored")
                    if (index < sports.size - 1) HorizontalDivider()
                }
            }
        }
    }
}

/**
 * iOS-style segmented control: a white card holding a light grey track, with the chosen
 * option on a white raised pill that slides between options.
 */
@Composable
private fun SegmentedSwitch(options: List<String>, selectedIndex: Int, onSelect: (Int) -> Unit) {
    Surface(
        shape = RoundedCornerShape(18.dp),
        color = HitNScoreTheme.colors.card,
        shadowElevation = 1.dp,
        modifier = Modifier.fillMaxWidth(),
    ) {
        BoxWithConstraints(
            Modifier
                .padding(6.dp)
                .fillMaxWidth()
                .height(40.dp)
                .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.07f), RoundedCornerShape(12.dp))
                .padding(3.dp),
        ) {
            val segment = maxWidth / options.size
            val offset by animateDpAsState(segment * selectedIndex, animationSpec = tween(220), label = "segment")
            Surface(
                shape = RoundedCornerShape(10.dp),
                color = HitNScoreTheme.colors.card,
                shadowElevation = 2.dp,
                modifier = Modifier
                    .offset(x = offset)
                    .width(segment)
                    .fillMaxHeight(),
            ) {}
            Row(Modifier.fillMaxSize()) {
                options.forEachIndexed { index, label ->
                    val selected = index == selectedIndex
                    Box(
                        Modifier
                            .weight(1f)
                            .fillMaxHeight()
                            .clip(RoundedCornerShape(10.dp))
                            .selectable(selected = selected, role = Role.Tab, onClick = { onSelect(index) }),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            label,
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                    }
                }
            }
        }
    }
}

/** Personal Free: what Personal Plus adds, with an Upgrade button to Subscription (as iOS). */
@Composable
private fun PerformanceUpgradeCard(onUpgrade: () -> Unit) {
    InnerCard(shape = RoundedCornerShape(20.dp)) {
        Column(
            Modifier.fillMaxWidth().padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(painterResource(R.drawable.ic_tab_analytics), contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(32.dp))
            Text(
                stringResource(R.string.analytics_upgrade_title),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            Text(
                stringResource(R.string.analytics_upgrade_body),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
            Button(onClick = onUpgrade, shape = RoundedCornerShape(12.dp)) {
                Text(stringResource(R.string.analytics_upgrade_button))
            }
        }
    }
}

@Composable
private fun BasicStats(recent: List<MatchSummary>, completedCount: Int?) {
    val recorded = remember(recent) { recent.filterNot { it.locked } }
    val durations = remember(recorded) { recorded.map { it.matchDurationSeconds ?: it.state?.matchDurationSeconds ?: 0 } }
    val bySport = remember(recorded) { recorded.groupBy { MatchFormatting.sportName(it.sport) }.toSortedMap() }
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        StatGrid(
            listOf(
                Stat("Matches scored", "${completedCount ?: recorded.size}", "Completed matches"),
                Stat("Average duration", if (recorded.isEmpty()) "—" else MatchFormatting.duration(durations.sum() / recorded.size), "Across available history"),
                Stat("Longest match", durations.maxOrNull()?.takeIf { it > 0 }?.let(MatchFormatting::duration) ?: "—", "Across available history"),
                Stat("Sports played", "${bySport.size}", "Different racket sports"),
            ),
        )
        if (bySport.isNotEmpty()) {
            Group("Scoring by sport") {
                bySport.entries.forEachIndexed { index, (sport, matches) ->
                    val total = matches.sumOf { it.matchDurationSeconds ?: it.state?.matchDurationSeconds ?: 0 }
                    Line(sport, "${matches.size}", "Average ${MatchFormatting.duration(total / matches.size)}")
                    if (index < bySport.size - 1) HorizontalDivider()
                }
            }
        }
    }
}

@Composable
private fun StatGrid(stats: List<Stat>) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        stats.chunked(2).forEach { pair ->
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                pair.forEach { stat ->
                    InnerCard(modifier = Modifier.weight(1f), shape = RoundedCornerShape(18.dp)) {
                        Column(Modifier.heightIn(min = 112.dp).padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(stat.title, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(
                                stat.value,
                                style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Black, fontFeatureSettings = "tnum"),
                                color = MaterialTheme.colorScheme.primary,
                                maxLines = 1,
                            )
                            Text(stat.detail, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 2)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun Group(title: String, content: @Composable () -> Unit) {
    InnerCard(shape = RoundedCornerShape(18.dp)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            content()
        }
    }
}

@Composable
private fun Line(title: String, value: String, detail: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.labelLarge)
            Text(detail, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Text(value, style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold), color = MaterialTheme.colorScheme.primary)
    }
}
