package com.hitnscore.mobile.feature.watch

import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ClipEntry
import androidx.compose.ui.platform.LocalClipboard
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.components.InfoRow
import com.hitnscore.mobile.core.designsystem.components.InnerCard
import kotlinx.coroutines.launch

object ShareLiveScoreTags {
    const val CODE = "share_live_code"
    const val SHARE = "share_live_share"
}

/**
 * The scorer's Share live score sheet (iOS shows the same code under Game Settings ›
 * Remote Match Viewing): the match's viewing code, with Copy and the Android share sheet,
 * so Personal Plus players can follow the score from Matches › Watch a Match. Club courts
 * also show the Spectator Display address and court code.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShareLiveScoreSheet(
    matchId: String,
    matchTitle: String,
    isOnline: Boolean,
    onDismiss: () -> Unit,
    /** Personal Free: no viewing code is requested or shown, only the upgrade note (as iOS). */
    upgradeRequired: Boolean = false,
    viewModel: ShareLiveScoreViewModel = viewModel(key = "share-$matchId", factory = ShareLiveScoreViewModel.factory(matchId)),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val clipboard = LocalClipboard.current
    val scope = rememberCoroutineScope()
    var copied by remember { mutableStateOf(false) }
    LaunchedEffect(isOnline, upgradeRequired) { if (isOnline && !upgradeRequired) viewModel.load() }

    val code = state.viewerCode
    val shareText = stringResource(R.string.share_live_message, matchTitle, code)

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            Modifier
                .padding(horizontal = 22.dp)
                .padding(bottom = 16.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(stringResource(R.string.share_live_title), style = MaterialTheme.typography.headlineSmall)
            if (upgradeRequired) {
                Text(stringResource(R.string.share_live_plus_only), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
                Text(stringResource(R.string.share_live_upgrade), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                return@Column
            }
            Text(stringResource(R.string.share_live_body), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            when {
                code.isNotBlank() -> {
                    InnerCard(shape = RoundedCornerShape(18.dp)) {
                        Column(Modifier.fillMaxWidth().padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(stringResource(R.string.share_live_code_label), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            val spoken = stringResource(R.string.share_live_code_spoken, code.toList().joinToString(" "))
                            Text(
                                code,
                                style = MaterialTheme.typography.headlineMedium.copy(fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Bold, letterSpacing = 4.sp),
                                color = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.testTag(ShareLiveScoreTags.CODE).semantics { contentDescription = spoken },
                            )
                        }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        OutlinedButton(
                            onClick = {
                                scope.launch {
                                    clipboard.setClipEntry(ClipEntry(android.content.ClipData.newPlainText("HitnScore viewing code", code)))
                                    copied = true
                                }
                            },
                            modifier = Modifier.weight(1f),
                        ) { Text(stringResource(if (copied) R.string.share_live_copied else R.string.share_live_copy)) }
                        Button(
                            onClick = {
                                val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, shareText)
                                context.startActivity(Intent.createChooser(send, null))
                            },
                            modifier = Modifier.weight(1f).testTag(ShareLiveScoreTags.SHARE),
                        ) { Text(stringResource(R.string.share_live_share)) }
                    }
                }
                !isOnline -> Text(stringResource(R.string.share_live_offline), color = MaterialTheme.colorScheme.onSurfaceVariant)
                state.errorMessage != null -> {
                    Text(state.errorMessage.orEmpty(), color = MaterialTheme.colorScheme.error)
                    TextButton(onClick = viewModel::load) { Text(stringResource(R.string.retry)) }
                }
                else -> Row(verticalAlignment = Alignment.CenterVertically) {
                    CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                    Spacer(Modifier.width(10.dp))
                    Text(stringResource(R.string.share_live_loading))
                }
            }
            if (state.showsSpectatorDisplay) {
                Text(stringResource(R.string.share_live_spectator), style = MaterialTheme.typography.titleSmall)
                InfoRow(stringResource(R.string.share_live_scoreboard_url), ShareLiveScoreViewModel.SCOREBOARD_URL)
                InfoRow(stringResource(R.string.share_live_court_code), state.access?.displayCode.orEmpty())
            }
        }
    }
}
