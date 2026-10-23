package com.hitnscore.mobile.feature.scoring

import android.Manifest
import android.app.Activity
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalView
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
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.core.designsystem.theme.ScoreTextStyles
import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchFormatting
import kotlinx.coroutines.launch

private val Slate = Color(0xFF4D6B8B)
private val ServeOrange = Color(0xFFD9822B)
private val RunningGreen = Color(0xFFB9F2C9)
private val Danger = Color(0xFFC4445C)
private const val SWIPE_UNDO_THRESHOLD_PX = 120f

/** Live scorer for all four sports, as iOS `MatchScoringView`. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScoringScreen(
    matchId: String,
    isOnline: Boolean,
    onBack: () -> Unit,
    onOpenMatchView: (String) -> Unit,
    viewModel: ScoringViewModel = viewModel(key = "score-$matchId", factory = ScoringViewModel.factory(matchId)),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val match = state.match
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    val haptics = LocalHapticFeedback.current
    var showActions by rememberSaveable { mutableStateOf(false) }
    var showSettings by rememberSaveable { mutableStateOf(false) }
    var confirmEnd by rememberSaveable { mutableStateOf(false) }

    KeepScreenOnAndPortrait()
    LiveNotification(match, active = match != null && !state.isComplete && !state.isScheduled)

    // A stronger haptic when a game is won.
    var lastGames by remember { mutableStateOf<Int?>(null) }
    LaunchedEffect(state.gamesCompleted) {
        if (lastGames != null && state.gamesCompleted > (lastGames ?: 0)) haptics.performHapticFeedback(HapticFeedbackType.LongPress)
        lastGames = state.gamesCompleted
    }
    LaunchedEffect(state.errorMessage) {
        // Load failures stay on screen; action failures show briefly.
        if (match != null) state.errorMessage?.let {
            snackbar.showSnackbar(it)
            viewModel.clearError()
        }
    }

    val onScore: (String) -> Unit = { side ->
        if (state.canScore) haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
        viewModel.score(side)
    }
    val undoPrompt = stringResource(R.string.undo_prompt)
    val undoLabel = stringResource(R.string.undo)
    val onSwipeUndo: () -> Unit = {
        scope.launch {
            val result = snackbar.showSnackbar(undoPrompt, actionLabel = undoLabel)
            if (result == SnackbarResult.ActionPerformed) viewModel.undo()
        }
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        match?.let { listOfNotNull(MatchFormatting.sportName(it.sport), it.courtName?.takeIf(String::isNotBlank)).joinToString(" · ") }.orEmpty(),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(painterResource(R.drawable.ic_arrow_back), contentDescription = stringResource(R.string.back))
                    }
                },
                actions = {
                    if (match != null && !state.isComplete) {
                        IconButton(onClick = { showSettings = true }) {
                            Icon(painterResource(R.drawable.ic_tab_settings), contentDescription = stringResource(R.string.match_settings))
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background),
            )
        },
        bottomBar = {
            if (match != null && !state.isComplete) {
                BottomDock(
                    timer = state.timer,
                    isScheduled = state.isScheduled,
                    onToggleTimer = viewModel::toggleTimer,
                    onSkip = viewModel::skipTimedPhase,
                    onAction = { showActions = true },
                )
            }
        },
    ) { padding ->
        Box(
            Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            when {
                match == null && state.isLoading -> CircularProgressIndicator(Modifier.align(Alignment.Center))
                match == null -> Text(
                    state.errorMessage ?: stringResource(R.string.not_available),
                    modifier = Modifier.align(Alignment.Center).padding(24.dp),
                )
                state.isComplete -> CompletedCard(match, state, onOpenMatchView = { onOpenMatchView(match.id) }, onUndo = viewModel::undo)
                else -> Column(Modifier.fillMaxSize().padding(horizontal = 12.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    if (!isOnline) {
                        Text(stringResource(R.string.offline), color = ServeOrange, style = MaterialTheme.typography.labelLarge)
                    }
                    if (state.isScheduled) {
                        ScheduledBanner(isMutating = state.isMutating, onStart = viewModel::startScheduled)
                    }
                    if (state.isTennis) {
                        TennisScoreboard(
                            match = match,
                            state = state,
                            onScore = onScore,
                            onSwipeUndo = onSwipeUndo,
                            onChooseReceiver = viewModel::chooseGoldenPointReceiver,
                            modifier = Modifier.weight(1f),
                        )
                    } else {
                        Scoreboard(
                            match = match,
                            state = state,
                            onScore = onScore,
                            onSwipeUndo = onSwipeUndo,
                            onToggleServeSide = viewModel::toggleServeSide,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }

            if (match != null && !state.isComplete && !state.isScheduled) {
                when (state.timer.phase) {
                    TimerPhase.WarmupReady, TimerPhase.WarmupSideOne, TimerPhase.WarmupSideTwo ->
                        WarmupOverlay(state.timer, state.isTennis, viewModel::toggleTimer, viewModel::skipTimedPhase)
                    TimerPhase.FirstServer ->
                        if (state.isTennis) {
                            TennisOpeningOverlay(match, state.isMutating, viewModel::chooseTennisOpening)
                        } else {
                            FirstServerOverlay(match, state.isMutating, viewModel::chooseFirstServer)
                        }
                    TimerPhase.Interval -> IntervalOverlay(state.timer, state.isTennis, viewModel::toggleTimer, viewModel::skipTimedPhase)
                    TimerPhase.MatchLive -> Unit
                }
            }
        }
    }

    if (showActions && match != null) {
        MatchActionsSheet(
            match = match,
            state = state,
            onDismiss = { showActions = false },
            onStroke = viewModel::stroke,
            onLet = viewModel::let,
            showStrokeAndLet = !state.isTennis,
            onUndo = viewModel::undo,
            onEndEarly = { confirmEnd = true },
        )
    }
    if (showSettings && match != null) {
        GameSettingsSheet(match = match, isTennis = state.isTennis, onDismiss = { showSettings = false }, onSave = viewModel::saveSettings)
    }
    if (confirmEnd) {
        AlertDialog(
            onDismissRequest = { confirmEnd = false },
            title = { Text(stringResource(R.string.end_early_title)) },
            text = { Text(stringResource(R.string.end_early_body)) },
            confirmButton = {
                TextButton(onClick = {
                    confirmEnd = false
                    viewModel.endEarly()
                }) { Text(stringResource(R.string.end_match), color = Danger) }
            },
            dismissButton = { TextButton(onClick = { confirmEnd = false }) { Text(stringResource(R.string.cancel)) } },
        )
    }
}

@Composable
private fun Scoreboard(
    match: MatchDetail,
    state: ScoringUiState,
    onScore: (String) -> Unit,
    onSwipeUndo: () -> Unit,
    onToggleServeSide: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val live = match.state
    val p1Shirt = ShirtColors.of(live?.player1ShirtColor ?: match.player1ShirtColor ?: "navy")
    val p2Shirt = ShirtColors.of(live?.player2ShirtColor ?: match.player2ShirtColor ?: "white")
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(28.dp),
        color = HitNScoreTheme.colors.card,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)),
    ) {
        Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // Summary banner
            Row(
                Modifier
                    .padding(horizontal = 8.dp)
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f), RoundedCornerShape(24.dp))
                    .padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(Modifier.size(9.dp).background(HitNScoreTheme.colors.activeStatus, CircleShape))
                Text(
                    stringResource(R.string.score_to, live?.scoreType ?: match.scoreType, live?.currentGameNumber ?: 1, live?.bestOf ?: match.bestOf),
                    modifier = Modifier.weight(1f),
                    textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                    maxLines = 1,
                )
            }
            // Name strips in shirt colours, with the serve-side pill for the server.
            Row(Modifier.fillMaxWidth()) {
                listOf("player1" to p1Shirt, "player2" to p2Shirt).forEach { (side, shirt) ->
                    val name = if (side == "player1") MatchFormatting.fullName(match.player1Name, match.player1Surname) else MatchFormatting.fullName(match.player2Name, match.player2Surname)
                    val serving = live?.currentServerSide == side
                    val sideLabel = live?.serviceSide ?: "Right"
                    val serveDescription = stringResource(R.string.serve_side_description, name, sideLabel)
                    Column(
                        Modifier
                            .weight(1f)
                            .heightIn(min = 92.dp)
                            .background(shirt.fill)
                            .padding(horizontal = 12.dp, vertical = 12.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(name, color = shirt.onFill, style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center, maxLines = 2, overflow = TextOverflow.Ellipsis)
                        if (serving) {
                            Surface(
                                onClick = onToggleServeSide,
                                enabled = state.canScore && state.canToggleServeSide,
                                shape = RoundedCornerShape(50),
                                color = Color.White,
                                border = BorderStroke(2.dp, Danger),
                                modifier = Modifier.semantics { contentDescription = serveDescription },
                            ) {
                                Text(sideLabel, color = Color.Black, style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp))
                            }
                        } else {
                            Spacer(Modifier.height(32.dp))
                        }
                    }
                }
            }
            // Score panels either side of the point rail.
            Row(
                Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = 6.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                ScorePanel(
                    name = match.player1Name,
                    score = live?.player1ScoreLabel ?: "${live?.player1Score ?: 0}",
                    games = live?.player1GamesWon ?: 0,
                    shirt = p1Shirt,
                    enabled = state.canScore,
                    onTap = { onScore("player1") },
                    onSwipeDown = onSwipeUndo,
                )
                PointRail(state.rail, Modifier.weight(1f).fillMaxHeight())
                ScorePanel(
                    name = match.player2Name,
                    score = live?.player2ScoreLabel ?: "${live?.player2Score ?: 0}",
                    games = live?.player2GamesWon ?: 0,
                    shirt = p2Shirt,
                    enabled = state.canScore,
                    onTap = { onScore("player2") },
                    onSwipeDown = onSwipeUndo,
                )
            }
            // Completed games strip.
            val history = live?.gameHistory.orEmpty()
            if (history.isNotEmpty()) {
                LazyRow(
                    Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(history, key = { it.gameNumber }) { game ->
                        Surface(shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.primaryContainer) {
                            Column(Modifier.width(84.dp).padding(vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("${game.player1Score} - ${game.player2Score}", style = ScoreTextStyles.Small.copy(fontSize = 15.sp))
                                Text(initials(game.winnerName), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
            }
            Spacer(Modifier.height(4.dp))
        }
    }
}

/** Tap to score; swipe down to undo (approved UX change 2). */
@Composable
private fun ScorePanel(
    name: String,
    score: String,
    games: Int,
    shirt: ShirtColor,
    enabled: Boolean,
    onTap: () -> Unit,
    onSwipeDown: () -> Unit,
) {
    val description = stringResource(R.string.score_description, name, score)
    var dragged by remember { mutableStateOf(0f) }
    Column(
        modifier = Modifier
            .width(112.dp)
            .fillMaxHeight()
            .padding(vertical = 8.dp)
            .background(shirt.fill, RoundedCornerShape(24.dp))
            .then(
                if (shirt.isLight) Modifier.border(1.5.dp, Color.Black.copy(alpha = 0.18f), RoundedCornerShape(24.dp)) else Modifier,
            )
            .pointerInput(Unit) {
                detectVerticalDragGestures(
                    onDragStart = { dragged = 0f },
                    onDragEnd = { if (dragged > SWIPE_UNDO_THRESHOLD_PX) onSwipeDown() },
                    onVerticalDrag = { _, amount -> dragged += amount },
                )
            }
            .clickable(enabled = enabled, role = Role.Button, onClick = onTap)
            .semantics(mergeDescendants = true) { contentDescription = description }
            .padding(horizontal = 8.dp, vertical = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .background(if (shirt.isLight) Color.Black.copy(alpha = 0.06f) else Color.White.copy(alpha = 0.18f), RoundedCornerShape(18.dp))
                .padding(vertical = 12.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(score, style = ScoreTextStyles.Large.copy(fontSize = 46.sp, lineHeight = 50.sp), color = shirt.onFill, maxLines = 1)
        }
        Text(stringResource(R.string.games_n, games), style = MaterialTheme.typography.labelLarge, color = shirt.onFill)
    }
}

@Composable
private fun PointRail(entries: List<RailEntry>, modifier: Modifier = Modifier) {
    val listState = rememberLazyListState()
    LaunchedEffect(entries.size, entries.lastOrNull()?.id) {
        if (entries.isNotEmpty()) listState.animateScrollToItem(entries.lastIndex)
    }
    LazyColumn(
        state = listState,
        modifier = modifier.padding(vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        items(entries, key = { it.id }) { entry ->
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.weight(1f), contentAlignment = Alignment.CenterEnd) {
                    if (entry.displaySide == "player1") RailMarkers(entry, MaterialTheme.colorScheme.primary)
                }
                Box(Modifier.width(1.dp).height(30.dp).background(MaterialTheme.colorScheme.outlineVariant))
                Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
                    if (entry.displaySide == "player2") RailMarkers(entry, Slate)
                }
            }
        }
    }
}

