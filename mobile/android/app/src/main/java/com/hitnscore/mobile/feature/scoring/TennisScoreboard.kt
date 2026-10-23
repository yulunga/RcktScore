package com.hitnscore.mobile.feature.scoring

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.core.designsystem.theme.ScoreTextStyles
import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchState

private const val TENNIS_SWIPE_UNDO_PX = 120f

/** Tennis/Padel scoreboard, as iOS `TennisScoringPresentation`. */
@Composable
fun TennisScoreboard(
    match: MatchDetail,
    state: ScoringUiState,
    onScore: (String) -> Unit,
    onSwipeUndo: () -> Unit,
    onChooseReceiver: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val live = match.state ?: MatchState()
    val ball = if (TennisRules.isPadel(match)) R.drawable.sport_ball_padel else R.drawable.sport_ball_tennis
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(28.dp),
        color = HitNScoreTheme.colors.card,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)),
    ) {
        Column(Modifier.padding(vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            FormatBanner(live)
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.Top,
            ) {
                TennisScoreCard(
                    name = TennisRules.scoreDisplayName(match, "player1"),
                    point = live.player1ScoreLabel ?: live.player1Score.toString(),
                    games = live.player1SetGames,
                    sets = live.player1GamesWon,
                    shirt = ShirtColors.of(live.player1ShirtColor ?: match.player1ShirtColor ?: "navy"),
                    serving = live.currentServerSide == "player1",
                    ball = ball,
                    enabled = state.canScore,
                    onTap = { onScore("player1") },
                    onSwipeDown = onSwipeUndo,
                    modifier = Modifier.weight(1f),
                )
                Column(
                    Modifier.widthIn(min = 58.dp).padding(top = 46.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        stringResource(
                            when {
                                live.isMatchTiebreak -> R.string.tennis_match_tiebreak_label
                                live.isTieBreak -> R.string.tennis_tiebreak_label
                                else -> R.string.tennis_points_label
                            },
                        ),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Image(painterResource(ball), contentDescription = null, modifier = Modifier.size(30.dp))
                    Text(stringResource(R.string.set_n, live.currentGameNumber), style = MaterialTheme.typography.labelMedium)
                }
                TennisScoreCard(
                    name = TennisRules.scoreDisplayName(match, "player2"),
                    point = live.player2ScoreLabel ?: live.player2Score.toString(),
                    games = live.player2SetGames,
                    sets = live.player2GamesWon,
                    shirt = ShirtColors.of(live.player2ShirtColor ?: match.player2ShirtColor ?: "white"),
                    serving = live.currentServerSide == "player2",
                    ball = ball,
                    enabled = state.canScore,
                    onTap = { onScore("player2") },
                    onSwipeDown = onSwipeUndo,
                    modifier = Modifier.weight(1f),
                )
            }
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                val notSet = stringResource(R.string.not_set)
                Text(
                    stringResource(R.string.tennis_serving, live.currentServer ?: notSet),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.weight(1f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    stringResource(R.string.tennis_receiving, live.currentReceiver ?: notSet),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            AnimatedVisibility(state.requiresReceiverChoice) {
                GoldenPointReceiverChoice(live, enabled = state.canPlay, onChoose = onChooseReceiver)
            }
            if (state.tennisPoints.isNotEmpty()) {
                PointTimeline(state.tennisPoints, Modifier.weight(1f))
            } else {
                Spacer(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun FormatBanner(live: MatchState) {
    val description = if (live.isMatchTiebreak) {
        stringResource(R.string.tennis_format_match_tiebreak)
    } else {
        buildString {
            append(stringResource(R.string.tennis_format, live.bestOf))
            if (live.tennisNoAdScoring) append(" • ").append(stringResource(R.string.setup_golden_point))
            if (live.tennisTimedBreaks) append(" • ").append(stringResource(R.string.tennis_timed_breaks_short))
        }
    }
    Row(
        Modifier
            .padding(horizontal = 8.dp)
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f), RoundedCornerShape(24.dp))
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(9.dp).background(HitNScoreTheme.colors.activeStatus, CircleShape))
        Spacer(Modifier.width(8.dp))
        Text(description, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary, maxLines = 2)
    }
}

/** Tap to score; swipe down to undo, as the squash panels. */
@Composable
private fun TennisScoreCard(
    name: String,
    point: String,
    games: Int,
    sets: Int,
    shirt: ShirtColor,
    serving: Boolean,
    ball: Int,
    enabled: Boolean,
    onTap: () -> Unit,
    onSwipeDown: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val description = stringResource(R.string.tennis_card_description, name, point, games, sets)
    var dragged by remember { mutableStateOf(0f) }
    val shape = RoundedCornerShape(24.dp)
    Column(
        modifier
            .heightIn(min = 196.dp)
            .background(shirt.fill, shape)
            .then(if (shirt.isLight) Modifier.border(1.5.dp, Color.Black.copy(alpha = 0.18f), shape) else Modifier)
            .pointerInput(Unit) {
                detectVerticalDragGestures(
                    onDragStart = { dragged = 0f },
                    onDragEnd = { if (dragged > TENNIS_SWIPE_UNDO_PX) onSwipeDown() },
                    onVerticalDrag = { _, amount -> dragged += amount },
                )
            }
            .clickable(enabled = enabled, role = Role.Button, onClick = onTap)
            .semantics(mergeDescendants = true) { contentDescription = description }
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
            Text(
                name,
                style = MaterialTheme.typography.titleMedium,
                color = shirt.onFill,
                textAlign = TextAlign.Center,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f, fill = false),
            )
            if (serving) {
                Spacer(Modifier.width(6.dp))
                Image(painterResource(ball), contentDescription = stringResource(R.string.serving), modifier = Modifier.size(18.dp))
            }
        }
        Box(
            Modifier
                .fillMaxWidth()
                .heightIn(min = 72.dp)
                .background(if (shirt.isLight) Color.Black.copy(alpha = 0.06f) else Color.White.copy(alpha = 0.17f), RoundedCornerShape(18.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Text(point, style = ScoreTextStyles.Large.copy(fontSize = 46.sp, lineHeight = 50.sp), color = shirt.onFill, maxLines = 1)
        }
        Row(Modifier.fillMaxWidth().height(42.dp), verticalAlignment = Alignment.CenterVertically) {
            Stat(stringResource(R.string.tennis_games), games, shirt, Modifier.weight(1f))
            Box(Modifier.width(1.dp).height(30.dp).background(shirt.onFill.copy(alpha = 0.35f)))
            Stat(stringResource(R.string.tennis_sets), sets, shirt, Modifier.weight(1f))
        }
    }
}

@Composable
private fun Stat(label: String, value: Int, shirt: ShirtColor, modifier: Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value.toString(), style = ScoreTextStyles.Small.copy(fontSize = 18.sp), color = shirt.onFill)
        Text(label, style = MaterialTheme.typography.labelSmall, color = shirt.onFill)
    }
}

@Composable
private fun PointTimeline(points: List<TennisPoint>, modifier: Modifier = Modifier) {
    val listState = rememberLazyListState()
    LaunchedEffect(points.size) {
        if (points.isNotEmpty()) listState.animateScrollToItem(points.lastIndex)
    }
    Column(
        modifier
            .padding(horizontal = 10.dp)
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f), RoundedCornerShape(16.dp))
            .padding(10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(stringResource(R.string.tennis_point_timeline), style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurfaceVariant)
        LazyColumn(state = listState, verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(top = 6.dp)) {
            items(points, key = { it.id }) { point ->
                Column {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterHorizontally)) {
                        Box(Modifier.width(70.dp), contentAlignment = Alignment.CenterEnd) {
                            if (point.scorer == "player1") Marker(point)
                        }
                        Box(Modifier.width(70.dp), contentAlignment = Alignment.CenterStart) {
                            if (point.scorer == "player2") Marker(point)
                        }
                    }
                    point.gameScore?.let { GameDivider(it) }
                }
            }
        }
    }
}

