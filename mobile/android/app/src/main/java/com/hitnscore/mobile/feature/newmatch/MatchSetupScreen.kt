package com.hitnscore.mobile.feature.newmatch

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.components.ErrorBanner
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.data.model.MatchFormatting
import com.hitnscore.mobile.data.model.PlayerLookup
import com.hitnscore.mobile.feature.scoring.Choice
import com.hitnscore.mobile.feature.scoring.ShirtPicker

/** Match setup for all four sports, as iOS `StartNewMatchView`. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MatchSetupScreen(
    args: SetupArgs,
    onBack: () -> Unit,
    onOpenMatch: (String) -> Unit,
    onScheduled: (String?) -> Unit,
    viewModel: MatchSetupViewModel = viewModel(key = "setup-${args.organizationId}-${args.sport}", factory = MatchSetupViewModel.factory(args)),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val form = state.form
    val sportName = MatchFormatting.sportName(args.sport)
    val singlesLabel = stringResource(R.string.setup_singles)
    val doublesLabel = stringResource(R.string.setup_doubles)

    LaunchedEffect(state.result) {
        when (val result = state.result) {
            is SetupResult.Open -> onOpenMatch(result.matchId)
            is SetupResult.Scheduled -> onScheduled(result.reason)
            null -> Unit
        }
        if (state.result != null) viewModel.consumeResult()
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.match_setup_title, sportName), maxLines = 1, overflow = TextOverflow.Ellipsis) },
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
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = padding.calculateTopPadding() + 4.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            modifier = Modifier.fillMaxSize().imePadding(),
        ) {
            if (state.isLoading) item { Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { CircularProgressIndicator() } }
            state.errorMessage?.let { item { ErrorBanner(it, onRetry = viewModel::load) } }
            if (!state.isLoading && !state.sportEnabled) item { Notice(stringResource(R.string.setup_sport_disabled, sportName)) }
            if (state.personalActiveMatch != null) item { Notice(stringResource(R.string.setup_personal_active)) }
            state.activeCourtMatch?.let { item { Notice(stringResource(R.string.setup_court_busy, form.courtName)) } }

            if (state.showsDoublesToggle) {
                item {
                    FormCard(stringResource(R.string.setup_match_type)) {
                        Choice(listOf(0, 1), if (form.doubles) 1 else 0, label = { if (it == 1) doublesLabel else singlesLabel }) { v ->
                            viewModel.update { it.copy(doubles = v == 1) }
                        }
                    }
                }
            }
            if (state.isTennis && form.doubles) {
                item {
                    TeamCard(
                        title = stringResource(R.string.setup_team_1),
                        first = PlayerFields(1, form.player1Name, form.player1Surname, form.player1Shirt, LookupTarget.Player1),
                        second = PlayerFields(2, form.player2Name, form.player2Surname, form.player2Shirt, LookupTarget.Player2),
                        state = state,
                        viewModel = viewModel,
                    )
                }
                item {
                    TeamCard(
                        title = stringResource(R.string.setup_team_2),
                        first = PlayerFields(3, form.player3Name, form.player3Surname, form.player3Shirt, LookupTarget.Player3),
                        second = PlayerFields(4, form.player4Name, form.player4Surname, form.player4Shirt, LookupTarget.Player4),
                        state = state,
                        viewModel = viewModel,
                    )
                }
            } else {
                item {
                    PlayerCard(
                        title = form.player1Name.trim().ifEmpty { stringResource(R.string.setup_player_1) },
                        firstName = form.player1Name,
                        surname = form.player1Surname,
                        country = form.player1Country,
                        leftHanded = form.player1LeftHanded,
                        shirt = form.player1Shirt,
                        suggestions = if (state.lookupTarget == LookupTarget.Player1) state.playerSuggestions else emptyList(),
                        onFirstName = { v -> viewModel.update { it.copy(player1Name = v) } },
                        onSurname = { v -> viewModel.update { it.copy(player1Surname = v) } },
                        onCountry = { v -> viewModel.update { it.copy(player1Country = v) } },
                        onLeftHanded = { v -> viewModel.update { it.copy(player1LeftHanded = v) } },
                        onShirt = { v -> viewModel.update { it.copy(player1Shirt = v) } },
                        onFocus = { focused -> viewModel.focus(LookupTarget.Player1, focused) },
                        onSuggestion = { viewModel.applySuggestion(LookupTarget.Player1, it) },
                        showDetails = !state.isTennis,
                    )
                }
                item {
                    PlayerCard(
                        title = form.player2Name.trim().ifEmpty { stringResource(R.string.setup_player_2) },
                        firstName = form.player2Name,
                        surname = form.player2Surname,
                        country = form.player2Country,
                        leftHanded = form.player2LeftHanded,
                        shirt = form.player2Shirt,
                        suggestions = if (state.lookupTarget == LookupTarget.Player2) state.playerSuggestions else emptyList(),
                        onFirstName = { v -> viewModel.update { it.copy(player2Name = v) } },
                        onSurname = { v -> viewModel.update { it.copy(player2Surname = v) } },
                        onCountry = { v -> viewModel.update { it.copy(player2Country = v) } },
                        onLeftHanded = { v -> viewModel.update { it.copy(player2LeftHanded = v) } },
                        onShirt = { v -> viewModel.update { it.copy(player2Shirt = v) } },
                        onFocus = { focused -> viewModel.focus(LookupTarget.Player2, focused) },
                        onSuggestion = { viewModel.applySuggestion(LookupTarget.Player2, it) },
                        showDetails = !state.isTennis,
                    )
                }
            }
            if (!args.isPersonal) {
                item {
                    FormCard(stringResource(R.string.setup_court)) {
                        if (state.courts.isEmpty() && !state.isLoading) {
                            Text(stringResource(R.string.setup_no_courts, sportName), color = MaterialTheme.colorScheme.onSurfaceVariant)
                        } else {
                            CourtPicker(state, onSelect = viewModel::selectCourt)
                        }
                    }
                }
            }
            item {
                FormCard(stringResource(R.string.setup_rules)) {
                    Text(stringResource(R.string.setup_match_format), style = MaterialTheme.typography.labelLarge)
                    Choice(listOf(1, 3, 5), form.bestOf, label = { "Best of $it" }) { v -> viewModel.update { it.copy(bestOf = v) } }
                    if (state.isTennis) {
                        TennisRulesOptions(form, onChange = viewModel::update)
                    } else {
                        RacketRulesOptions(form, onChange = viewModel::update)
                    }
                    if (state.canSchedule) {
                        SwitchRow(stringResource(R.string.setup_schedule), stringResource(R.string.setup_schedule_body), form.schedule) { v ->
                            viewModel.update { it.copy(schedule = v) }
                        }
                    }
                }
            }
            if (!args.isPersonal) {
                item {
                    FormCard(stringResource(R.string.setup_referee)) {
                        OutlinedTextField(
                            value = form.refereeName,
                            onValueChange = { v -> viewModel.update { it.copy(refereeName = v) } },
                            modifier = Modifier
                                .fillMaxWidth()
                                .onFocusChanged { viewModel.focus(LookupTarget.Referee, it.isFocused) },
                            placeholder = { Text(stringResource(R.string.setup_referee_hint)) },
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Done),
                        )
                        if (state.lookupTarget == LookupTarget.Referee) {
                            state.refereeSuggestions.forEach { name ->
                                TextButton(onClick = { viewModel.applyReferee(name) }) { Text(name) }
                            }
                        }
                    }
                }
            }
            item {
                Button(
                    onClick = viewModel::submit,
                    enabled = state.canSubmit,
                    modifier = Modifier.fillMaxWidth().height(54.dp),
                    shape = RoundedCornerShape(18.dp),
                ) {
                    if (state.isSubmitting) {
                        CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.5.dp, color = MaterialTheme.colorScheme.onPrimary)
                    } else {
                        Text(stringResource(if (state.shouldSchedule) R.string.setup_schedule_button else R.string.setup_start), style = MaterialTheme.typography.titleMedium)
                    }
                }
            }
            state.personalActiveMatch?.let { active ->
                item {
                    TextButton(onClick = { onOpenMatch(active.matchId) }, modifier = Modifier.fillMaxWidth()) {
                        Text(stringResource(R.string.setup_resume))
                    }
                }
            }
        }
    }
}

@Composable
private fun PlayerCard(
    title: String,
    firstName: String,
    surname: String,
    country: String,
    leftHanded: Boolean,
    shirt: String,
    suggestions: List<PlayerLookup>,
    onFirstName: (String) -> Unit,
    onSurname: (String) -> Unit,
    onCountry: (String) -> Unit,
    onLeftHanded: (Boolean) -> Unit,
    onShirt: (String) -> Unit,
    onFocus: (Boolean) -> Unit,
    onSuggestion: (PlayerLookup) -> Unit,
    /** Country and handedness are squash/racketball details; tennis and Padel hide them. */
    showDetails: Boolean = true,
) {
    FormCard(title) {
        val nameOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Next)
        OutlinedTextField(
            value = firstName,
            onValueChange = onFirstName,
            label = { Text(stringResource(R.string.setup_first_name)) },
            singleLine = true,
            keyboardOptions = nameOptions,
            modifier = Modifier.fillMaxWidth().onFocusChanged { onFocus(it.isFocused) },
        )
        OutlinedTextField(
            value = surname,
            onValueChange = onSurname,
            label = { Text(stringResource(R.string.setup_surname)) },
            singleLine = true,
            keyboardOptions = nameOptions,
            modifier = Modifier.fillMaxWidth().onFocusChanged { if (it.isFocused) onFocus(true) },
        )
        suggestions.forEach { suggestion ->
            Surface(
                onClick = { onSuggestion(suggestion) },
                shape = RoundedCornerShape(12.dp),
                color = MaterialTheme.colorScheme.primaryContainer,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(suggestion.displayName.ifBlank { "${suggestion.firstName} ${suggestion.surname}" }, modifier = Modifier.padding(12.dp))
            }
        }
        if (showDetails) {
            OutlinedTextField(
                value = country,
                onValueChange = onCountry,
                label = { Text(stringResource(R.string.setup_country)) },
                singleLine = true,
                keyboardOptions = nameOptions,
                modifier = Modifier.fillMaxWidth(),
            )
            SwitchRow(stringResource(R.string.setup_left_handed), null, leftHanded, onLeftHanded)
        }
        ShirtPicker(stringResource(R.string.setup_shirt), shirt, onShirt)
    }
}

