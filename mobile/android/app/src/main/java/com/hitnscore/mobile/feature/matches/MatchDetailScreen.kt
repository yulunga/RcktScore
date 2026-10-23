package com.hitnscore.mobile.feature.matches

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.components.ErrorBanner
import com.hitnscore.mobile.core.designsystem.components.InfoRow
import com.hitnscore.mobile.core.designsystem.components.InnerCard
import com.hitnscore.mobile.core.designsystem.components.OfflineState
import com.hitnscore.mobile.core.designsystem.components.SectionCard
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.core.designsystem.theme.ScoreTextStyles
import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchFormatting

private val Slate = Color(0xFF4D6B8B)
private val ServeOrange = Color(0xFFD9822B)

/** Read-only match view, as iOS `HistoricMatchView`. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MatchDetailScreen(
    matchId: String,
    isOnline: Boolean,
    onBack: () -> Unit,
    viewModel: MatchDetailViewModel = viewModel(key = "match-$matchId", factory = MatchDetailViewModel.factory(matchId)),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.historic_match)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(painterResource(R.drawable.ic_arrow_back), contentDescription = stringResource(R.string.back))
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background),
            )
        },
    ) { padding ->
        val match = state.match
        val timeline = state.timeline
        LazyColumn(
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = padding.calculateTopPadding() + 4.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            when {
                !isOnline && match == null -> item { SectionCard(title = stringResource(R.string.historic_match)) { OfflineState(stringResource(R.string.offline_history)) } }
                state.isLoading && match == null -> item {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.5.dp)
                        Spacer(Modifier.width(12.dp))
                        Text(stringResource(R.string.match_loading))
                    }
                }
            }
            state.errorMessage?.let { message -> item { ErrorBanner(message, onRetry = viewModel::load) } }
            if (match != null && timeline != null) {
                if (!match.status.equals("completed", ignoreCase = true)) {
                    item { Text(stringResource(R.string.live_match_note), color = MaterialTheme.colorScheme.onSurfaceVariant) }
                }
                item { SummaryCard(match) }
                item { InformationCard(match, timeline.isTennisStyle) }
                item { TimeCard(timeline) }
                item { TimelineCard(match, timeline) }
            }
        }
    }
}

@Composable
private fun SummaryCard(match: MatchDetail) {
    Surface(
        shape = RoundedCornerShape(28.dp),
        color = HitNScoreTheme.colors.card,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            ScoreRow(MatchFormatting.fullName(match.player1Name, match.player1Surname), match.state?.player1GamesWon ?: 0)
            ScoreRow(MatchFormatting.fullName(match.player2Name, match.player2Surname), match.state?.player2GamesWon ?: 0)
        }
    }
}

@Composable
private fun ScoreRow(name: String, games: Int) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(name, style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f))
        Text("$games", style = ScoreTextStyles.Medium.copy(fontSize = 30.sp), color = MaterialTheme.colorScheme.primary)
    }
}

@Composable
private fun InformationCard(match: MatchDetail, tennis: Boolean) {
    var expanded by rememberSaveable { mutableStateOf(false) }
    Surface(
        shape = RoundedCornerShape(24.dp),
        color = HitNScoreTheme.colors.card,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
      Column(Modifier.padding(if (expanded) 18.dp else 14.dp)) {
        ExpandHeader(stringResource(R.string.match_information), expanded) { expanded = !expanded }
        AnimatedVisibility(expanded) {
            Column(Modifier.padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                val started = match.state?.events?.firstOrNull { it.eventType == "match_started" }?.createdAt ?: match.createdAt
                val startedAt = MatchFormatting.parseInstant(started)
                InfoRow(stringResource(R.string.info_sport), MatchFormatting.sportName(match.sport))
                InfoRow(stringResource(R.string.info_game_details), gameDetails(match, tennis))
                InfoRow(stringResource(R.string.info_date), MatchFormatting.dateOnly(startedAt))
                InfoRow(stringResource(R.string.info_started), MatchFormatting.timeOnly(startedAt))
                InfoRow(stringResource(R.string.info_court), courtName(match))
                InfoRow(stringResource(R.string.info_referee), match.refereeName ?: stringResource(R.string.not_added))
            }
        }
      }
    }
}

@Composable
private fun TimeCard(timeline: MatchTimeline) {
    var expanded by rememberSaveable { mutableStateOf(false) }
    InnerCard {
        Column(Modifier.padding(12.dp)) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { expanded = !expanded },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text(stringResource(R.string.match_time), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(
                        MatchFormatting.clock(timeline.totalDurationSeconds),
                        style = ScoreTextStyles.Small,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
                ExpandIcon(expanded)
            }
            AnimatedVisibility(expanded) {
                // Simple wrapping grid of game/set times, five per row as iOS.
                Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    timeline.games.filter { it.durationSeconds != null }.chunked(5).forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            row.forEach { game ->
                                Surface(shape = RoundedCornerShape(12.dp), color = MaterialTheme.colorScheme.surface, modifier = Modifier.weight(1f)) {
                                    Column(Modifier.padding(vertical = 7.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                        Text(
                                            stringResource(if (timeline.isTennisStyle) R.string.set_n else R.string.game_n, game.gameNumber),
                                            style = MaterialTheme.typography.labelSmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        )
                                        Text(MatchFormatting.clock(game.durationSeconds ?: 0), style = MaterialTheme.typography.labelLarge)
                                    }
                                }
                            }
                            repeat(5 - row.size) { Spacer(Modifier.weight(1f)) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TimelineCard(match: MatchDetail, timeline: MatchTimeline) {
    val player1 = MatchFormatting.fullName(match.player1Name, match.player1Surname)
    val player2 = MatchFormatting.fullName(match.player2Name, match.player2Surname)
    val doublesTeams = match.state?.tennisTeams.takeIf { match.state?.teamFormat.equals("doubles", ignoreCase = true) }
    fun sideName(side: String): String {
        doublesTeams?.get(side)?.takeIf { it.isNotEmpty() }?.let { team -> return team.joinToString(" & ") { it.displayName } }
        return if (side == "player2") player2 else player1
    }

    SectionCard(title = stringResource(R.string.point_timeline)) {
        if (timeline.games.isEmpty()) {
            Text(stringResource(R.string.no_point_history), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        timeline.games.forEachIndexed { index, game ->
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    stringResource(if (timeline.isTennisStyle) R.string.set_n else R.string.game_n, game.gameNumber),
                    style = MaterialTheme.typography.titleSmall,
                )
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(horizontal = 6.dp)) {
                    Text(player1, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(
                        game.result?.let { "${it.player1Score}-${it.player2Score}" }.orEmpty(),
                        style = ScoreTextStyles.Small.copy(fontSize = 16.sp),
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.widthIn(min = 48.dp),
                        textAlign = TextAlign.Center,
                    )
                    Text(player2, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f), textAlign = TextAlign.End, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                game.entries.forEach { entry ->
                    if (timeline.isTennisStyle) {
                        TennisPointRow(sideName(entry.winnerSide), entry)
                        if (entry.tennisGameCompleted) {
                            CompletionBanner(
                                title = stringResource(if (entry.matchCompleted) R.string.banner_match else R.string.banner_game),
                                winner = sideName(entry.winnerSide),
                                score = entry.completedGameScore,
                            )
                        }
                        if (entry.setCompleted && !entry.matchCompleted) {
                            CompletionBanner(
                                title = stringResource(R.string.banner_set),
                                winner = sideName(entry.winnerSide),
                                score = game.result?.let { "${it.player1Score}-${it.player2Score}" },
                            )
                        }
                    } else {
                        RacketPointRow(sideName(entry.winnerSide), entry)
                    }
                }
                if (!timeline.isTennisStyle && game.result != null) {
                    Text(
                        stringResource(R.string.games_score, game.gamesScoreAfter),
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Black),
                        color = MaterialTheme.colorScheme.primary,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f), RoundedCornerShape(9.dp))
                            .padding(vertical = 5.dp),
                    )
                }
            }
            if (index != timeline.games.lastIndex) HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
        }
    }
}

/** Squash/racketball row: score bubble on the winner's rail, serve marker, name and time centred. */
@Composable
private fun RacketPointRow(winnerName: String, entry: TimelineEntry) {
    InnerCard(shape = RoundedCornerShape(10.dp)) {
        Row(Modifier.padding(horizontal = 8.dp, vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.width(58.dp), contentAlignment = Alignment.CenterStart) {
                if (entry.winnerSide == "player1") SideMarkers(entry, MaterialTheme.colorScheme.primary, serveFirst = true)
            }
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(winnerName, style = MaterialTheme.typography.labelLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
                entry.timestamp?.let {
                    Text(MatchFormatting.timeOnly(it), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            Box(Modifier.width(58.dp), contentAlignment = Alignment.CenterEnd) {
                if (entry.winnerSide == "player2") SideMarkers(entry, Slate, serveFirst = false)
            }
        }
    }
}

@Composable
private fun SideMarkers(entry: TimelineEntry, tint: Color, serveFirst: Boolean) {
    val serving = entry.serverSide == entry.winnerSide
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
        if (serveFirst && serving) ServeMarker(entry.serviceSideLabel)
        Box(Modifier.size(28.dp).background(tint, CircleShape), contentAlignment = Alignment.Center) {
            Text(entry.score.orEmpty(), color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold, maxLines = 1)
        }
        if (!serveFirst && serving) ServeMarker(entry.serviceSideLabel)
    }
}

@Composable
private fun ServeMarker(label: String) {
    Box(Modifier.size(18.dp).background(ServeOrange, CircleShape), contentAlignment = Alignment.Center) {
        Text(label, color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun TennisPointRow(winnerName: String, entry: TimelineEntry) {
    InnerCard(shape = RoundedCornerShape(10.dp)) {
        Row(Modifier.padding(horizontal = 8.dp, vertical = 3.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(winnerName, style = MaterialTheme.typography.labelLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
                entry.timestamp?.let {
                    Text(MatchFormatting.timeOnly(it), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            entry.score?.let {
                Text(
                    it,
                    style = ScoreTextStyles.Small.copy(fontSize = 15.sp),
                    color = if (entry.winnerSide == "player2") Slate else MaterialTheme.colorScheme.primary,
                )
            }
        }
    }
}

@Composable
private fun CompletionBanner(title: String, winner: String, score: String?) {
    val red = HitNScoreTheme.colors.completedStatus
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = red.copy(alpha = 0.1f),
        border = BorderStroke(1.dp, red.copy(alpha = 0.35f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(title, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Black), color = red)
            Text(winner, style = MaterialTheme.typography.titleSmall)
            score?.let { Text(it, style = ScoreTextStyles.Small, color = MaterialTheme.colorScheme.primary) }
        }
    }
}

@Composable
private fun ExpandHeader(title: String, expanded: Boolean, onToggle: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onToggle),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
        ExpandIcon(expanded)
    }
}

@Composable
private fun ExpandIcon(expanded: Boolean) {
    Box(Modifier.size(28.dp).background(MaterialTheme.colorScheme.primary, CircleShape), contentAlignment = Alignment.Center) {
        Icon(
            painterResource(if (expanded) R.drawable.ic_expand_less else R.drawable.ic_expand_more),
            contentDescription = stringResource(if (expanded) R.string.collapse else R.string.expand),
            tint = Color.White,
            modifier = Modifier.size(20.dp),
        )
    }
}

private fun gameDetails(match: MatchDetail, tennis: Boolean): String {
    val bestOf = match.state?.bestOf ?: match.bestOf
    if (tennis) {
        val scoring = if (match.state?.tennisNoAdScoring == true) "Golden Point" else "Advantage scoring"
        return "Best of $bestOf sets • $scoring"
    }
    val handicapOn = match.state?.handicap?.enabled ?: match.handicapEnabled
    val handicap = if (handicapOn) {
        "Handicap ${match.state?.handicap?.player1Offset ?: match.player1Offset} | ${match.state?.handicap?.player2Offset ?: match.player2Offset}"
    } else {
        "No handicap"
    }
    return "$handicap • Best of $bestOf • PAR-${match.state?.scoreType ?: match.scoreType}"
}

private fun courtName(match: MatchDetail): String =
    listOfNotNull(match.courtName, match.courtAlias)
        .map { it.trim() }
        .filter { it.isNotEmpty() }
        .distinctBy { it.lowercase() }
        .joinToString(" • ")
