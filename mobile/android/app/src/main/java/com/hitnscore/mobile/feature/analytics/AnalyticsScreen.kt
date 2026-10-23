package com.hitnscore.mobile.feature.analytics

import androidx.compose.foundation.layout.Arrangement
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

/** Analytics tab: Personal Plus performance report, or basic stats from available history. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AnalyticsScreen(session: SessionState.SignedIn, state: ShellUiState, isPersonalPlus: Boolean, actions: ShellActions) {
    var showPersonal by rememberSaveable { mutableStateOf(true) }
    val personalView = isPersonalPlus && showPersonal
    val performance = state.dashboard?.performance
    val recent = state.dashboard?.recentMatches.orEmpty()
    val isPersonalAccount = session.activeContext.type == AccountContextType.Personal

    PullToRefreshBox(isRefreshing = state.isRefreshing, onRefresh = actions.onRefresh, modifier = Modifier.fillMaxSize()) {
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
            if (isPersonalPlus) {
                item {
                    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                        SegmentedButton(
                            selected = showPersonal,
                            onClick = { showPersonal = true },
                            shape = SegmentedButtonDefaults.itemShape(0, 2),
                        ) { Text(stringResource(R.string.analytics_personal)) }
                        SegmentedButton(
                            selected = !showPersonal,
                            onClick = { showPersonal = false },
                            shape = SegmentedButtonDefaults.itemShape(1, 2),
                        ) { Text(stringResource(R.string.analytics_stats)) }
                    }
                }
            }
            item {
                SectionCard(
                    title = stringResource(if (personalView) R.string.analytics_personal_title else R.string.analytics_stats),
                    iconRes = R.drawable.ic_tab_analytics,
                    subtitle = stringResource(if (personalView) R.string.analytics_personal_subtitle else R.string.analytics_stats_subtitle),
                ) {
                    when {
                        state.isLoading && state.dashboard == null -> SkeletonRows(2, height = 112)
                        personalView && performance == null -> EmptyState(stringResource(R.string.analytics_no_data))
                        personalView && performance != null -> PersonalReport(performance)
                        else -> BasicStats(recent, state.dashboard?.organization?.completedMatchCount)
                    }
                    if (!isPersonalPlus && isPersonalAccount) {
                        Text(
                            stringResource(R.string.analytics_free_note),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
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
