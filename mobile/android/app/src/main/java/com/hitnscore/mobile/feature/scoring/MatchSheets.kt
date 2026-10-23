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
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
) {
    var pending by rememberSaveable { mutableStateOf<PendingAction?>(null) }
    val p1 = MatchFormatting.fullName(match.player1Name, match.player1Surname)
    val p2 = MatchFormatting.fullName(match.player2Name, match.player2Surname)
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            Modifier
                .padding(horizontal = 22.dp)
                .padding(bottom = 16.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(stringResource(R.string.match_actions), style = MaterialTheme.typography.headlineSmall)
            Text("$p1 ${stringResource(R.string.versus)} $p2", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            when (pending) {
                null -> {
                    if (showStrokeAndLet) {
                        ActionRow(stringResource(R.string.action_stroke), enabled = state.canScore) { pending = PendingAction.Stroke }
                        ActionRow(stringResource(R.string.action_let), enabled = state.canScore) { pending = PendingAction.Let }
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
    onSave: (Int, Int, String, String) -> Unit,
) {
    val live = match.state
    var scoreType by rememberSaveable { mutableStateOf(live?.scoreType ?: match.scoreType) }
    var bestOf by rememberSaveable { mutableStateOf(live?.bestOf ?: match.bestOf) }
    var shirt1 by rememberSaveable { mutableStateOf(live?.player1ShirtColor ?: match.player1ShirtColor ?: "navy") }
    var shirt2 by rememberSaveable { mutableStateOf(live?.player2ShirtColor ?: match.player2ShirtColor ?: "white") }
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            Modifier
                .padding(horizontal = 22.dp)
                .padding(bottom = 16.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(stringResource(R.string.match_settings), style = MaterialTheme.typography.headlineSmall)
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
                    onSave(scoreType, bestOf, shirt1, shirt2)
                    onDismiss()
                },
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

@Composable
fun ColorDot(color: Color) {
    Box(
        Modifier
            .size(18.dp)
            .background(color, CircleShape)
            .border(1.dp, Color.Black.copy(alpha = 0.2f), CircleShape),
    )
}
