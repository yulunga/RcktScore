package com.hitnscore.mobile.feature.matches

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DateRangePicker
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalIconToggleButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.rememberDateRangePickerState
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
import androidx.compose.ui.unit.dp
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.components.EmptyState
import com.hitnscore.mobile.core.designsystem.components.ErrorBanner
import com.hitnscore.mobile.core.designsystem.components.OfflineState
import com.hitnscore.mobile.core.designsystem.components.SectionCard
import com.hitnscore.mobile.core.designsystem.components.SkeletonRows
import com.hitnscore.mobile.core.session.AccountContextType
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.data.model.MatchFormatting
import com.hitnscore.mobile.data.model.MatchSummary
import com.hitnscore.mobile.feature.home.MatchSection
import com.hitnscore.mobile.feature.shell.MatchesCategory
import com.hitnscore.mobile.feature.shell.ShellActions
import com.hitnscore.mobile.feature.shell.ShellHeader
import com.hitnscore.mobile.feature.shell.ShellUiState
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

/** iOS Matches: Current / Scheduled / History for the active account context. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MatchesScreen(session: SessionState.SignedIn, state: ShellUiState, isPersonalPlus: Boolean, actions: ShellActions) {
    val isPersonal = session.activeContext.type == AccountContextType.Personal
    val dashboard = state.dashboard
    var search by rememberSaveable { mutableStateOf("") }
    var sportFilter by rememberSaveable { mutableStateOf<String?>(null) }
    var startDateMillis by rememberSaveable { mutableStateOf<Long?>(null) }
    var endDateMillis by rememberSaveable { mutableStateOf<Long?>(null) }
    var showDatePicker by rememberSaveable { mutableStateOf(false) }
    // Collapsed by default, as iOS: the filter button reveals search and filters.
    var filtersExpanded by rememberSaveable { mutableStateOf(false) }
    val filtersActive = search.isNotBlank() || sportFilter != null || startDateMillis != null

    val recent = dashboard?.recentMatches.orEmpty()
    val sports = remember(recent) { recent.filterNot { it.locked }.map { it.sport ?: "squash" }.distinct().sorted() }
    val filtered = remember(recent, search, sportFilter, startDateMillis, endDateMillis) {
        filterHistory(recent, search, sportFilter, startDateMillis?.toUtcDate(), endDateMillis?.toUtcDate())
    }

    PullToRefreshBox(isRefreshing = state.isRefreshing, onRefresh = actions.onRefresh, modifier = Modifier.fillMaxSize()) {
        LazyColumn(
            // Bottom space so the Start button never covers the last card.
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 96.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            item(key = "header") {
                ShellHeader(
                    session = session,
                    isOnline = state.isOnline,
                    hasUnreadNotifications = state.hasUnreadNotifications,
                    contextLabel = stringResource(R.string.context_label_matches),
                    onOpenNotifications = actions.onOpenNotifications,
                    onContextSelected = actions.onContextSelected,
                )
            }
            item(key = "category") {
                val options = listOf(
                    MatchesCategory.Current to R.string.matches_current,
                    MatchesCategory.Scheduled to R.string.matches_scheduled,
                    MatchesCategory.History to R.string.matches_history,
                )
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                    options.forEachIndexed { index, (category, label) ->
                        SegmentedButton(
                            selected = state.matchesCategory == category,
                            onClick = { actions.onSelectMatchesCategory(category) },
                            shape = SegmentedButtonDefaults.itemShape(index, options.size),
                        ) { Text(stringResource(label)) }
                    }
                }
            }
            state.errorMessage?.let { message ->
                item(key = "error") { ErrorBanner(message, onRetry = actions.onRefresh) }
            }

            when (state.matchesCategory) {
                MatchesCategory.Current -> item(key = "current") {
                    SectionCard(
                        title = stringResource(R.string.section_current_matches),
                        subtitle = stringResource(if (isPersonal) R.string.current_matches_personal else R.string.current_matches_club),
                    ) {
                        MatchSection(dashboard?.activeMatches.orEmpty(), state.isLoading, stringResource(R.string.empty_active)) {
                            ActiveMatchCard(it) { actions.onOpenMatch(it) }
                        }
                    }
                }

                MatchesCategory.Scheduled -> item(key = "scheduled") {
                    SectionCard(title = stringResource(R.string.section_scheduled_matches), iconRes = R.drawable.ic_tab_matches) {
                        if (isPersonal && !isPersonalPlus) {
                            UpgradePrompt(
                                title = stringResource(R.string.scheduling_upgrade_title),
                                body = stringResource(R.string.scheduling_upgrade_body),
                                onViewPlan = actions.onOpenSubscription,
                            )
                        } else {
                            MatchSection(dashboard?.scheduledMatches.orEmpty(), state.isLoading, stringResource(R.string.empty_scheduled)) {
                                ScheduledMatchCard(it)
                            }
                        }
                    }
                }

                MatchesCategory.History -> {
                    item(key = "historyFilters") {
                        SectionCard(
                            title = stringResource(R.string.section_recent_matches),
                            iconRes = R.drawable.ic_date_range,
                            subtitle = stringResource(R.string.history_subtitle),
                        ) {
                            if (!state.isOnline) {
                                OfflineState(stringResource(R.string.offline_history))
                            } else {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        when {
                                            state.isLoading && recent.isEmpty() -> ""
                                            filtersActive -> stringResource(R.string.history_filters_active) + " · " +
                                                stringResource(R.string.history_count, filtered.size)
                                            else -> stringResource(R.string.history_count, filtered.size)
                                        },
                                        style = MaterialTheme.typography.labelMedium,
                                        color = if (filtersActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.weight(1f),
                                    )
                                    if (filtersActive) {
                                        TextButton(onClick = {
                                            search = ""
                                            sportFilter = null
                                            startDateMillis = null
                                            endDateMillis = null
                                        }) { Text(stringResource(R.string.history_clear_all)) }
                                    }
                                    FilledTonalIconToggleButton(
                                        checked = filtersExpanded || filtersActive,
                                        onCheckedChange = { filtersExpanded = !filtersExpanded },
                                    ) {
                                        Icon(
                                            painterResource(R.drawable.ic_filter_list),
                                            contentDescription = stringResource(
                                                if (filtersExpanded) R.string.history_hide_filters else R.string.history_show_filters,
                                            ),
                                        )
                                    }
                                }
                                AnimatedVisibility(visible = filtersExpanded) {
                                HistoryFilters(
                                    search = search,
                                    onSearchChange = { search = it },
                                    sports = sports,
                                    sportFilter = sportFilter,
                                    onSportFilter = { sportFilter = it },
                                    startDateMillis = startDateMillis,
                                    endDateMillis = endDateMillis,
                                    onPickDates = { showDatePicker = true },
                                    onClearDates = {
                                        startDateMillis = null
                                        endDateMillis = null
                                    },
                                )
                                }
                                when {
                                    state.isLoading && recent.isEmpty() -> SkeletonRows(3)
                                    filtered.isEmpty() -> EmptyState(
                                        stringResource(if (recent.isEmpty()) R.string.empty_recent else R.string.history_no_results),
                                    )
                                }
                            }
                        }
                    }
                    if (state.isOnline) {
                        itemsIndexed(
                            items = filtered,
                            key = { index, match -> if (match.locked) "locked-$index" else "match-${match.matchId}" },
                        ) { _, match ->
                            if (match.locked) {
                                LockedHistoryCard(onViewPlan = actions.onOpenSubscription)
                            } else {
                                RecentMatchCard(match) { actions.onOpenMatch(match) }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showDatePicker) {
        val pickerState = rememberDateRangePickerState(
            initialSelectedStartDateMillis = startDateMillis,
            initialSelectedEndDateMillis = endDateMillis,
        )
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    startDateMillis = pickerState.selectedStartDateMillis
                    endDateMillis = pickerState.selectedEndDateMillis ?: pickerState.selectedStartDateMillis
                    showDatePicker = false
                }) { Text(stringResource(R.string.ok)) }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text(stringResource(R.string.cancel)) }
            },
        ) {
            DateRangePicker(state = pickerState, modifier = Modifier.fillMaxWidth())
        }
    }
}

@Composable
private fun HistoryFilters(
    search: String,
    onSearchChange: (String) -> Unit,
    sports: List<String>,
    sportFilter: String?,
    onSportFilter: (String?) -> Unit,
    startDateMillis: Long?,
    endDateMillis: Long?,
    onPickDates: () -> Unit,
    onClearDates: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        OutlinedTextField(
            value = search,
            onValueChange = onSearchChange,
            modifier = Modifier.fillMaxWidth(),
            placeholder = { Text(stringResource(R.string.history_search)) },
            leadingIcon = { Icon(painterResource(R.drawable.ic_search), contentDescription = null) },
            trailingIcon = {
                if (search.isNotEmpty()) {
                    IconButton(onClick = { onSearchChange("") }) {
                        Icon(painterResource(R.drawable.ic_close), contentDescription = stringResource(R.string.history_clear_search))
                    }
                }
            },
            singleLine = true,
            shape = RoundedCornerShape(14.dp),
        )
        Row(
            modifier = Modifier.horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            FilterChip(
                selected = sportFilter == null,
                onClick = { onSportFilter(null) },
                label = { Text(stringResource(R.string.history_all_sports)) },
            )
            sports.forEach { sport ->
                FilterChip(
                    selected = sportFilter == sport,
                    onClick = { onSportFilter(if (sportFilter == sport) null else sport) },
                    label = { Text(MatchFormatting.sportName(sport)) },
                )
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            val start = startDateMillis?.toUtcDate()
            val end = endDateMillis?.toUtcDate()
            FilterChip(
                selected = start != null,
                onClick = onPickDates,
                leadingIcon = { Icon(painterResource(R.drawable.ic_date_range), contentDescription = null, modifier = Modifier.size(18.dp)) },
                label = {
                    Text(
                        if (start == null) {
                            stringResource(R.string.history_date_any)
                        } else {
                            stringResource(R.string.history_date_range, start.toString(), (end ?: start).toString())
                        },
                    )
                },
            )
            if (start != null) {
                TextButton(onClick = onClearDates) { Text(stringResource(R.string.history_clear_dates)) }
            }
        }
    }
}

@Composable
fun UpgradePrompt(title: String, body: String, onViewPlan: () -> Unit) {
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, style = MaterialTheme.typography.titleMedium)
        Text(body, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        TextButton(onClick = onViewPlan) { Text(stringResource(R.string.view_plan)) }
    }
}

private fun Long.toUtcDate(): LocalDate = Instant.ofEpochMilli(this).atZone(ZoneOffset.UTC).toLocalDate()

/** Text, sport and inclusive date-range filtering of completed matches. Locked rows stay visible only when unfiltered. */
internal fun filterHistory(
    matches: List<MatchSummary>,
    search: String,
    sport: String?,
    from: LocalDate?,
    to: LocalDate?,
): List<MatchSummary> {
    val query = search.trim().lowercase()
    val filtering = query.isNotEmpty() || sport != null || from != null
    return matches.filter { match ->
        if (match.locked) return@filter !filtering
        if (sport != null && (match.sport ?: "squash") != sport) return@filter false
        if (from != null) {
            val day = MatchFormatting.matchDate(match)?.let { MatchFormatting.localDate(it) } ?: return@filter false
            if (day.isBefore(from) || day.isAfter(to ?: from)) return@filter false
        }
        query.isEmpty() || MatchFormatting.searchText(match).contains(query)
    }
}
