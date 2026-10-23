package com.hitnscore.mobile.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/*
 * Match payloads from the v2 backend (`backend/common/match_logic.py`), mirroring
 * iOS `MatchSummary.swift`. Fields are optional with defaults wherever iOS decodes
 * leniently, so a new or missing backend field never breaks a screen.
 */

@Serializable
data class MatchSummary(
    val id: String = "",
    @SerialName("match_id") val legacyMatchId: String? = null,
    @SerialName("player1_name") val player1Name: String = "",
    @SerialName("player1_surname") val player1Surname: String? = null,
    @SerialName("player2_name") val player2Name: String = "",
    @SerialName("player2_surname") val player2Surname: String? = null,
    @SerialName("court_name") val courtName: String? = null,
    val sport: String? = null,
    val status: String = "",
    @SerialName("best_of") val bestOf: Int? = null,
    @SerialName("score_type") val scoreType: Int? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
    @SerialName("completed_at") val completedAt: String? = null,
    @SerialName("match_duration_seconds") val matchDurationSeconds: Int? = null,
    @SerialName("winner_name") val winnerName: String? = null,
    val state: MatchState? = null,
    val locked: Boolean = false,
    @SerialName("viewer_code") val viewerCode: String? = null,
) {
    /** The backend sends `id`; older payloads used `match_id`. */
    val matchId: String
        get() = id.ifBlank { legacyMatchId.orEmpty() }
}

@Serializable
data class MatchDetail(
    val id: String,
    @SerialName("court_name") val courtName: String? = null,
    @SerialName("court_alias") val courtAlias: String? = null,
    @SerialName("court_display_code") val courtDisplayCode: String? = null,
    val sport: String? = null,
    @SerialName("player1_name") val player1Name: String = "",
    @SerialName("player1_surname") val player1Surname: String? = null,
    @SerialName("player1_shirt_color") val player1ShirtColor: String? = null,
    @SerialName("player1_handedness") val player1Handedness: String? = null,
    @SerialName("player2_name") val player2Name: String = "",
    @SerialName("player2_surname") val player2Surname: String? = null,
    @SerialName("player2_shirt_color") val player2ShirtColor: String? = null,
    @SerialName("player2_handedness") val player2Handedness: String? = null,
    @SerialName("referee_name") val refereeName: String? = null,
    @SerialName("score_type") val scoreType: Int = 15,
    @SerialName("best_of") val bestOf: Int = 3,
    @SerialName("handicap_enabled") val handicapEnabled: Boolean = false,
    @SerialName("player1_offset") val player1Offset: Int = 0,
    @SerialName("player2_offset") val player2Offset: Int = 0,
    val status: String = "",
    @SerialName("auto_scheduled") val autoScheduled: Boolean? = null,
    @SerialName("auto_schedule_reason") val autoScheduleReason: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
    @SerialName("completed_at") val completedAt: String? = null,
    @SerialName("match_duration_seconds") val matchDurationSeconds: Int? = null,
    val state: MatchState? = null,
)

