package com.hitnscore.mobile.feature.watch

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.components.InnerCard
import com.hitnscore.mobile.core.designsystem.components.SectionCard
import com.hitnscore.mobile.data.model.MatchFormatting
import com.hitnscore.mobile.data.model.MatchSummary
import com.hitnscore.mobile.data.model.WatchCode

object WatchMatchCardTags {
    const val CODE = "watch_code_field"
    const val WATCH = "watch_code_button"
}

/**
 * Watch a Match on Matches › Current, for Personal Plus (as iOS): enter the scorer's
 * 8-character viewing code, or reopen a match from Viewed Matches.
 */
@Composable
fun WatchMatchCard(
    viewedMatches: List<MatchSummary>,
    isOnline: Boolean,
    onWatch: (String) -> Unit,
) {
    var code by rememberSaveable { mutableStateOf("") }
    val canWatch = isOnline && WatchCode.isComplete(code)
    val offlineNote: (@Composable () -> Unit)? = if (isOnline) null else {
        { Text(stringResource(R.string.watch_needs_connection)) }
    }
    SectionCard(
        title = stringResource(R.string.watch_card_title),
        iconRes = R.drawable.ic_live_stream,
        subtitle = stringResource(R.string.watch_card_body),
    ) {
        OutlinedTextField(
            value = code,
            onValueChange = { code = WatchCode.normalize(it) },
            placeholder = { Text("ABCD2345") },
            label = { Text(stringResource(R.string.watch_code_field)) },
            singleLine = true,
            textStyle = MaterialTheme.typography.titleMedium.copy(fontFamily = FontFamily.Monospace, letterSpacing = 3.sp),
            keyboardOptions = KeyboardOptions(
                capitalization = KeyboardCapitalization.Characters,
                autoCorrectEnabled = false,
                keyboardType = KeyboardType.Ascii,
                imeAction = ImeAction.Go,
            ),
            keyboardActions = KeyboardActions(onGo = { if (canWatch) onWatch(code) }),
            supportingText = offlineNote,
            modifier = Modifier.fillMaxWidth().testTag(WatchMatchCardTags.CODE),
        )
        Button(
            onClick = { onWatch(code) },
            enabled = canWatch,
            modifier = Modifier.fillMaxWidth().testTag(WatchMatchCardTags.WATCH),
        ) { Text(stringResource(R.string.watch_button)) }

        val saved = viewedMatches.filter { !it.viewerCode.isNullOrBlank() }
        if (saved.isNotEmpty()) {
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            Text(stringResource(R.string.watch_viewed_matches), style = MaterialTheme.typography.titleSmall)
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                saved.forEach { match ->
                    InnerCard(onClick = { onWatch(match.viewerCode.orEmpty()) }) {
                        Row(Modifier.fillMaxWidth().padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text(
                                    "${MatchFormatting.fullName(match.player1Name, match.player1Surname)} ${stringResource(R.string.versus)} " +
                                        MatchFormatting.fullName(match.player2Name, match.player2Surname),
                                    style = MaterialTheme.typography.titleSmall,
                                )
                                Text(
                                    stringResource(if (match.status.equals("completed", ignoreCase = true)) R.string.watch_finished_short else R.string.watch_live_short),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                            Icon(painterResource(R.drawable.ic_chevron_right), contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                        }
                    }
                }
            }
        }
    }
}
