package com.hitnscore.mobile.feature.settings

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.data.model.AssociationCompetition
import com.hitnscore.mobile.data.model.AssociationCompetitionDivision
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Club › Leagues (as iOS): the club's leagues and inter-club leagues, each opening to its
 * divisions and their fixtures. Read-only in the app; leagues are managed on the web.
 */
@Composable
internal fun LeaguesPage(state: OrganizationSettingsUiState) {
    val competitions = state.settings?.organization?.associationCompetitions.orEmpty()
        .sortedWith(compareBy({ it.type.lowercase() }, { it.name.lowercase() }))
    EditorCard(stringResource(R.string.settings_leagues), iconRes = R.drawable.ic_tab_tournament) {
        EditorNote(stringResource(R.string.leagues_body))
        when {
            state.isLoading && state.settings == null -> Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                Text(stringResource(R.string.leagues_loading), color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            competitions.isEmpty() -> EditorNote(stringResource(R.string.leagues_empty))
            else -> listOf("league", "interclub").forEach { type ->
                val group = competitions.filter { it.type.lowercase() == type }
                if (group.isNotEmpty()) {
                    Text(
                        stringResource(if (type == "interclub") R.string.leagues_interclub else R.string.leagues_club),
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    group.forEach { LeagueRow(it) }
                }
            }
        }
    }
}

@Composable
private fun LeagueRow(competition: AssociationCompetition) {
    var open by rememberSaveable(competition.type, competition.name) { mutableStateOf(false) }
    val divisions = competition.allDivisions
    val matches = divisions.sumOf { it.fixtures.size }
    Surface(shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            ExpandRow(
                title = competition.name,
                subtitle = "${divisions.size} ${if (divisions.size == 1) "division" else "divisions"} · $matches ${if (matches == 1) "match" else "matches"}",
                open = open,
                onToggle = { open = !open },
            )
            AnimatedVisibility(open) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    if (divisions.isEmpty()) {
                        Text(stringResource(R.string.leagues_no_divisions), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    divisions.forEach { DivisionRow(competition.name, it) }
                }
            }
        }
    }
}

@Composable
private fun DivisionRow(league: String, division: AssociationCompetitionDivision) {
    var open by rememberSaveable(league, division.name) { mutableStateOf(false) }
    val uriHandler = LocalUriHandler.current
    Surface(shape = RoundedCornerShape(14.dp), color = HitNScoreTheme.colors.card, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            val count = division.fixtures.size
            ExpandRow(division.name, "$count ${if (count == 1) "match" else "matches"}", open) { open = !open }
            AnimatedVisibility(open) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    val url = division.url?.trim()?.takeIf { it.startsWith("https://", true) || it.startsWith("http://", true) }
                    if (url != null) {
                        TextButton(onClick = { uriHandler.openUri(url) }) { Text(stringResource(R.string.leagues_open_tables), fontWeight = FontWeight.SemiBold) }
                    }
                    if (division.fixtures.isEmpty()) {
                        Text(stringResource(R.string.leagues_no_matches), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    division.fixtures.forEach { fixture ->
                        val away = fixture.venue.equals("away", ignoreCase = true)
                        val chip = if (away) HitNScoreTheme.colors.brandPink else MaterialTheme.colorScheme.primary
                        Surface(shape = RoundedCornerShape(12.dp), color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f), modifier = Modifier.fillMaxWidth()) {
                            Row(Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f)) {
                                    Text(fixtureDate(fixture.date), style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold)
                                    Text(fixture.opposition, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                                }
                                Text(
                                    stringResource(if (away) R.string.leagues_away else R.string.leagues_home),
                                    style = MaterialTheme.typography.labelMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = chip,
                                    modifier = Modifier
                                        .background(chip.copy(alpha = 0.12f), RoundedCornerShape(50))
                                        .padding(horizontal = 10.dp, vertical = 6.dp),
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ExpandRow(title: String, subtitle: String, open: Boolean, onToggle: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = onToggle), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Icon(
            painterResource(if (open) R.drawable.ic_expand_less else R.drawable.ic_expand_more),
            contentDescription = stringResource(if (open) R.string.collapse else R.string.expand),
            tint = MaterialTheme.colorScheme.primary,
        )
    }
}

/** "Sat 15 Nov 2026" from `2026-11-15`; other text is shown as sent. */
internal fun fixtureDate(value: String): String =
    runCatching { LocalDate.parse(value.take(10)).format(DateTimeFormatter.ofPattern("EEE d MMM yyyy", Locale.UK)) }.getOrDefault(value)
