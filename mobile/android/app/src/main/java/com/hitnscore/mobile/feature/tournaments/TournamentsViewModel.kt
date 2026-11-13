package com.hitnscore.mobile.feature.tournaments

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.data.model.TournamentSummary
import com.hitnscore.mobile.data.remote.TournamentApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ClubTournament(val clubName: String, val tournament: TournamentSummary)

data class TournamentsUiState(
    /** Clubs with Tournament Manager switched on. Empty hides the Tournaments tab (Help shows instead). */
    val enabledClubIds: List<Int> = emptyList(),
    val tournaments: List<ClubTournament> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
) {
    val hasTournamentClubs: Boolean get() = enabledClubIds.isNotEmpty()
}

/**
 * As iOS `loadTournamentAccess`: for each club, check Tournament Manager in its settings,
 * then list the tournaments that are open for registration, live or in progress.
 */
class TournamentsViewModel(private val api: TournamentApi) : ViewModel() {
    private val mutableState = MutableStateFlow(TournamentsUiState())
    val uiState: StateFlow<TournamentsUiState> = mutableState.asStateFlow()
    private var job: Job? = null
    private var lastClubs: List<Pair<Int, String>>? = null

    /** [clubs] are (organisation id, name) for the user's club memberships. */
    fun load(clubs: List<Pair<Int, String>>, force: Boolean = false) {
        if (!force && clubs == lastClubs) return
        lastClubs = clubs
        job?.cancel()
        if (clubs.isEmpty()) {
            mutableState.value = TournamentsUiState()
            return
        }
        mutableState.update { it.copy(isLoading = true, errorMessage = null) }
        job = viewModelScope.launch {
            val enabled = mutableListOf<Pair<Int, String>>()
            val loaded = mutableListOf<ClubTournament>()
            var firstError: String? = null
            for ((id, name) in clubs) {
                when (val settings = api.organizationSettings(id)) {
                    is ApiResult.Failure -> { firstError = firstError ?: settings.error.message; continue }
                    is ApiResult.Success -> if (!settings.value.organization.features.tournamentManager.webEnabled) continue
                }
                enabled += id to name
                when (val list = api.tournaments(id)) {
                    is ApiResult.Success -> loaded += list.value
                        .filter { it.status.lowercase() in CURRENT_STATUSES }
                        .map { ClubTournament(name, it) }
                    is ApiResult.Failure -> firstError = firstError ?: list.error.message
                }
            }
            mutableState.value = TournamentsUiState(
                enabledClubIds = enabled.sortedBy { it.second.lowercase() }.map { it.first },
                tournaments = sortTournaments(loaded),
                isLoading = false,
                errorMessage = if (enabled.isEmpty()) null else firstError,
            )
        }
    }

    companion object {
        val CURRENT_STATUSES = setOf("registration", "draw_published", "in_progress")

        fun sortTournaments(items: List<ClubTournament>): List<ClubTournament> =
            items.sortedWith(compareBy({ it.tournament.startsOn ?: "9999-12-31" }, { it.tournament.name.lowercase() }))

        fun statusLabel(status: String): String = when (status.lowercase()) {
            "registration" -> "Registration"
            "draw_published" -> "Live"
            "in_progress" -> "In Progress"
            else -> status.replace('_', ' ').split(' ').joinToString(" ") { w -> w.replaceFirstChar { it.uppercase() } }
        }

        val Factory = viewModelFactory {
            initializer {
                val container = (this[APPLICATION_KEY] as HitNScoreApplication).container
                TournamentsViewModel(container.tournamentApi)
            }
        }
    }
}