/** Squash/racketball rules: PAR scoring, handicap bands, Golden Point and timed breaks. */
@Composable
private fun RacketRulesOptions(form: MatchSetupForm, onChange: ((MatchSetupForm) -> MatchSetupForm) -> Unit) {
    Text(stringResource(R.string.setup_game_format), style = MaterialTheme.typography.labelLarge)
    Choice(listOf(11, 15), form.scoreType, enabled = !form.handicap, label = { "PAR-$it" }) { v -> onChange { it.copy(scoreType = v) } }
    SwitchRow(stringResource(R.string.setup_handicap), stringResource(R.string.setup_handicap_body), form.handicap) { v ->
        onChange { it.copy(handicap = v) }
    }
    if (form.handicap) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            BandPicker(form.player1Name.ifBlank { stringResource(R.string.setup_player_1) }, form.player1Band, form.player1Offset, Modifier.weight(1f)) { v ->
                onChange { it.copy(player1Band = v) }
            }
            BandPicker(form.player2Name.ifBlank { stringResource(R.string.setup_player_2) }, form.player2Band, form.player2Offset, Modifier.weight(1f)) { v ->
                onChange { it.copy(player2Band = v) }
            }
        }
    }
    CheckRow(stringResource(R.string.setup_golden_point), stringResource(R.string.setup_golden_point_body, form.scoreType - 1), form.goldenPoint) { v ->
        onChange { it.copy(goldenPoint = v) }
    }
    CheckRow(stringResource(R.string.setup_timed_breaks), stringResource(R.string.setup_timed_breaks_body), form.timedBreaks) { v ->
        onChange { it.copy(timedBreaks = v) }
    }
}

