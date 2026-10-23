package com.hitnscore.mobile.feature.newmatch

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.data.model.CourtSummary
import com.hitnscore.mobile.data.model.CreateMatchRequest
import com.hitnscore.mobile.data.model.MatchSummary
import com.hitnscore.mobile.data.model.PlayerLookup
import com.hitnscore.mobile.data.remote.HitNScoreApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class LookupTarget { Player1, Player2, Player3, Player4, Referee }

/** Tennis and Padel share the set-based setup. */
fun isTennisStyleSport(sport: String): Boolean = sport.lowercase() in setOf("tennis", "padel")

/**
 * The setup form, as iOS `MatchSetupFormState`. In doubles, players 1 and 2 are
 * team 1 and players 3 and 4 are team 2; in singles, player 2 is the opponent.
 */
data class MatchSetupForm(
    val courtId: String = "",
    val courtName: String = "",
    val courtAlias: String = "",
    val player1Name: String = "",
    val player1Surname: String = "",
    val player1Country: String = "",
    val player1LeftHanded: Boolean = false,
    val player1Shirt: String = "navy",
    val player2Name: String = "",
    val player2Surname: String = "",
    val player2Country: String = "",
    val player2LeftHanded: Boolean = false,
    val player2Shirt: String = "white",
    val doubles: Boolean = false,
    val player3Name: String = "",
    val player3Surname: String = "",
    val player3Shirt: String = "blue",
    val player4Name: String = "",
    val player4Surname: String = "",
    val player4Shirt: String = "red",
    /** Tennis/Padel: a 10-point match tiebreak instead of a deciding final set. */
    val finalSetTiebreak: Boolean = false,
    val refereeName: String = "",
    val scoreType: Int = 15,
    val bestOf: Int = 5,
    val schedule: Boolean = false,
    val handicap: Boolean = false,
    val player1Band: String = "",
    val player2Band: String = "",
    val player1Offset: Int = 0,
    val player2Offset: Int = 0,
    val goldenPoint: Boolean = false,
    val timedBreaks: Boolean = false,
)

sealed interface SetupResult {
    data class Open(val matchId: String) : SetupResult
    data class Scheduled(val reason: String?) : SetupResult
}

data class SetupArgs(
    val sport: String,
    val organizationId: Int,
    val isPersonal: Boolean,
    val isPersonalPlus: Boolean,
    val sessionSports: List<String>,
    val activeMatches: List<MatchSummary>,
)

data class MatchSetupUiState(
    val args: SetupArgs,
    val isLoading: Boolean = true,
    val isSubmitting: Boolean = false,
    val form: MatchSetupForm = MatchSetupForm(),
    val courts: List<CourtSummary> = emptyList(),
    val sportEnabled: Boolean = true,
    val errorMessage: String? = null,
    val lookupTarget: LookupTarget? = null,
    val playerSuggestions: List<PlayerLookup> = emptyList(),
    val refereeSuggestions: List<String> = emptyList(),
    val result: SetupResult? = null,
) {
    /** A club match on a court that already has a match in progress. */
    val activeCourtMatch: MatchSummary?
        get() = if (args.isPersonal || form.courtName.isBlank()) null else args.activeMatches.firstOrNull { it.courtName == form.courtName }

    val canSchedule: Boolean get() = !args.isPersonal || args.isPersonalPlus

    val isTennis: Boolean get() = isTennisStyleSport(args.sport)

    /** Padel is always doubles; tennis offers singles or doubles. */
    val showsDoublesToggle: Boolean get() = args.sport.equals("tennis", ignoreCase = true)

    /** Busy court or the schedule switch: created as scheduled, ready to start later. */
    val shouldSchedule: Boolean get() = (form.schedule && canSchedule) || activeCourtMatch != null

    /** Personal accounts can run one live match at a time. */
    val personalActiveMatch: MatchSummary?
        get() = if (args.isPersonal && !shouldSchedule) args.activeMatches.firstOrNull() else null

    val canSubmit: Boolean
        get() {
            val players = form.player1Name.isNotBlank() && form.player2Name.isNotBlank() &&
                (!form.doubles || (form.player3Name.isNotBlank() && form.player4Name.isNotBlank()))
            val court = args.isPersonal || (form.courtId.isNotBlank() && form.courtName.isNotBlank())
            val bands = !form.handicap || (form.player1Band.isNotBlank() && form.player2Band.isNotBlank())
            return !isLoading && !isSubmitting && sportEnabled && players && court && bands && personalActiveMatch == null
        }
}

