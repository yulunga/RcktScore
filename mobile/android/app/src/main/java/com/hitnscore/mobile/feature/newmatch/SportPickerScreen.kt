package com.hitnscore.mobile.feature.newmatch

import androidx.annotation.DrawableRes
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.core.session.AccountContext
import com.hitnscore.mobile.core.session.AccountContextSwitcher
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.data.model.MatchFormatting

/** Sports offered on Android, matching iOS. */
data class SportOption(val id: String, @param:DrawableRes val ball: Int)

val SPORT_OPTIONS = listOf(
    SportOption("squash", R.drawable.sport_ball_squash),
    SportOption("racketball", R.drawable.sport_ball_racketball),
    SportOption("tennis", R.drawable.sport_ball_tennis),
    SportOption("padel", R.drawable.sport_ball_padel),
)

/** The account's enabled sports, defaulting as iOS does when the backend sends none. */
fun SessionState.SignedIn.enabledSports(): List<String> =
    memberships.firstOrNull { it.id == activeContext.membershipId }?.enabledSports
        ?.map { it.trim().lowercase() }?.filter { it.isNotEmpty() }
        ?: listOf("squash", "racketball", "tennis")

/** "Choose Racket Sport", with the brand court-line cards and ball artwork from iOS. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SportPickerScreen(
    session: SessionState.SignedIn,
    onContextSelected: (AccountContext) -> Unit,
    onChoose: (String) -> Unit,
    onBack: () -> Unit,
) {
    val enabled = session.enabledSports()
    val sports = SPORT_OPTIONS.filter { it.id in enabled }
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.choose_sport)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(painterResource(R.drawable.ic_close), contentDescription = stringResource(R.string.close))
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background),
            )
        },
    ) { padding ->
        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = padding.calculateTopPadding() + 8.dp, bottom = 24.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            item(span = { GridItemSpan(2) }) {
                AccountContextSwitcher(
                    activeContext = session.activeContext,
                    availableContexts = session.availableContexts,
                    label = stringResource(R.string.context_label),
                    onContextSelected = onContextSelected,
                )
            }
            items(sports, key = { it.id }) { sport ->
                SportCard(sport, onClick = { onChoose(sport.id) })
            }
        }
    }
}

@Composable
private fun SportCard(sport: SportOption, onClick: () -> Unit) {
    val blue = MaterialTheme.colorScheme.primary
    val pink = HitNScoreTheme.colors.brandPink
    val name = MatchFormatting.sportName(sport.id)
    val description = stringResource(R.string.start_sport_match, name)
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(24.dp),
        color = MaterialTheme.colorScheme.primaryContainer,
        border = BorderStroke(1.dp, Brush.linearGradient(listOf(blue.copy(alpha = 0.78f), pink.copy(alpha = 0.32f), blue.copy(alpha = 0.28f)))),
        shadowElevation = 2.dp,
        modifier = Modifier
            .aspectRatio(1f)
            .semantics { contentDescription = description },
    ) {
        Box {
            // Simple court diagram behind the ball, in the iOS court-line blue.
            Canvas(Modifier.fillMaxSize().padding(14.dp)) {
                val line = blue.copy(alpha = 0.45f)
                val stroke = Stroke(width = 1.6.dp.toPx())
                drawRoundRect(color = line, style = stroke)
                drawLine(line, Offset(0f, size.height * 0.55f), Offset(size.width, size.height * 0.55f), stroke.width)
                drawLine(line, Offset(size.width / 2, size.height * 0.55f), Offset(size.width / 2, size.height), stroke.width)
            }
            Column(Modifier.fillMaxSize().padding(10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Spacer(Modifier.weight(1f))
                Image(painterResource(sport.ball), contentDescription = null, modifier = Modifier.size(76.dp))
                Spacer(Modifier.weight(0.6f))
                Surface(shape = RoundedCornerShape(50), color = MaterialTheme.colorScheme.surface) {
                    Row(Modifier.padding(horizontal = 11.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(6.dp).background(pink, CircleShape))
                        Spacer(Modifier.width(7.dp))
                        Text(
                            name,
                            style = MaterialTheme.typography.labelLarge,
                            maxLines = 1,
                        )
                    }
                }
            }
        }
    }
}