/** Tennis/Padel rules, as iOS: Golden Point, final-set match tiebreak and timed breaks. */
@Composable
private fun TennisRulesOptions(form: MatchSetupForm, onChange: ((MatchSetupForm) -> MatchSetupForm) -> Unit) {
    CheckRow(stringResource(R.string.setup_golden_point), stringResource(R.string.setup_tennis_golden_point_body), form.goldenPoint) { v ->
        onChange { it.copy(goldenPoint = v) }
    }
    CheckRow(
        stringResource(R.string.setup_final_set_tiebreak),
        stringResource(R.string.setup_final_set_tiebreak_body),
        form.finalSetTiebreak,
        enabled = form.bestOf > 1,
    ) { v -> onChange { it.copy(finalSetTiebreak = v) } }
    CheckRow(stringResource(R.string.setup_tennis_timed_breaks), stringResource(R.string.setup_tennis_timed_breaks_body), form.timedBreaks) { v ->
        onChange { it.copy(timedBreaks = v) }
    }
}

/** One doubles player's name and shirt. */
private data class PlayerFields(val number: Int, val firstName: String, val surname: String, val shirt: String, val target: LookupTarget)

private fun MatchSetupForm.withPlayer(number: Int, firstName: String? = null, surname: String? = null, shirt: String? = null): MatchSetupForm = when (number) {
    1 -> copy(player1Name = firstName ?: player1Name, player1Surname = surname ?: player1Surname, player1Shirt = shirt ?: player1Shirt)
    2 -> copy(player2Name = firstName ?: player2Name, player2Surname = surname ?: player2Surname, player2Shirt = shirt ?: player2Shirt)
    3 -> copy(player3Name = firstName ?: player3Name, player3Surname = surname ?: player3Surname, player3Shirt = shirt ?: player3Shirt)
    else -> copy(player4Name = firstName ?: player4Name, player4Surname = surname ?: player4Surname, player4Shirt = shirt ?: player4Shirt)
}

