package com.hitnscore.mobile.feature.tournaments

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.components.EmptyState
import com.hitnscore.mobile.core.designsystem.components.InnerCard
import com.hitnscore.mobile.core.designsystem.components.SectionCard
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.data.model.TournamentSummary
import com.hitnscore.mobile.feature.shell.ShellActions
import com.hitnscore.mobile.feature.shell.ShellHeader
import com.hitnscore.mobile.feature.shell.ShellUiState
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Tournaments tab (replaces Help when a club has Tournament Manager on), as iOS. */
@Composable
fun TournamentsScreen(session: SessionState.SignedIn, state: ShellUiState, tournaments: TournamentsUiState, actions: ShellActions) {
    LazyColumn(
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
        modifier = Modifier.fillMaxSize(),
    ) {
        item {
            ShellHeader(
                session = session,
                isOnline = state.isOnline,
                hasUnreadNotifications = state.hasUnreadNotifications,
                onOpenNotifications = actions.onOpenNotifications,
                onContextSelected = actions.onContextSelected,
                onSignOut = actions.onSignOut,
            )
        }
        item {
            SectionCard(
                title = stringResource(R.string.tab_tournaments),
                iconRes = R.drawable.ic_tab_tournament,
                subtitle = stringResource(R.string.tournaments_subtitle),
            ) {
                when {
                    tournaments.isLoading -> CircularProgressIndicator()
                    tournaments.errorMessage != null -> Text(tournaments.errorMessage, color = MaterialTheme.colorScheme.error)
                    tournaments.tournaments.isEmpty() -> EmptyState(stringResource(R.string.tournaments_empty))
                    else -> Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        tournaments.tournaments.forEach { TournamentRow(it) }
                    }
                }
            }
        }
    }
}

@Composable
private fun TournamentRow(item: ClubTournament) {
    InnerCard {
        Row(Modifier.padding(14.dp), horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.Top) {
            Box(
                Modifier.size(42.dp).background(MaterialTheme.colorScheme.primary.copy(alpha = 0.1f), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(painterResource(R.drawable.ic_tab_tournament), contentDescription = null, tint = HitNScoreTheme.colors.brandPink)
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(item.tournament.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Text(item.clubName, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.primary)
                Text(detailLine(item.tournament), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Text(
                TournamentsViewModel.statusLabel(item.tournament.status),
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.1f), RoundedCornerShape(50))
                    .padding(horizontal = 9.dp, vertical = 6.dp),
            )
        }
    }
}

/** "Squash · 3 May–5 May 2027 · 12 entries", as iOS `tournamentDetailLine`. */
internal fun detailLine(t: TournamentSummary): String {
    val parts = mutableListOf(t.sport.replaceFirstChar { it.uppercase() })
    val start = t.startsOn?.takeIf { it.isNotBlank() }
    if (start != null) {
        val end = t.endsOn?.takeIf { it.isNotBlank() && it != start }
        parts += if (end != null) "${displayDate(start)}–${displayDate(end)}" else displayDate(start)
    }
    parts += "${t.entryCount} ${if (t.entryCount == 1) "entry" else "entries"}"
    return parts.joinToString(" · ")
}

private fun displayDate(value: String): String =
    runCatching { LocalDate.parse(value.take(10)).format(DateTimeFormatter.ofPattern("d MMM yyyy", Locale.UK)) }.getOrDefault(value)