@Composable
private fun RailMarkers(entry: RailEntry, accent: Color) {
    Row(Modifier.padding(horizontal = 4.dp), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        listOf(entry.sideLabel.ifEmpty { "-" }, entry.score).forEach { label ->
            Box(
                Modifier
                    .size(28.dp)
                    .background(if (entry.isCurrentServe) accent else accent.copy(alpha = 0.14f), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text(label, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = if (entry.isCurrentServe) Color.White else accent)
            }
        }
    }
}

@Composable
private fun BottomDock(
    timer: MatchTimer,
    isScheduled: Boolean,
    onToggleTimer: () -> Unit,
    onSkip: () -> Unit,
    onAction: () -> Unit,
) {
    Surface(color = MaterialTheme.colorScheme.surface, shadowElevation = 6.dp) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                TimerChip(timer, enabled = !isScheduled && timer.phase != TimerPhase.FirstServer, onClick = onToggleTimer, modifier = Modifier.weight(1f))
                Button(
                    onClick = onAction,
                    enabled = !isScheduled,
                    shape = RoundedCornerShape(22.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primaryContainer, contentColor = Slate),
                    modifier = Modifier.height(52.dp).widthIn(min = 124.dp),
                ) {
                    Icon(painterResource(R.drawable.ic_tune), contentDescription = null, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.action), style = MaterialTheme.typography.titleMedium)
                }
            }
            val skipLabel = when (timer.phase) {
                TimerPhase.WarmupSideOne, TimerPhase.WarmupSideTwo -> R.string.skip_warmup
                TimerPhase.Interval -> R.string.skip_break
                else -> null
            }
            if (skipLabel != null) TextButton(onClick = onSkip) { Text(stringResource(skipLabel)) }
        }
    }
}