/** A doubles team: two players, each with name lookup and a shirt colour (as iOS `doublesTeamCard`). */
@Composable
private fun TeamCard(title: String, first: PlayerFields, second: PlayerFields, state: MatchSetupUiState, viewModel: MatchSetupViewModel) {
    FormCard(title) {
        listOf(first, second).forEach { player ->
            val nameOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Next)
            val heading = listOf(player.firstName.trim(), player.surname.trim()).filter { it.isNotEmpty() }.joinToString(" ")
            Text(heading.ifEmpty { stringResource(R.string.setup_player_n, player.number) }, style = MaterialTheme.typography.labelLarge)
            OutlinedTextField(
                value = player.firstName,
                onValueChange = { v -> viewModel.update { it.withPlayer(player.number, firstName = v) } },
                label = { Text(stringResource(R.string.setup_first_name)) },
                singleLine = true,
                keyboardOptions = nameOptions,
                modifier = Modifier.fillMaxWidth().onFocusChanged { viewModel.focus(player.target, it.isFocused) },
            )
            OutlinedTextField(
                value = player.surname,
                onValueChange = { v -> viewModel.update { it.withPlayer(player.number, surname = v) } },
                label = { Text(stringResource(R.string.setup_surname)) },
                singleLine = true,
                keyboardOptions = nameOptions,
                modifier = Modifier.fillMaxWidth().onFocusChanged { if (it.isFocused) viewModel.focus(player.target, true) },
            )
            if (state.lookupTarget == player.target) {
                state.playerSuggestions.forEach { suggestion ->
                    Surface(
                        onClick = { viewModel.applySuggestion(player.target, suggestion) },
                        shape = RoundedCornerShape(12.dp),
                        color = MaterialTheme.colorScheme.primaryContainer,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(suggestion.displayName.ifBlank { "${suggestion.firstName} ${suggestion.surname}" }, modifier = Modifier.padding(12.dp))
                    }
                }
            }
            ShirtPicker(stringResource(R.string.setup_shirt), player.shirt) { v -> viewModel.update { it.withPlayer(player.number, shirt = v) } }
        }
    }
}

@Composable
private fun CourtPicker(state: MatchSetupUiState, onSelect: (com.hitnscore.mobile.data.model.CourtSummary) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        OutlinedButton(onClick = { expanded = true }, modifier = Modifier.fillMaxWidth()) {
            Text(state.form.courtName.ifBlank { stringResource(R.string.setup_select_court) }, modifier = Modifier.weight(1f))
            Icon(painterResource(R.drawable.ic_expand_more), contentDescription = null)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            state.courts.forEach { court ->
                DropdownMenuItem(
                    text = { Text(listOf(court.courtName, court.courtAlias).filter { it.isNotBlank() }.distinct().joinToString(" · ")) },
                    onClick = {
                        expanded = false
                        onSelect(court)
                    },
                )
            }
        }
    }
}

@Composable
private fun BandPicker(player: String, band: String, offset: Int, modifier: Modifier, onSelect: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Column(modifier) {
        Text(stringResource(R.string.setup_band, player), style = MaterialTheme.typography.labelMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Box {
            OutlinedButton(onClick = { expanded = true }, modifier = Modifier.fillMaxWidth()) { Text(band.ifBlank { "–" }) }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                Handicap.bands.forEach { option ->
                    DropdownMenuItem(text = { Text(option) }, onClick = {
                        expanded = false
                        onSelect(option)
                    })
                }
            }
        }
        if (band.isNotBlank()) {
            Text(stringResource(R.string.setup_offset, offset), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun FormCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    Surface(
        shape = RoundedCornerShape(24.dp),
        color = HitNScoreTheme.colors.card,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(18.dp).widthIn(max = 560.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            content()
        }
    }
}

@Composable
private fun SwitchRow(title: String, body: String?, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyLarge)
            body?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

@Composable
private fun CheckRow(title: String, body: String, checked: Boolean, enabled: Boolean = true, onChange: (Boolean) -> Unit) {
    Surface(
        onClick = { onChange(!checked) },
        enabled = enabled,
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.primaryContainer,
        modifier = Modifier.fillMaxWidth().alpha(if (enabled) 1f else 0.55f),
    ) {
        Row(Modifier.padding(horizontal = 6.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Checkbox(checked = checked, onCheckedChange = onChange, enabled = enabled)
            Column(Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.bodyLarge)
                Text(body, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun Notice(text: String) {
    Surface(shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.primaryContainer, modifier = Modifier.fillMaxWidth()) {
        Text(text, modifier = Modifier.padding(14.dp), color = MaterialTheme.colorScheme.onPrimaryContainer, style = MaterialTheme.typography.bodyMedium)
    }
}