class MatchSetupViewModel(
    args: SetupArgs,
    private val api: HitNScoreApi,
) : ViewModel() {

    private val mutableState = MutableStateFlow(MatchSetupUiState(args))
    val uiState: StateFlow<MatchSetupUiState> = mutableState.asStateFlow()
    private var lookupJob: Job? = null

    init {
        load()
    }

    fun load() {
        val args = mutableState.value.args
        mutableState.update { it.copy(isLoading = true, errorMessage = null) }
        viewModelScope.launch {
            when (val result = api.organizationSettings(args.organizationId)) {
                is ApiResult.Success -> {
                    val organization = result.value.organization
                    val courts = result.value.courts.filter { it.sport.isNullOrBlank() || it.sport.equals(args.sport, ignoreCase = true) }
                    val sessionSports = args.sessionSports.map { it.lowercase() }.toSet()
                    val enabled = organization.enabledSports.map { it.lowercase() }.filter { it in sessionSports }
                    mutableState.update { state ->
                        val firstCourt = courts.firstOrNull()
                        val defaults = if (isTennisStyleSport(args.sport)) {
                            // Sets are first to 6 games; no handicap; Padel is always doubles (as iOS).
                            state.form.copy(
                                scoreType = TENNIS_SCORE_TYPE,
                                bestOf = state.form.bestOf.takeIf { it in setOf(1, 3, 5) } ?: 3,
                                doubles = state.form.doubles || args.sport.equals("padel", ignoreCase = true),
                                handicap = false,
                            )
                        } else {
                            state.form
                        }
                        state.copy(
                            isLoading = false,
                            courts = courts,
                            sportEnabled = args.sport in enabled,
                            form = defaults.copy(
                                timedBreaks = organization.timedBreakDefaults[args.sport] ?: false,
                                courtId = if (args.isPersonal) firstCourt?.id?.toString().orEmpty() else state.form.courtId.ifBlank { firstCourt?.id?.toString().orEmpty() },
                                courtName = if (args.isPersonal) firstCourt?.courtName ?: PERSONAL_COURT else state.form.courtName.ifBlank { firstCourt?.courtName.orEmpty() },
                                courtAlias = if (args.isPersonal) firstCourt?.courtAlias ?: PERSONAL_COURT else state.form.courtAlias.ifBlank { firstCourt?.courtAlias.orEmpty() },
                            ),
                        )
                    }
                }
                is ApiResult.Failure -> mutableState.update { it.copy(isLoading = false, errorMessage = result.error.message) }
            }
        }
    }

    fun update(transform: (MatchSetupForm) -> MatchSetupForm) {
        mutableState.update { state ->
            var form = transform(state.form)
            if (state.isTennis) form = form.copy(handicap = false, scoreType = TENNIS_SCORE_TYPE)
            if (!state.showsDoublesToggle && state.isTennis) form = form.copy(doubles = true)
            if (form.bestOf == 1) form = form.copy(finalSetTiebreak = false)
            if (form.handicap && !state.form.handicap) form = form.copy(scoreType = HANDICAP_SCORE_TYPE)
            if (!form.handicap) form = form.copy(player1Band = "", player2Band = "", player1Offset = 0, player2Offset = 0)
            if (form.handicap) {
                form = form.copy(
                    player1Offset = Handicap.offset(form.player1Band, form.player2Band),
                    player2Offset = Handicap.offset(form.player2Band, form.player1Band),
                )
            }
            state.copy(form = form)
        }
        queueLookup()
    }

    fun selectCourt(court: CourtSummary) = update {
        it.copy(courtId = court.id.toString(), courtName = court.courtName, courtAlias = court.courtAlias)
    }

    /** Name suggestions follow the focused field; losing focus only clears its own target. */
    fun focus(target: LookupTarget, focused: Boolean) {
        val current = mutableState.value.lookupTarget
        if (!focused && current != target) return
        if (focused && current == target) return
        mutableState.update {
            it.copy(lookupTarget = if (focused) target else null, playerSuggestions = emptyList(), refereeSuggestions = emptyList())
        }
        queueLookup()
    }

    fun applySuggestion(target: LookupTarget, suggestion: PlayerLookup) {
        lookupJob?.cancel()
        mutableState.update { state ->
            val form = when (target) {
                LookupTarget.Player1 -> state.form.copy(player1Name = suggestion.firstName, player1Surname = suggestion.surname)
                LookupTarget.Player2 -> state.form.copy(player2Name = suggestion.firstName, player2Surname = suggestion.surname)
                LookupTarget.Player3 -> state.form.copy(player3Name = suggestion.firstName, player3Surname = suggestion.surname)
                LookupTarget.Player4 -> state.form.copy(player4Name = suggestion.firstName, player4Surname = suggestion.surname)
                LookupTarget.Referee -> state.form
            }
            state.copy(form = form, lookupTarget = null, playerSuggestions = emptyList())
        }
    }

    fun applyReferee(name: String) {
        lookupJob?.cancel()
        mutableState.update { it.copy(form = it.form.copy(refereeName = name), lookupTarget = null, refereeSuggestions = emptyList()) }
    }

    fun submit() {
        val state = mutableState.value
        if (!state.canSubmit) return
        val form = state.form
        val args = state.args
        val request = if (state.isTennis) tennisRequest(state) else CreateMatchRequest(
            tenantId = args.organizationId.toString(),
            courtId = if (args.isPersonal) null else form.courtId,
            courtName = if (args.isPersonal) null else form.courtName,
            courtAlias = if (args.isPersonal) null else form.courtAlias,
            player1Name = form.player1Name.trim(),
            player1Surname = form.player1Surname.trim(),
            player1Country = form.player1Country.trim(),
            player1Handedness = if (form.player1LeftHanded) "left" else "right",
            player1ShirtColor = form.player1Shirt,
            player2Name = form.player2Name.trim(),
            player2Surname = form.player2Surname.trim(),
            player2Country = form.player2Country.trim(),
            player2Handedness = if (form.player2LeftHanded) "left" else "right",
            player2ShirtColor = form.player2Shirt,
            refereeName = if (args.isPersonal) "" else form.refereeName.trim(),
            scoreType = form.scoreType,
            bestOf = form.bestOf,
            handicapEnabled = form.handicap,
            player1Band = form.player1Band,
            player2Band = form.player2Band,
            player1Offset = form.player1Offset,
            player2Offset = form.player2Offset,
            sport = args.sport,
            status = if (state.shouldSchedule) "scheduled" else "active",
            goldenPoint = form.goldenPoint,
            finalSetMatchTiebreak = false,
            timedBreaks = form.timedBreaks,
        )
        mutableState.update { it.copy(isSubmitting = true, errorMessage = null) }
        viewModelScope.launch {
            when (val result = api.createMatch(request)) {
                is ApiResult.Success -> {
                    val match = result.value
                    val scheduled = match.status.equals("scheduled", ignoreCase = true) || match.autoScheduled == true
                    mutableState.update {
                        it.copy(isSubmitting = false, result = if (scheduled) SetupResult.Scheduled(match.autoScheduleReason) else SetupResult.Open(match.id))
                    }
                }
                is ApiResult.Failure -> mutableState.update { it.copy(isSubmitting = false, errorMessage = result.error.message) }
            }
        }
    }

    /** Tennis/Padel body, as iOS: team names joined with " / " and the team fields filled in. */
    private fun tennisRequest(state: MatchSetupUiState): CreateMatchRequest {
        val form = state.form
        val args = state.args
        val doubles = form.doubles
        fun name(first: String, last: String) = listOf(first.trim(), last.trim()).filter { it.isNotEmpty() }.joinToString(" ")
        fun team(a: String, b: String) = listOf(a, b).filter { it.isNotEmpty() }.joinToString(" / ")
        val side1 = if (doubles) team(name(form.player1Name, form.player1Surname), name(form.player2Name, form.player2Surname)) else name(form.player1Name, form.player1Surname)
        val side2 = if (doubles) team(name(form.player3Name, form.player3Surname), name(form.player4Name, form.player4Surname)) else name(form.player2Name, form.player2Surname)
        return CreateMatchRequest(
            tenantId = args.organizationId.toString(),
            courtId = if (args.isPersonal) null else form.courtId,
            courtName = if (args.isPersonal) null else form.courtName,
            courtAlias = if (args.isPersonal) null else form.courtAlias,
            player1Name = side1,
            player1Surname = if (doubles) "" else form.player1Surname.trim(),
            player1Country = "",
            player1Handedness = "right",
            player1ShirtColor = form.player1Shirt,
            player2Name = side2,
            player2Surname = if (doubles) "" else form.player2Surname.trim(),
            player2Country = "",
            player2Handedness = "right",
            player2ShirtColor = if (doubles) form.player3Shirt else form.player2Shirt,
            refereeName = if (args.isPersonal) "" else form.refereeName.trim(),
            scoreType = TENNIS_SCORE_TYPE,
            bestOf = form.bestOf,
            handicapEnabled = false,
            player1Band = "",
            player2Band = "",
            player1Offset = 0,
            player2Offset = 0,
            sport = args.sport,
            status = if (state.shouldSchedule) "scheduled" else "active",
            teamFormat = if (doubles) "doubles" else "singles",
            team1Player1Name = form.player1Name.trim(),
            team1Player1Surname = form.player1Surname.trim(),
            team1Player2Name = if (doubles) form.player2Name.trim() else null,
            team1Player2Surname = if (doubles) form.player2Surname.trim() else null,
            team2Player1Name = if (doubles) form.player3Name.trim() else form.player2Name.trim(),
            team2Player1Surname = if (doubles) form.player3Surname.trim() else form.player2Surname.trim(),
            team2Player2Name = if (doubles) form.player4Name.trim() else null,
            team2Player2Surname = if (doubles) form.player4Surname.trim() else null,
            team1Player1ShirtColor = if (doubles) form.player1Shirt else null,
            team1Player2ShirtColor = if (doubles) form.player2Shirt else null,
            team2Player1ShirtColor = if (doubles) form.player3Shirt else null,
            team2Player2ShirtColor = if (doubles) form.player4Shirt else null,
            goldenPoint = form.goldenPoint,
            finalSetMatchTiebreak = form.finalSetTiebreak && form.bestOf > 1,
            timedBreaks = form.timedBreaks,
        )
    }

    fun consumeResult() = mutableState.update { it.copy(result = null) }

    /** Debounced name lookup for the focused field, as iOS (220 ms, two characters minimum). */
    private fun queueLookup() {
        lookupJob?.cancel()
        val state = mutableState.value
        val target = state.lookupTarget ?: return
        val query = when (target) {
            LookupTarget.Player1 -> "${state.form.player1Name} ${state.form.player1Surname}"
            LookupTarget.Player2 -> "${state.form.player2Name} ${state.form.player2Surname}"
            LookupTarget.Player3 -> "${state.form.player3Name} ${state.form.player3Surname}"
            LookupTarget.Player4 -> "${state.form.player4Name} ${state.form.player4Surname}"
            LookupTarget.Referee -> state.form.refereeName
        }.trim()
        if (query.length < 2) {
            mutableState.update { it.copy(playerSuggestions = emptyList(), refereeSuggestions = emptyList()) }
            return
        }
        lookupJob = viewModelScope.launch {
            delay(LOOKUP_DEBOUNCE_MS)
            val result = api.setupLookup(state.args.organizationId, query)
            val lookups = (result as? ApiResult.Success)?.value
            mutableState.update {
                if (it.lookupTarget != target) return@update it
                if (target == LookupTarget.Referee) {
                    it.copy(refereeSuggestions = lookups?.referees.orEmpty().filterNot { name -> name.equals(query, ignoreCase = true) }.take(5))
                } else {
                    it.copy(playerSuggestions = lookups?.players.orEmpty().take(5))
                }
            }
        }
    }

    companion object {
        private const val PERSONAL_COURT = "Personal Match"
        private const val HANDICAP_SCORE_TYPE = 15
        private const val TENNIS_SCORE_TYPE = 6
        private const val LOOKUP_DEBOUNCE_MS = 220L

        fun factory(args: SetupArgs): ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val container = (this[APPLICATION_KEY] as HitNScoreApplication).container
                MatchSetupViewModel(args, container.api)
            }
        }
    }
}