@Composable
private fun TimerChip(timer: MatchTimer, enabled: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier, large: Boolean = false) {
    val background = when {
        timer.phase == TimerPhase.Interval -> ServeOrange
        timer.isCountdownWarning -> Danger
        timer.phase == TimerPhase.MatchLive -> if (timer.running) RunningGreen else Slate
        else -> if (timer.running) MaterialTheme.colorScheme.primary else Slate
    }
    val foreground = if (timer.phase == TimerPhase.MatchLive && timer.running) Color(0xFF1C3D63) else Color.White
    val text = if (timer.phase == TimerPhase.WarmupReady) stringResource(R.string.start_warmup) else MatchFormatting.clock(timer.displaySeconds)
    val description = stringResource(R.string.timer_description, MatchFormatting.clock(timer.displaySeconds))
    Surface(
        onClick = onClick,
        enabled = enabled,
        shape = RoundedCornerShape(22.dp),
        color = background,
        modifier = modifier.height(if (large) 72.dp else 52.dp).semantics { contentDescription = description },
    ) {
        Box(contentAlignment = Alignment.Center) {
            Text(text, style = ScoreTextStyles.Small.copy(fontSize = if (large) 32.sp else 22.sp), color = foreground)
        }
    }
}

@Composable
private fun OverlayCard(content: @Composable () -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.35f))
            .clickable(enabled = false) {},
        contentAlignment = Alignment.Center,
    ) {
        Surface(shape = RoundedCornerShape(28.dp), color = MaterialTheme.colorScheme.surface, modifier = Modifier.padding(24.dp).widthIn(max = 420.dp)) {
            Column(Modifier.verticalScroll(rememberScrollState()).padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) { content() }
        }
    }
}

