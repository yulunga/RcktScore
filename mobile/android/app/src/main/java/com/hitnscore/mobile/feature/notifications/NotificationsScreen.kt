package com.hitnscore.mobile.feature.notifications

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.TextButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.components.EmptyState
import com.hitnscore.mobile.core.designsystem.components.InnerCard
import com.hitnscore.mobile.core.designsystem.components.StatusDot
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.data.model.AppNotification
import com.hitnscore.mobile.data.model.MatchFormatting

/** Backend notification inbox; opening a message marks it read on every device. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsScreen(
    notifications: List<AppNotification>,
    onOpen: (String) -> Unit,
    onBack: () -> Unit,
    /** Deletes the given messages (the × on a card, or "Delete selected"). */
    onDismiss: (Set<String>) -> Unit = {},
    errorMessage: String? = null,
) {
    var expandedId by rememberSaveable { mutableStateOf<String?>(null) }
    var selected by remember { mutableStateOf(setOf<String>()) }
    // Drop selections for messages that are gone.
    val visibleSelection = selected.intersect(notifications.map { it.id }.toSet())
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.notifications)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(painterResource(R.drawable.ic_arrow_back), contentDescription = stringResource(R.string.back))
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background),
            )
        },
    ) { padding ->
        LazyColumn(
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = padding.calculateTopPadding() + 4.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            errorMessage?.let { item { Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.error) } }
            if (notifications.isEmpty()) item { EmptyState(stringResource(R.string.notifications_empty)) }
            if (notifications.isNotEmpty()) item(key = "selection-bar") {
                val allSelected = visibleSelection.size == notifications.size
                Row(verticalAlignment = Alignment.CenterVertically) {
                    TextButton(onClick = { selected = if (allSelected) emptySet() else notifications.map { it.id }.toSet() }) {
                        Text(stringResource(if (allSelected) R.string.notifications_clear_selection else R.string.notifications_select_all))
                    }
                    Spacer(Modifier.weight(1f))
                    if (visibleSelection.isNotEmpty()) {
                        TextButton(onClick = {
                            onDismiss(visibleSelection)
                            selected = emptySet()
                        }) {
                            Text(
                                stringResource(R.string.notifications_delete_selected, visibleSelection.size),
                                color = MaterialTheme.colorScheme.error,
                                fontWeight = FontWeight.Bold,
                            )
                        }
                    }
                }
            }
            items(notifications, key = { it.id }) { notification ->
                val expanded = expandedId == notification.id
                val isSelected = notification.id in visibleSelection
                InnerCard(onClick = {
                    expandedId = if (expanded) null else notification.id
                    onOpen(notification.id)
                }) {
                    Row(Modifier.padding(start = 4.dp), verticalAlignment = Alignment.Top) {
                    Checkbox(
                        checked = isSelected,
                        onCheckedChange = { selected = if (it) selected + notification.id else selected - notification.id },
                        modifier = Modifier.padding(top = 4.dp),
                    )
                    Column(Modifier.weight(1f).padding(top = 16.dp, bottom = 16.dp, end = 4.dp).animateContentSize()) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            if (!notification.isRead) {
                                StatusDot(HitNScoreTheme.colors.brandPink)
                                Spacer(Modifier.width(8.dp))
                            }
                            Text(
                                notification.title,
                                style = MaterialTheme.typography.titleMedium.copy(
                                    fontWeight = if (notification.isRead) FontWeight.Medium else FontWeight.Bold,
                                ),
                                modifier = Modifier.weight(1f),
                            )
                        }
                        Text(
                            MatchFormatting.dateOnly(MatchFormatting.parseInstant(notification.createdAt)),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Text(
                            notification.message,
                            style = MaterialTheme.typography.bodyMedium,
                            maxLines = if (expanded) Int.MAX_VALUE else 2,
                            modifier = Modifier.padding(top = 6.dp),
                        )
                    }
                    IconButton(onClick = { onDismiss(setOf(notification.id)) }) {
                        Icon(
                            painterResource(R.drawable.ic_close),
                            contentDescription = stringResource(R.string.notifications_delete_one, notification.title),
                            tint = HitNScoreTheme.colors.brandPink,
                        )
                    }
                    }
                }
            }
        }
    }
}