@Serializable
data class MatchState(
    @SerialName("player1_score") val player1Score: Int = 0,
    @SerialName("player2_score") val player2Score: Int = 0,
    @SerialName("player1_games_won") val player1GamesWon: Int = 0,
    @SerialName("player2_games_won") val player2GamesWon: Int = 0,
    @SerialName("player1_set_games") val player1SetGames: Int = 0,
    @SerialName("player2_set_games") val player2SetGames: Int = 0,
    @SerialName("current_game_number") val currentGameNumber: Int = 1,
    @SerialName("best_of") val bestOf: Int = 1,
    @SerialName("score_type") val scoreType: Int = 15,
    @SerialName("current_server") val currentServer: String? = null,
    @SerialName("current_server_side") val currentServerSide: String? = null,
    @SerialName("service_side") val serviceSide: String? = null,
    @SerialName("player1_shirt_color") val player1ShirtColor: String? = null,
    @SerialName("player2_shirt_color") val player2ShirtColor: String? = null,
    @SerialName("score_display_mode") val scoreDisplayMode: String? = null,
    @SerialName("player1_score_label") val player1ScoreLabel: String? = null,
    @SerialName("player2_score_label") val player2ScoreLabel: String? = null,
    @SerialName("is_tie_break") val isTieBreak: Boolean = false,
    @SerialName("is_match_tiebreak") val isMatchTiebreak: Boolean = false,
    @SerialName("tennis_no_ad_scoring") val tennisNoAdScoring: Boolean = false,
    @SerialName("tennis_final_set_match_tiebreak") val tennisFinalSetMatchTiebreak: Boolean = false,
    @SerialName("tennis_timed_breaks") val tennisTimedBreaks: Boolean = false,
    @SerialName("no_ad_deciding_side") val noAdDecidingSide: String? = null,
    @SerialName("team_format") val teamFormat: String? = null,
    @SerialName("tennis_teams") val tennisTeams: Map<String, List<TennisParticipant>>? = null,
    @SerialName("current_server_participant_id") val currentServerParticipantId: String? = null,
    @SerialName("current_receiver") val currentReceiver: String? = null,
    @SerialName("current_receiver_side") val currentReceiverSide: String? = null,
    @SerialName("current_receiver_participant_id") val currentReceiverParticipantId: String? = null,
    @SerialName("serve_order") val serveOrder: List<String>? = null,
    @SerialName("receiver_deuce_order") val receiverDeuceOrder: Map<String, String>? = null,
    val handicap: MatchHandicap? = null,
    @SerialName("match_duration_seconds") val matchDurationSeconds: Int = 0,
    @SerialName("game_history") val gameHistory: List<GameHistoryEntry> = emptyList(),
    @SerialName("match_complete") val matchComplete: Boolean = false,
    @SerialName("winner_name") val winnerName: String? = null,
    val events: List<MatchEvent> = emptyList(),
)

@Serializable
data class TennisParticipant(
    val id: String = "",
    @SerialName("first_name") val firstName: String = "",
    val surname: String? = null,
    @SerialName("display_name") val displayName: String = "",
    @SerialName("shirt_color") val shirtColor: String? = null,
)

@Serializable
data class MatchHandicap(
    val enabled: Boolean = false,
    @SerialName("player1_band") val player1Band: String? = null,
    @SerialName("player2_band") val player2Band: String? = null,
    @SerialName("player1_offset") val player1Offset: Int = 0,
    @SerialName("player2_offset") val player2Offset: Int = 0,
)

@Serializable
data class GameHistoryEntry(
    @SerialName("game_number") val gameNumber: Int = 0,
    @SerialName("player1_score") val player1Score: Int = 0,
    @SerialName("player2_score") val player2Score: Int = 0,
    @SerialName("winner_name") val winnerName: String? = null,
)

@Serializable
data class MatchEvent(
    val id: String = "",
    @SerialName("event_type") val eventType: String = "",
    val payload: MatchEventPayload? = null,
    @SerialName("created_at") val createdAt: String? = null,
    val summary: String? = null,
)

/** The subset of event payload fields the read-only views use. */
@Serializable
data class MatchEventPayload(
    val scorer: String? = null,
    @SerialName("player_side") val playerSide: String? = null,
    @SerialName("current_server_side") val currentServerSide: String? = null,
    @SerialName("service_side") val serviceSide: String? = null,
    @SerialName("game_completed") val gameCompleted: Boolean? = null,
    @SerialName("match_completed") val matchCompleted: Boolean? = null,
    @SerialName("player1_score") val player1Score: Int? = null,
    @SerialName("player2_score") val player2Score: Int? = null,
    @SerialName("game_number") val gameNumber: Int? = null,
    val side: String? = null,
    @SerialName("game_result") val gameResult: GameHistoryEntry? = null,
    @SerialName("is_tie_break") val isTieBreak: Boolean? = null,
    @SerialName("point_player1_score") val pointPlayer1Score: Int? = null,
    @SerialName("point_player2_score") val pointPlayer2Score: Int? = null,
    @SerialName("point_player1_score_label") val pointPlayer1ScoreLabel: String? = null,
    @SerialName("point_player2_score_label") val pointPlayer2ScoreLabel: String? = null,
    @SerialName("player1_score_label") val player1ScoreLabel: String? = null,
    @SerialName("player2_score_label") val player2ScoreLabel: String? = null,
    @SerialName("tennis_game_completed") val tennisGameCompleted: Boolean? = null,
    @SerialName("set_completed") val setCompleted: Boolean? = null,
    @SerialName("completed_game_number") val completedGameNumber: Int? = null,
    @SerialName("completed_game_player1_games") val completedGamePlayer1Games: Int? = null,
    @SerialName("completed_game_player2_games") val completedGamePlayer2Games: Int? = null,
)

@Serializable
data class MatchResponseData(val match: MatchDetail)