@Composable
private fun WarmupOverlay(timer: MatchTimer, isTennis: Boolean, onToggle: () -> Unit, onSkip: () -> Unit) = OverlayCard {
    val ready = timer.phase == TimerPhase.WarmupReady
    Text(stringResource(if (timer.phase == TimerPhase.WarmupSideTwo) R.string.change_sides else R.string.warmup), style = MaterialTheme.typography.headlineSmall)
    Text(
        stringResource(
            when {
                isTennis && timer.phase == TimerPhase.WarmupReady -> R.string.tennis_warmup_body
                isTennis -> R.string.tennis_warmup_running_body
                timer.phase == TimerPhase.WarmupReady -> R.string.warmup_ready_body
                timer.phase == TimerPhase.WarmupSideTwo -> R.string.change_sides_body
                else -> R.string.warmup_running_body
            },
        ),
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    if (ready) {
        Button(onClick = onToggle, modifier = Modifier.fillMaxWidth().height(52.dp), shape = RoundedCornerShape(18.dp)) { Text(stringResource(R.string.start_warmup)) }
    } else {
        TimerChip(timer, enabled = true, onClick = onToggle, modifier = Modifier.fillMaxWidth(), large = true)
    }
    Button(
        onClick = onSkip,
        modifier = Modifier.fillMaxWidth().height(52.dp),
        shape = RoundedCornerShape(18.dp),
        colors = ButtonDefaults.buttonColors(containerColor = Slate),
    ) { Text(stringResource(R.string.skip_warmup)) }
}

@Composable
private fun FirstServerOverlay(match: MatchDetail, isMutating: Boolean, onChoose: (String) -> Unit) = OverlayCard {
    Text(stringResource(R.string.first_server), style = MaterialTheme.typography.headlineSmall)
    Text(stringResource(R.string.first_server_body), color = MaterialTheme.colorScheme.onSurfaceVariant)
    Button(onClick = { onChoose("player1") }, enabled = !isMutating, modifier = Modifier.fillMaxWidth().height(56.dp), shape = RoundedCornerShape(18.dp)) {
        Text(MatchFormatting.fullName(match.player1Name, match.player1Surname))
    }
    Button(
        onClick = { onChoose("player2") },
        enabled = !isMutating,
        modifier = Modifier.fillMaxWidth().height(56.dp),
        shape = RoundedCornerShape(18.dp),
        colors = ButtonDefaults.buttonColors(containerColor = Slate),
    ) { Text(MatchFormatting.fullName(match.player2Name, match.player2Surname)) }
}

/**
 * Tennis/Padel opening order (iOS "Opening Server" / "Serve & Receive"). Singles picks
 * the server; doubles also picks the opposing receiver before the match clock starts.
 */
@Composable
private fun TennisOpeningOverlay(match: MatchDetail, isMutating: Boolean, onBegin: (String, String) -> Unit) = OverlayCard {
    val doubles = TennisRules.isDoubles(match)
    val servers = TennisRules.openingServers(match)
    var serverId by rememberSaveable { mutableStateOf<String?>(null) }
    var receiverId by rememberSaveable { mutableStateOf<String?>(null) }
    val receivers = TennisRules.openingReceivers(match, serverId)
    Text(stringResource(if (doubles) R.string.tennis_serve_and_receive else R.string.tennis_opening_server), style = MaterialTheme.typography.headlineSmall)
    Text(
        stringResource(if (doubles) R.string.tennis_serve_and_receive_body else R.string.tennis_opening_server_body),
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    if (doubles) Text(stringResource(R.string.tennis_opening_server), style = MaterialTheme.typography.labelLarge)
    servers.forEach { participant ->
        SelectRow(participant.displayName, selected = serverId == participant.id) {
            serverId = participant.id
            val updated = TennisRules.openingReceivers(match, participant.id)
            // Singles has one possible receiver; doubles keeps a still-valid choice.
            receiverId = if (doubles) receiverId?.takeIf { id -> updated.any { it.id == id } } else updated.firstOrNull()?.id
        }
    }
    if (doubles && serverId != null) {
        Text(stringResource(R.string.tennis_opening_receiver), style = MaterialTheme.typography.labelLarge)
        receivers.forEach { participant ->
            SelectRow(participant.displayName, selected = receiverId == participant.id) { receiverId = participant.id }
        }
    }
    Button(
        onClick = {
            val server = serverId
            val receiver = receiverId
            if (server != null && receiver != null) onBegin(server, receiver)
        },
        enabled = !isMutating && serverId != null && receiverId != null,
        modifier = Modifier.fillMaxWidth().height(52.dp),
        shape = RoundedCornerShape(18.dp),
    ) { Text(stringResource(R.string.tennis_begin_match)) }
}

@Composable
private fun SelectRow(title: String, selected: Boolean, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(16.dp),
        color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.primaryContainer,
        modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
    ) {
        Box(Modifier.padding(horizontal = 16.dp, vertical = 12.dp), contentAlignment = Alignment.CenterStart) {
            Text(
                title,
                style = MaterialTheme.typography.titleMedium,
                color = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onPrimaryContainer,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun IntervalOverlay(timer: MatchTimer, isTennis: Boolean, onToggle: () -> Unit, onSkip: () -> Unit) = OverlayCard {
    val setBreak = isTennis && timer.intervalDurationSeconds == MatchTimer.TENNIS_SET_BREAK_SECONDS
    val title = when {
        setBreak -> R.string.tennis_set_break
        isTennis -> R.string.tennis_changeover
        else -> R.string.game_break
    }
    val body = when {
        setBreak -> R.string.tennis_set_break_body
        isTennis -> R.string.tennis_changeover_body
        else -> R.string.game_break_body
    }
    Text(stringResource(title), style = MaterialTheme.typography.headlineSmall)
    Text(stringResource(body), color = MaterialTheme.colorScheme.onSurfaceVariant)
    TimerChip(timer, enabled = true, onClick = onToggle, modifier = Modifier.fillMaxWidth(), large = true)
    Button(
        onClick = onSkip,
        modifier = Modifier.fillMaxWidth().height(52.dp),
        shape = RoundedCornerShape(18.dp),
        colors = ButtonDefaults.buttonColors(containerColor = Slate),
    ) { Text(stringResource(R.string.skip_break)) }
}

@Composable
private fun ScheduledBanner(isMutating: Boolean, onStart: () -> Unit) {
    Surface(shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.primaryContainer, modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(start = 16.dp, end = 8.dp, top = 8.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.scheduled_note), modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
            Button(onClick = onStart, enabled = !isMutating, shape = RoundedCornerShape(50)) { Text(stringResource(R.string.start_scheduled)) }
        }
    }
}

@Composable
private fun CompletedCard(match: MatchDetail, state: ScoringUiState, onOpenMatchView: () -> Unit, onUndo: () -> Unit) {
    val live = match.state
    val p1 = MatchFormatting.fullName(match.player1Name, match.player1Surname)
    val p2 = MatchFormatting.fullName(match.player2Name, match.player2Surname)
    val winner = live?.winnerName ?: when {
        (live?.player1GamesWon ?: 0) > (live?.player2GamesWon ?: 0) -> p1
        (live?.player2GamesWon ?: 0) > (live?.player1GamesWon ?: 0) -> p2
        else -> null
    }
    Column(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Surface(shape = RoundedCornerShape(28.dp), color = HitNScoreTheme.colors.card, modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(stringResource(R.string.completed_title), style = MaterialTheme.typography.labelLarge, color = HitNScoreTheme.colors.completedStatus)
                winner?.let { Text(stringResource(R.string.completed_winner, it), style = MaterialTheme.typography.headlineSmall) }
                listOf(p1 to (live?.player1GamesWon ?: 0), p2 to (live?.player2GamesWon ?: 0)).forEach { (name, games) ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(name, style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f))
                        Text("$games", style = ScoreTextStyles.Medium, color = MaterialTheme.colorScheme.primary)
                    }
                }
                Text(
                    live?.gameHistory.orEmpty().joinToString("   ") { "${it.player1Score}-${it.player2Score}" },
                    style = MaterialTheme.typography.bodyLarge.copy(fontFeatureSettings = "tnum"),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(stringResource(R.string.completed_time, MatchFormatting.clock(state.timer.matchDurationSeconds)), style = MaterialTheme.typography.bodyMedium)
            }
        }
        Button(onClick = onOpenMatchView, modifier = Modifier.fillMaxWidth().height(52.dp), shape = RoundedCornerShape(18.dp)) {
            Text(stringResource(R.string.view_match))
        }
        if (!state.undoLocked) {
            TextButton(onClick = onUndo, enabled = !state.isMutating, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                Text(stringResource(R.string.action_undo))
            }
        }
    }
}

/** Keeps the display on while scoring and holds phones in portrait (tablets may rotate). */
@Composable
private fun KeepScreenOnAndPortrait() {
    val view = LocalView.current
    val context = LocalContext.current
    val isPhone = LocalConfiguration.current.smallestScreenWidthDp < 600
    DisposableEffect(view, isPhone) {
        view.keepScreenOn = true
        val activity = context as? Activity
        val previous = activity?.requestedOrientation
        if (isPhone) activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        onDispose {
            view.keepScreenOn = false
            if (isPhone && previous != null) activity?.requestedOrientation = previous
        }
    }
}

/** Shows the ongoing "match in progress" notification while this match is live. */
@Composable
private fun LiveNotification(match: MatchDetail?, active: Boolean) {
    val context = LocalContext.current
    val notifier = remember(context) { (context.applicationContext as HitNScoreApplication).container.liveMatchNotifier }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { }
    LaunchedEffect(Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            permission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }
    LaunchedEffect(match, active) {
        if (active && match != null) notifier.show(match) else notifier.cancel()
    }
    DisposableEffect(notifier) { onDispose { notifier.cancel() } }
}

private fun initials(name: String?): String =
    name?.split(" ")?.filter { it.isNotBlank() }?.take(2)?.joinToString("") { it.first().uppercase() }.orEmpty()
