package com.hitnscore.mobile.feature.watch

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.LifecycleStartEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.components.ErrorBanner
import com.hitnscore.mobile.core.designsystem.components.InnerCard
import com.hitnscore.mobile.core.designsystem.components.OfflineState
import com.hitnscore.mobile.core.designsystem.components.SectionCard
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.core.designsystem.theme.ScoreTextStyles
import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchFormatting
import com.hitnscore.mobile.feature.matches.InformationCard
import com.hitnscore.mobile.feature.matches.TimelineCard

object WatchMatchTags {
    const val SCREEN = "watch_match_screen"
    const val SAVE = "watch_match_save"
}

/**
 * Score Stream viewer, as iOS `RemoteMatchWatchView`: the live score, refreshed every few
 * seconds while visible, the full point timeline, and Add to Viewed Matches.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WatchMatchScreen(
    code: String,
    organizationId: Int,
    isOnline: Boolean,
    onBack: () -> Unit,
    onSaved: () -> Unit,
    viewModel: WatchMatchViewModel = viewModel(
        key = "watch-$organizationId-$code",
        factory = WatchMatchViewModel.factory(code, organizationId),
    ),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    // Follow only while on screen (and online); the last score stays when it stops.
    LifecycleStartEffect(viewModel, isOnline) {
        if (isOnline) viewModel.startFollowing()
        onStopOrDispose { viewModel.stopFollowing() }
    }
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(if (state.isFinished) R.string.watch_title_finished else R.string.watch_title_live)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(painterResource(R.drawable.ic_arrow_back), contentDescription = stringResource(R.string.back))
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background),
            )
        },
        modifier = Modifier.testTag(WatchMatchTags.SCREEN),
    ) { padding ->
        val watch = state.watch
        val match = watch?.match
        val timeline = state.timeline
        LazyColumn(
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = padding.calculateTopPadding() + 4.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            if (!isOnline) {
                item { OfflineState(stringResource(if (match == null) R.string.watch_offline else R.string.watch_offline_paused)) }
            }
            if (state.isLoading && match == null && isOnline) {
                item {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.5.dp)
                        Spacer(Modifier.width(12.dp))
                        Text(stringResource(R.string.watch_opening))
                    }
                }
            }
            state.errorMessage?.let { message -> item { ErrorBanner(message, onRetry = viewModel::retry) } }
            if (watch != null && match != null) {
                item { StatusCard(state, onSave = { viewModel.save(onSaved) }) }
                item { LiveScoreCard(match, finished = state.isFinished) }
                item { InformationCard(match, timeline?.isTennisStyle == true) }
                if (timeline != null) item { TimelineCard(match, timeline) }
            }
        }
    }
}

@Composable
private fun StatusCard(state: WatchMatchUiState, onSave: () -> Unit) {
    val watch = state.watch ?: return
    val live = !state.isFinished
    SectionCard(title = MatchFormatting.sportName(watch.match.sport)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .size(10.dp)
                    .background(if (live) HitNScoreTheme.colors.activeStatus else MaterialTheme.colorScheme.primary, CircleShape),
            )
            Spacer(Modifier.width(8.dp))
            Text(
                stringResource(if (live) R.string.watch_updating else R.string.watch_finished),
                style = MaterialTheme.typography.titleSmall,
                color = if (live) HitNScoreTheme.colors.activeStatus else MaterialTheme.colorScheme.primary,
                modifier = Modifier.weight(1f),
            )
            Text(
                stringResource(R.string.watch_code_label, watch.code.ifBlank { state.code }),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (watch.saved) {
            Text(stringResource(R.string.watch_saved), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
        } else {
            Button(
                onClick = onSave,
                enabled = !state.isSaving,
                modifier = Modifier.fillMaxWidth().testTag(WatchMatchTags.SAVE),
            ) { Text(stringResource(if (state.isSaving) R.string.watch_saving else R.string.watch_save)) }
        }
    }
}

/** Points (or 15/30/40 for tennis) large, with games, and sets for tennis/Padel. */
@Composable
private fun LiveScoreCard(match: MatchDetail, finished: Boolean) {
    val live = match.state
    val tennis = MatchFormatting.isTennisStyle(match.sport, live)
    Surface(
        shape = RoundedCornerShape(28.dp),
        color = HitNScoreTheme.colors.card,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)),
        modifier = Modifier
            .fillMaxWidth()
            // TalkBack reads score changes as they arrive.
            .semantics { liveRegion = LiveRegionMode.Polite },
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            ScoreColumn(
                name = MatchFormatting.fullName(match.player1Name, match.player1Surname),
                big = if (finished) "${live?.player1GamesWon ?: 0}" else live?.player1ScoreLabel ?: "${live?.player1Score ?: 0}",
                small = summaryLine(tennis, live?.player1GamesWon ?: 0, live?.player1SetGames ?: 0),
                modifier = Modifier.weight(1f),
            )
            Text("–", style = MaterialTheme.typography.headlineMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            ScoreColumn(
                name = MatchFormatting.fullName(match.player2Name, match.player2Surname),
                big = if (finished) "${live?.player2GamesWon ?: 0}" else live?.player2ScoreLabel ?: "${live?.player2Score ?: 0}",
                small = summaryLine(tennis, live?.player2GamesWon ?: 0, live?.player2SetGames ?: 0),
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun summaryLine(tennis: Boolean, won: Int, setGames: Int): String =
    if (tennis) {
        stringResource(R.string.watch_sets_games, won, setGames)
    } else {
        pluralStringResource(R.plurals.watch_games, won, won)
    }

@Composable
private fun ScoreColumn(name: String, big: String, small: String, modifier: Modifier = Modifier) {
    InnerCard(modifier = modifier, shape = RoundedCornerShape(18.dp)) {
        Column(
            Modifier.fillMaxWidth().padding(vertical = 14.dp, horizontal = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(name, style = MaterialTheme.typography.titleSmall, textAlign = TextAlign.Center, maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(big, style = ScoreTextStyles.Medium.copy(fontSize = 52.sp), color = MaterialTheme.colorScheme.primary, maxLines = 1)
            Text(small, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
