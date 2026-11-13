package com.hitnscore.mobile.feature.scoring

import android.content.Context
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CutCornerShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.session.AccountContextType
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.data.model.MatchEvent

/** Device-local scoring preferences (iOS keeps these in @AppStorage). */
object ScoringPreferences {
    private const val FILE = "hitnscore_scoring"
    private const val KEY_STROKE_LET_HELP = "hitnscore.strokeLetHelpEnabled"

    fun strokeLetHelpEnabled(context: Context): Boolean =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).getBoolean(KEY_STROKE_LET_HELP, false)

    fun setStrokeLetHelpEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit().putBoolean(KEY_STROKE_LET_HELP, enabled).apply()
    }
}

/** As iOS `MatchScoringView.isPersonalPlus`: the active plan or any membership is Personal Plus. */
fun SessionState.SignedIn.hasPersonalPlus(): Boolean =
    memberships.any { it.plan?.lowercase() == "personal_plus" } ||
        availableContexts.any { it.type == AccountContextType.Personal && it.plan == "Personal Plus" }

/** As iOS `canUseStrokeLetHelp`: Personal Plus, or a member of any club. */
fun SessionState.SignedIn.canUseStrokeLetHelp(): Boolean =
    hasPersonalPlus() || availableContexts.any { it.type == AccountContextType.Club }

/** Settings › Game Settings › Game Attributes: the ST/L Help switch. */
@Composable
fun StrokeLetHelpSetting(allowed: Boolean, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    var enabled by remember { mutableStateOf(ScoringPreferences.strokeLetHelpEnabled(context)) }
    Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(stringResource(R.string.game_attributes), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.stl_help), style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
                Text(
                    stringResource(if (allowed) R.string.stl_help_body else R.string.stl_help_locked),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Switch(
                checked = enabled && allowed,
                enabled = allowed,
                onCheckedChange = {
                    enabled = it
                    ScoringPreferences.setStrokeLetHelpEnabled(context, it)
                },
            )
        }
    }
}

private enum class ResultShape { Hexagon, Rectangle, Capsule }

/** The Stroke / Let decision flow chart shown from Match Actions › ST/L Help (as iOS). */
@Composable
fun StrokeLetHelpGuide(onBack: () -> Unit) {
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState())) {
        StlQuestionRow(stringResource(R.string.stl_q1), stringResource(R.string.stl_q1_detail), stringResource(R.string.stl_no_let), ResultShape.Hexagon)
        StlDownConnector()
        StlQuestionRow(stringResource(R.string.stl_q2), null, stringResource(R.string.stl_no_let), ResultShape.Hexagon)
        StlDownConnector()
        StlQuestionRow(stringResource(R.string.stl_q3), null, stringResource(R.string.stl_stroke), ResultShape.Rectangle)
        StlDownConnector()
        StlQuestionRow(stringResource(R.string.stl_q4), null, stringResource(R.string.stl_yes_let), ResultShape.Capsule)
        StlDownConnector()
        StlResultBox(stringResource(R.string.stl_stroke), ResultShape.Rectangle, Modifier.padding(start = 52.dp, bottom = 16.dp))
        OutlinedButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.stl_back))
        }
    }
}

@Composable
private fun StlQuestionRow(question: String, detail: String?, noResult: String, shape: ResultShape) {
    Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(question, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold)
            detail?.let {
                Text(it, style = MaterialTheme.typography.bodySmall, fontStyle = FontStyle.Italic, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(stringResource(R.string.stl_no), style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("→", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        StlResultBox(noResult, shape)
    }
}

@Composable
private fun StlDownConnector() {
    Column(Modifier.fillMaxWidth().height(40.dp).padding(start = 86.dp), verticalArrangement = Arrangement.Center) {
        Text(stringResource(R.string.stl_yes), style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text("↓", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun StlResultBox(title: String, shape: ResultShape, modifier: Modifier = Modifier) {
    val outline: Shape = when (shape) {
        ResultShape.Hexagon -> CutCornerShape(16.dp)
        ResultShape.Rectangle -> RectangleShape
        ResultShape.Capsule -> RoundedCornerShape(50)
    }
    Box(
        modifier
            .size(width = 82.dp, height = 52.dp)
            .border(BorderStroke(2.dp, MaterialTheme.colorScheme.onSurface), outline),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
    }
}

/** Serve and call totals for the Personal Plus completed-match card (iOS `completedMatchActionMetrics`). */
data class CompletedActionMetrics(
    val player1ServeWon: Int = 0,
    val player1ServeLost: Int = 0,
    val player2ServeWon: Int = 0,
    val player2ServeLost: Int = 0,
    val strokes: Int = 0,
    val lets: Int = 0,
)

fun completedActionMetrics(events: List<MatchEvent>): CompletedActionMetrics {
    var p1Won = 0
    var p1Lost = 0
    var p2Won = 0
    var p2Lost = 0
    var strokes = 0
    var lets = 0
    for (event in events) {
        if (event.eventType == "stroke") strokes++
        if (event.eventType == "let") lets++
        if (event.eventType != "score_point" && event.eventType != "stroke") continue
        val scorer = event.payload?.scorer ?: event.payload?.playerSide
        when (event.payload?.pointServerSide ?: event.payload?.currentServerSide) {
            "player1" -> if (scorer == "player1") p1Won++ else p1Lost++
            "player2" -> if (scorer == "player2") p2Won++ else p2Lost++
        }
    }
    return CompletedActionMetrics(p1Won, p1Lost, p2Won, p2Lost, strokes, lets)
}

/** A player's Serves Won / Serves Lost tile. */
@Composable
fun ServeMetricTile(playerName: String, won: Int, lost: Int, modifier: Modifier = Modifier) {
    Surface(shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.surfaceVariant, modifier = modifier) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(playerName, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold, maxLines = 1)
            listOf(R.string.serves_won to won, R.string.serves_lost to lost).forEach { (label, value) ->
                Row {
                    Text(stringResource(label), style = MaterialTheme.typography.bodySmall, modifier = Modifier.weight(1f))
                    Text("$value", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                }
            }
        }
    }
}