/** Squash/racketball handicap bands and starting offsets (same table as iOS and web). */
object Handicap {
    val bands = listOf("A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M")

    private val matrix: Map<String, List<Int>> = mapOf(
        "A" to listOf(0, -1, -2, -3, -4, -5, -6, -6, -7, -8, -8, -9, -10),
        "B" to listOf(1, 0, -1, -2, -3, -4, -5, -6, -6, -7, -8, -8, -9),
        "C" to listOf(2, 1, 0, -1, -2, -3, -4, -5, -6, -6, -7, -8, -8),
        "D" to listOf(3, 2, 1, 0, -1, -2, -3, -4, -5, -6, -6, -7, -8),
        "E" to listOf(4, 3, 2, 1, 0, -1, -2, -3, -4, -5, -6, -6, -7),
        "F" to listOf(5, 4, 3, 2, 1, 0, -1, -2, -3, -4, -5, -6, -6),
        "G" to listOf(6, 5, 4, 3, 2, 1, 0, -1, -2, -3, -4, -5, -6),
        "H" to listOf(6, 6, 5, 4, 3, 2, 1, 0, -1, -2, -3, -4, -5),
        "I" to listOf(7, 6, 6, 5, 4, 3, 2, 1, 0, -1, -2, -3, -4),
        "J" to listOf(8, 7, 6, 6, 5, 4, 3, 2, 1, 0, -1, -2, -3),
        "K" to listOf(8, 8, 7, 6, 6, 5, 4, 3, 2, 1, 0, -1, -2),
        "L" to listOf(9, 8, 8, 7, 6, 6, 5, 4, 3, 2, 1, 0, -1),
        "M" to listOf(10, 9, 8, 8, 7, 6, 6, 5, 4, 3, 2, 1, 0),
    )

    /** Starting score for a player in [band] against an opponent in [opponentBand]. */
    fun offset(band: String, opponentBand: String): Int {
        val column = bands.indexOf(opponentBand)
        if (column < 0) return 0
        return matrix[band]?.getOrNull(column) ?: 0
    }
}
