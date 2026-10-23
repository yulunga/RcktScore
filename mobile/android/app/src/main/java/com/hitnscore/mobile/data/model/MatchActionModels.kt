package com.hitnscore.mobile.data.model

import java.util.UUID
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/*
 * Request bodies for match setup and scoring, mirroring iOS `APIClient.swift`.
 * Optional fields default to null and are omitted from the JSON (encodeDefaults is off),
 * matching iOS, which leaves nil values out.
 * Every mutating action carries a fresh `client_action_id` so retries are idempotent.
 */

fun newClientActionId(): String = UUID.randomUUID().toString()

@Serializable
data class PlayerLookup(
    @SerialName("first_name") val firstName: String = "",
    val surname: String = "",
    @SerialName("display_name") val displayName: String = "",
)

@Serializable
data class MatchSetupLookups(
    val players: List<PlayerLookup> = emptyList(),
    val referees: List<String> = emptyList(),
)

@Serializable
data class MatchSetupLookupResponseData(val lookups: MatchSetupLookups = MatchSetupLookups())

/** `POST /start_match`. Team fields are sent for tennis and Padel only. */
@Serializable
data class CreateMatchRequest(
    @SerialName("tenant_id") val tenantId: String,
    @SerialName("court_id") val courtId: String? = null,
    @SerialName("court_name") val courtName: String? = null,
    @SerialName("court_alias") val courtAlias: String? = null,
    @SerialName("player1_name") val player1Name: String,
    @SerialName("player1_surname") val player1Surname: String,
    @SerialName("player1_country") val player1Country: String,
    @SerialName("player1_handedness") val player1Handedness: String,
    @SerialName("player1_shirt_color") val player1ShirtColor: String,
    @SerialName("player2_name") val player2Name: String,
    @SerialName("player2_surname") val player2Surname: String,
    @SerialName("player2_country") val player2Country: String,
    @SerialName("player2_handedness") val player2Handedness: String,
    @SerialName("player2_shirt_color") val player2ShirtColor: String,
    @SerialName("referee_name") val refereeName: String,
    @SerialName("score_type") val scoreType: Int,
    @SerialName("best_of") val bestOf: Int,
    @SerialName("handicap_enabled") val handicapEnabled: Boolean,
    @SerialName("player1_band") val player1Band: String,
    @SerialName("player2_band") val player2Band: String,
    @SerialName("player1_offset") val player1Offset: Int,
    @SerialName("player2_offset") val player2Offset: Int,
    val sport: String,
    val status: String,
    @SerialName("team_format") val teamFormat: String? = null,
    @SerialName("team1_player1_name") val team1Player1Name: String? = null,
    @SerialName("team1_player1_surname") val team1Player1Surname: String? = null,
    @SerialName("team1_player2_name") val team1Player2Name: String? = null,
    @SerialName("team1_player2_surname") val team1Player2Surname: String? = null,
    @SerialName("team2_player1_name") val team2Player1Name: String? = null,
    @SerialName("team2_player1_surname") val team2Player1Surname: String? = null,
    @SerialName("team2_player2_name") val team2Player2Name: String? = null,
    @SerialName("team2_player2_surname") val team2Player2Surname: String? = null,
    @SerialName("team1_player1_shirt_color") val team1Player1ShirtColor: String? = null,
    @SerialName("team1_player2_shirt_color") val team1Player2ShirtColor: String? = null,
    @SerialName("team2_player1_shirt_color") val team2Player1ShirtColor: String? = null,
    @SerialName("team2_player2_shirt_color") val team2Player2ShirtColor: String? = null,
    /** Golden Point. The backend uses the tennis flag name for every sport. */
    @SerialName("tennis_no_ad_scoring") val goldenPoint: Boolean,
    @SerialName("tennis_final_set_match_tiebreak") val finalSetMatchTiebreak: Boolean,
    /** Timed warm-up and breaks. The backend uses the tennis flag name for every sport. */
    @SerialName("tennis_timed_breaks") val timedBreaks: Boolean,
)

@Serializable
data class ScorePointRequest(
    @SerialName("match_id") val matchId: String,
    val scorer: String,
    @SerialName("client_action_id") val clientActionId: String,
)

/** `POST /event_action`: stroke, let, serve side, first server, timer, match settings. */
@Serializable
data class EventActionRequest(
    @SerialName("match_id") val matchId: String,
    @SerialName("action_type") val actionType: String,
    @SerialName("client_action_id") val clientActionId: String,
    @SerialName("player_side") val playerSide: String? = null,
    val note: String? = null,
    val side: String? = null,
    @SerialName("current_server") val currentServer: String? = null,
    @SerialName("current_server_side") val currentServerSide: String? = null,
    @SerialName("service_side") val serviceSide: String? = null,
    @SerialName("match_duration_seconds") val matchDurationSeconds: Int? = null,
    @SerialName("score_type") val scoreType: Int? = null,
    @SerialName("best_of") val bestOf: Int? = null,
    @SerialName("player1_shirt_color") val player1ShirtColor: String? = null,
    @SerialName("player2_shirt_color") val player2ShirtColor: String? = null,
    @SerialName("current_server_participant_id") val currentServerParticipantId: String? = null,
    @SerialName("current_receiver") val currentReceiver: String? = null,
    @SerialName("current_receiver_side") val currentReceiverSide: String? = null,
    @SerialName("current_receiver_participant_id") val currentReceiverParticipantId: String? = null,
    @SerialName("serve_order") val serveOrder: List<String>? = null,
    @SerialName("receiver_deuce_order") val receiverDeuceOrder: Map<String, String>? = null,
)

@Serializable
data class MatchIdRequest(
    @SerialName("match_id") val matchId: String,
    @SerialName("client_action_id") val clientActionId: String? = null,
)

@Serializable
data class EndMatchRequest(
    @SerialName("match_id") val matchId: String,
    @SerialName("ended_early") val endedEarly: Boolean,
    @SerialName("client_action_id") val clientActionId: String,
    val reason: String? = null,
    @SerialName("match_duration_seconds") val matchDurationSeconds: Int? = null,
)