@Composable
private fun Marker(point: TennisPoint) {
    val color = if (point.isGame) HitNScoreTheme.colors.gameScore else HitNScoreTheme.colors.brandPink
    Box(
        Modifier.size(width = 48.dp, height = 28.dp).background(color.copy(alpha = 0.16f), RoundedCornerShape(50)),
        contentAlignment = Alignment.Center,
    ) {
        Text(point.label, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = if (point.isGame) MaterialTheme.colorScheme.onSurface else color)
    }
}

@Composable
private fun GameDivider(score: String) {
    val blue = MaterialTheme.colorScheme.primary
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.weight(1f).height(2.dp).background(blue.copy(alpha = 0.7f)))
        Text(score, style = ScoreTextStyles.Small.copy(fontSize = 15.sp), color = blue, modifier = Modifier.padding(horizontal = 8.dp))
        Box(Modifier.weight(1f).height(2.dp).background(blue.copy(alpha = 0.7f)))
    }
}

@Composable
private fun GoldenPointReceiverChoice(live: MatchState, enabled: Boolean, onChoose: (String) -> Unit) {
    Surface(
        shape = RoundedCornerShape(18.dp),
        color = HitNScoreTheme.colors.activeStatus.copy(alpha = 0.14f),
        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp),
    ) {
        Column(Modifier.padding(14.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(stringResource(R.string.golden_point_receiver), style = MaterialTheme.typography.titleMedium)
            Text(
                stringResource(R.string.golden_point_receiver_body),
                style = MaterialTheme.typography.bodySmall,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                TennisRules.goldenPointReceivers(live).forEach { receiver ->
                    Button(
                        onClick = { onChoose(TennisRules.receiverCourt(live, receiver)) },
                        enabled = enabled,
                        shape = RoundedCornerShape(50),
                        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary),
                        modifier = Modifier.weight(1f),
                    ) { Text(receiver.displayName, maxLines = 1, overflow = TextOverflow.Ellipsis) }
                }
            }
        }
    }
}
