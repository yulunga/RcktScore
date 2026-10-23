package com.hitnscore.mobile.feature.matches

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.components.InnerCard
import com.hitnscore.mobile.core.designsystem.components.StatusDot
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.core.designsystem.theme.ScoreTextStyles
import com.hitnscore.mobile.data.model.MatchFormatting
import com.hitnscore.mobile.data.model.MatchSummary

private val DateGradient = Brush.linearGradient(listOf(Color(0xE0FFD60A), Color(0xB8FF9500)))

/** Live match row: court, "In Progress", players either side of the games score. */
@Composable
fun ActiveMatchCard(match: MatchSummary, onClick: () -> Unit) {
    val description = "${MatchFormatting.fullName(match.player1Name, match.player1Surname)} " +
        "${stringResource(R.string.versus)} ${MatchFormatting.fullName(match.player2Name, match.player2Surname)}, " +
        "${MatchFormatting.gamesLine(match.state)}, ${stringResource(R.string.in_progress)}"
    InnerCard(onClick = onClick, modifier = Modifier.semantics { contentDescription = description }) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = match.courtName.orEmpty(),
                    modifier = Modifier.weight(1f),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                StatusDot(HitNScoreTheme.colors.activeStatus)
                Spacer(Modifier.width(6.dp))
                Text(
                    stringResource(R.string.in_progress),
                    style = MaterialTheme.typography.labelMedium,
                    color = HitNScoreTheme.colors.activeStatus,
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                PlayerColumn(match.player1Name, match.player1Surname, Alignment.Start, Modifier.weight(1f))
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(horizontal = 6.dp)) {
                    Text(
                        MatchFormatting.gamesLine(match.state),
                        style = ScoreTextStyles.Medium.copy(fontSize = 28.sp),
                        color = MaterialTheme.colorScheme.primary,
                        maxLines = 1,
                    )
                    Text(
                        stringResource(R.string.best_of, match.bestOf ?: match.state?.bestOf ?: 3),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                PlayerColumn(match.player2Name, match.player2Surname, Alignment.End, Modifier.weight(1f))
                ChevronBadge()
            }
        }
    }
}

/** Compact scheduled-match row: court • format, then the two players. */
@Composable
fun ScheduledMatchCard(match: MatchSummary) {
    val court = match.courtName?.trim().orEmpty()
    val format = stringResource(R.string.best_of, match.bestOf ?: 3)
    InnerCard(shape = RoundedCornerShape(18.dp)) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                if (court.isEmpty()) format else "$court • $format",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
            )
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    MatchFormatting.fullName(match.player1Name, match.player1Surname),
                    style = MaterialTheme.typography.titleSmall,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false),
                )
                Text(stringResource(R.string.versus), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(
                    MatchFormatting.fullName(match.player2Name, match.player2Surname),
                    style = MaterialTheme.typography.titleSmall,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false),
                )
            }
        }
    }
}

/** Completed match row with the yellow date block, winner in pink, games stacked. */
@Composable
fun RecentMatchCard(match: MatchSummary, onClick: () -> Unit) {
    val winner = MatchFormatting.winnerSide(match)
    val date = MatchFormatting.matchDate(match)
    val pink = HitNScoreTheme.colors.brandPink
    val blue = MaterialTheme.colorScheme.primary
    val p1 = MatchFormatting.fullName(match.player1Name, match.player1Surname)
    val p2 = MatchFormatting.fullName(match.player2Name, match.player2Surname)
    val description = "${MatchFormatting.sportName(match.sport)}, ${MatchFormatting.dateOnly(date)}, " +
        "$p1 ${match.state?.player1GamesWon ?: 0}, $p2 ${match.state?.player2GamesWon ?: 0}"

    InnerCard(onClick = onClick, modifier = Modifier.clearAndSetSemantics { contentDescription = description }) {
        Row(Modifier.height(IntrinsicSize.Min)) {
            Column(
                modifier = Modifier
                    .width(64.dp)
                    .fillMaxHeight()
                    .background(DateGradient)
                    .padding(vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Text(MatchFormatting.dayOfMonth(date), style = ScoreTextStyles.Small.copy(fontWeight = FontWeight.Black), color = Color.White)
                Text(
                    MatchFormatting.monthYear(date),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.primary,
                    textAlign = TextAlign.Center,
                )
            }
            Row(
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 10.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text(
                        MatchFormatting.sportName(match.sport),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(p1, style = MaterialTheme.typography.labelLarge, color = if (winner == 1) pink else blue, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(stringResource(R.string.versus), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(p2, style = MaterialTheme.typography.labelLarge, color = if (winner == 2) pink else blue, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(horizontal = 8.dp)) {
                    Text("${match.state?.player1GamesWon ?: 0}", style = ScoreTextStyles.Small.copy(fontWeight = FontWeight.Black), color = if (winner == 1) pink else blue)
                    Text("${match.state?.player2GamesWon ?: 0}", style = ScoreTextStyles.Small.copy(fontWeight = FontWeight.Black), color = if (winner == 2) pink else blue)
                }
                ChevronBadge(size = 28)
            }
        }
    }
}

/** Blurred placeholder for history beyond the Personal Free limit. */
@Composable
fun LockedHistoryCard(onViewPlan: () -> Unit) {
    InnerCard {
        Box(contentAlignment = Alignment.Center) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .blur(6.dp)
                    .padding(16.dp),
            ) {
                Text("Previous match", style = MaterialTheme.typography.titleMedium)
                Text("Player name · Opponent")
                Text("Completed match details", style = MaterialTheme.typography.labelSmall)
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(12.dp)) {
                Icon(painterResource(R.drawable.ic_lock), contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                Text(stringResource(R.string.locked_title), style = MaterialTheme.typography.titleSmall)
                TextButton(onClick = onViewPlan) { Text(stringResource(R.string.view_plan)) }
            }
        }
    }
}

@Composable
private fun PlayerColumn(firstName: String, surname: String?, alignment: Alignment.Horizontal, modifier: Modifier) {
    Column(modifier, horizontalAlignment = alignment) {
        Text(
            firstName.trim().ifEmpty { "Player" },
            style = MaterialTheme.typography.titleMedium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        if (!surname.isNullOrBlank()) {
            Text(
                surname,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun ChevronBadge(size: Int = 38) {
    Box(
        Modifier
            .padding(start = 6.dp)
            .size(size.dp)
            .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(50)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            painterResource(R.drawable.ic_chevron_right),
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size((size * 0.6f).dp),
        )
    }
}
