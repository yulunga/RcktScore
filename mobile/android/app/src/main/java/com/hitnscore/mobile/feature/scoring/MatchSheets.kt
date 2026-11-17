package com.hitnscore.mobile.feature.scoring

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchFormatting

private enum class PendingAction { Stroke, Let }

/** Stroke, let, undo and end early, behind the compact Action button (as iOS). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MatchActionsSheet(
    match: MatchDetail,
    state: ScoringUiState,
    onDismiss: () -> Unit,
    onStroke: (String) -> Unit,
    onLet: (String?) -> Unit,
    onUndo: () -> Unit,
    onEndEarly: () -> Unit,
    /** Stroke and let are squash/racketball calls; tennis and Padel only undo or end early. */
    showStrokeAndLet: Boolean = true,
    /** Score Stream: share the viewing code with Personal Plus players. */
    onShareLiveScore: (() -> Unit)? = null,
    /** ST/L Help is switched on in Game Settings and the account may use it (Personal Plus or club). */
    showStrokeLetHelp: Boolean = false,
) {
    var pending by rememberSaveable { mutableStateOf<PendingAction?>(null) }
    var helpOpen by rememberSaveable { mutableStateOf(false) }
    val p1 = MatchFormatting.fullName(match.player1Name, match.player1Surname)
    val p2 = MatchFormatting.fullName(match.player2Name, match.player2Surname)
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
        Column(
            Modifier
                .padding(horizontal = 22.dp)
                .padding(bottom = 16.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (helpOpen) {
                Text(stringResource(R.string.stl_help_title), style = MaterialTheme.typography.headlineSmall)
                StrokeLetHelpGuide(onBack = { helpOpen = false })
                return@Column
            }
            Text(stringResource(R.string.match_actions), style = MaterialTheme.typography.headlineSmall)
            Text("$p1 ${stringResource(R.string.versus)} $p2", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            when (pending) {
                null -> {
                    if (onShareLiveScore != null) {
                        ActionRow(stringResource(R.string.share_live_title), enabled = true) {
                            onDismiss()
                            onShareLiveScore()
                        }
                    }
                    if (showStrokeAndLet) {
                        ActionRow(stringResource(R.string.action_stroke), enabled = state.canScore) { pending = PendingAction.Stroke }
                        ActionRow(stringResource(R.string.action_let), enabled = state.canScore) { pending = PendingAction.Let }
                    }
                    if (showStrokeLetHelp) {
                        ActionRow(stringResource(R.string.stl_help), enabled = true) { helpOpen = true }
                    }
                    ActionRow(stringResource(R.string.action_undo), enabled = !state.isMutating && !state.undoLocked) {
                        onDismiss()
                        onUndo()
                    }
                    ActionRow(stringResource(R.string.action_end_early), enabled = !state.isMutating && !state.isComplete, danger = true) {
                        onDismiss()
                        onEndEarly()
                    }
                }
                else -> {
                    Text(stringResource(R.string.action_choose_player), style = MaterialTheme.typography.labelLarge)
                    val label = if (pending == PendingAction.Stroke) R.string.action_award_stroke else R.string.action_award_let
                    listOf("player1" to p1, "player2" to p2).forEach { (side, name) ->
                        ActionRow(stringResource(label, name), enabled = state.canScore) {
                            onDismiss()
                            if (pending == PendingAction.Stroke) onStroke(side) else onLet(side)
                        }
                    }
                    if (pending == PendingAction.Let) {
                        ActionRow(stringResource(R.string.action_general_let), enabled = state.canScore) {
                            onDismiss()
                            onLet(null)
                        }
                    }
                    TextButton(onClick = { pending = null }, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                        Text(stringResource(R.string.action_back))
                    }
                }
            }
        }
    }
}

@Composable
private fun ActionRow(title: String, enabled: Boolean, danger: Boolean = false, onClick: () -> Unit) {
    val accent = if (danger) HitNScoreTheme.colors.completedStatus else HitNScoreTheme.colors.brandPink
    Surface(
        onClick = onClick,
        enabled = enabled,
        shape = RoundedCornerShape(18.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        border = BorderStroke(2.dp, accent.copy(alpha = if (enabled) 1f else 0.35f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(
            title,
            style = MaterialTheme.typography.titleMedium,
            color = if (danger) accent else MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
        )
    }
}

/** In-match Game Settings: score type, match format and shirt colours. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GameSettingsSheet(
    match: MatchDetail,
    isTennis: Boolean,
    onDismiss: () -> Unit,
    onSave: (Int, Int, String, String, String, String, String, String, String, String, String, String) -> Unit,
    /** As iOS Game Settings › Remote Match Viewing. */
    onShareLiveScore: (() -> Unit)? = null,
) {
    val live = match.state
    val player1Primary = live?.tennisTeams?.get("player1")?.firstOrNull()
    val player2Primary = live?.tennisTeams?.get("player2")?.firstOrNull()
    val isDoubles = isTennis && (
        live?.teamFormat.equals("doubles", ignoreCase = true) ||
            (live?.tennisTeams?.get("player1")?.size ?: 0) > 1 ||
            (live?.tennisTeams?.get("player2")?.size ?: 0) > 1
        )
    var scoreType by rememberSaveable { mutableStateOf(live?.scoreType ?: match.scoreType) }
    var bestOf by rememberSaveable { mutableStateOf(live?.bestOf ?: match.bestOf) }
    var player1Name by rememberSaveable { mutableStateOf(player1Primary?.firstName ?: match.player1Name) }
    var player1Surname by rememberSaveable { mutableStateOf(player1Primary?.surname ?: match.player1Surname.orEmpty()) }
    var shirt1 by rememberSaveable { mutableStateOf(live?.player1ShirtColor ?: match.player1ShirtColor ?: "navy") }
    var player2Name by rememberSaveable { mutableStateOf(player2Primary?.firstName ?: match.player2Name) }
    var player2Surname by rememberSaveable { mutableStateOf(player2Primary?.surname ?: match.player2Surname.orEmpty()) }
    var shirt2 by rememberSaveable { mutableStateOf(live?.player2ShirtColor ?: match.player2ShirtColor ?: "white") }
    var team1Player2Name by rememberSaveable { mutableStateOf(live?.tennisTeams?.get("player1")?.getOrNull(1)?.firstName.orEmpty()) }
    var team1Player2Surname by rememberSaveable { mutableStateOf(live?.tennisTeams?.get("player1")?.getOrNull(1)?.surname.orEmpty()) }
    var team2Player2Name by rememberSaveable { mutableStateOf(live?.tennisTeams?.get("player2")?.getOrNull(1)?.firstName.orEmpty()) }
    var team2Player2Surname by rememberSaveable { mutableStateOf(live?.tennisTeams?.get("player2")?.getOrNull(1)?.surname.orEmpty()) }
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            Modifier
                .padding(horizontal = 22.dp)
                .padding(bottom = 16.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(stringResource(R.string.match_settings), style = MaterialTheme.typography.headlineSmall)
            if (onShareLiveScore != null) {
                OutlinedButton(
                    onClick = {
                        onDismiss()
                        onShareLiveScore()
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) { Text(stringResource(R.string.share_live_title)) }
            }
            OutlinedTextField(
                value = player1Name,
                onValueChange = { player1Name = it.take(100) },
                label = { Text("Player 1 first name") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = player1Surname,
                onValueChange = { player1Surname = it.take(100) },
                label = { Text("Player 1 surname") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = player2Name,
                onValueChange = { player2Name = it.take(100) },
                label = { Text("Player 2 first name") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = player2Surname,
                onValueChange = { player2Surname = it.take(100) },
                label = { Text("Player 2 surname") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            if (isDoubles) {
                OutlinedTextField(
                    value = team1Player2Name,
                    onValueChange = { team1Player2Name = it.take(100) },
                    label = { Text("Team 1 · Player 2 first name") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = team1Player2Surname,
                    onValueChange = { team1Player2Surname = it.take(100) },
                    label = { Text("Team 1 · Player 2 surname") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = team2Player2Name,
                    onValueChange = { team2Player2Name = it.take(100) },
                    label = { Text("Team 2 · Player 2 first name") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = team2Player2Surname,
                    onValueChange = { team2Player2Surname = it.take(100) },
                    label = { Text("Team 2 · Player 2 surname") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            // Tennis/Padel sets are always first to 6 games, so only the match format changes.
            if (!isTennis) {
                Text(stringResource(R.string.setup_game_format), style = MaterialTheme.typography.labelLarge)
                Choice(listOf(11, 15), scoreType, enabled = !match.handicapEnabled, label = { "PAR-$it" }) { scoreType = it }
            }
            Text(stringResource(R.string.setup_match_format), style = MaterialTheme.typography.labelLarge)
            Choice(listOf(1, 3, 5), bestOf, label = { if (isTennis) "Best of $it sets" else "Best of $it" }) { bestOf = it }
            ShirtPicker(MatchFormatting.fullName(match.player1Name, match.player1Surname), shirt1) { shirt1 = it }
            ShirtPicker(MatchFormatting.fullName(match.player2Name, match.player2Surname), shirt2) { shirt2 = it }
            Button(
                onClick = {
                    onSave(
                        scoreType, bestOf, player1Name, player1Surname, shirt1,
                        player2Name, player2Surname, team1Player2Name, team1Player2Surname,
                        team2Player2Name, team2Player2Surname, shirt2,
                    )
                    onDismiss()
                },
                enabled = player1Name.isNotBlank() && player2Name.isNotBlank() &&
                    (!isDoubles || (team1Player2Name.isNotBlank() && team2Player2Name.isNotBlank())),
                modifier = Modifier.fillMaxWidth(),
            ) { Text(stringResource(R.string.save)) }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Choice(options: List<Int>, selected: Int, enabled: Boolean = true, label: (Int) -> String, onSelect: (Int) -> Unit) {
    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
        options.forEachIndexed { index, option ->
            SegmentedButton(
                selected = option == selected,
                onClick = { onSelect(option) },
                enabled = enabled,
                shape = SegmentedButtonDefaults.itemShape(index, options.size),
            ) { Text(label(option)) }
        }
    }
}

/** Compact colour-dot menu labelled with the player's name, as iOS. */
@Composable
fun ShirtPicker(playerName: String, selected: String, onSelect: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    val current = ShirtColors.of(selected)
    Box {
        OutlinedButton(onClick = { expanded = true }, modifier = Modifier.fillMaxWidth()) {
            Text(playerName, modifier = Modifier.weight(1f), style = MaterialTheme.typography.labelLarge)
            ColorDot(current.fill)
            Spacer(Modifier.width(8.dp))
            Text(current.label)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            ShirtColors.all.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option.label) },
                    leadingIcon = { ColorDot(option.fill) },
                    onClick = {
                        expanded = false
                        onSelect(option.id)
                    },
                )
            }
        }
    }
}

/**
 * The shirt colour as a round swatch (match setup, beside the player's heading): tapping it
 * opens the ten colours as two rows of five swatches, without names.
 */
@Composable
fun ShirtSwatchPicker(selected: String, contentDescription: String, onSelect: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    val current = ShirtColors.of(selected)
    Box {
        Surface(
            onClick = { expanded = true },
            shape = CircleShape,
            color = current.fill,
            border = BorderStroke(2.dp, MaterialTheme.colorScheme.outlineVariant),
            modifier = Modifier.size(36.dp).semantics { this.contentDescription = contentDescription },
        ) {}
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }, shape = RoundedCornerShape(18.dp)) {
            Column(Modifier.padding(horizontal = 12.dp, vertical = 6.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                ShirtColors.all.chunked(5).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        row.forEach { option ->
                            val chosen = option.id == current.id
                            Surface(
                                onClick = {
                                    expanded = false
                                    onSelect(option.id)
                                },
                                shape = CircleShape,
                                color = option.fill,
                                border = BorderStroke(
                                    if (chosen) 3.dp else 1.dp,
                                    if (chosen) MaterialTheme.colorScheme.primary else Color.Black.copy(alpha = 0.2f),
                                ),
                                modifier = Modifier.size(36.dp).semantics { this.contentDescription = option.label },
                            ) {}
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ColorDot(color: Color) {
    Box(
        Modifier
            .size(18.dp)
            .background(color, CircleShape)
            .border(1.dp, Color.Black.copy(alpha = 0.2f), CircleShape),
    )
}
