package com.hitnscore.mobile.feature.scoring.offline

import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.data.model.EndMatchRequest
import com.hitnscore.mobile.data.model.EventActionRequest
import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchIdRequest
import com.hitnscore.mobile.data.model.MatchState
import com.hitnscore.mobile.data.model.ScorePointRequest
import com.hitnscore.mobile.data.model.newClientActionId
import com.hitnscore.mobile.data.remote.HitNScoreApi
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** The scoring actions that can wait on the phone until it is back online (iOS `OfflineMatchActionKind`). */
@Serializable
enum class OfflineActionKind(val eventType: String) {
    @SerialName("score_point") ScorePoint("score_point"),
    @SerialName("stroke") Stroke("stroke"),
    @SerialName("let") Let("let"),
    @SerialName("serve_side") ServeSide("serve_side"),
    @SerialName("receiver_choice") ReceiverChoice("receiver_choice"),
    @SerialName("server") Server("server"),
    @SerialName("timer") Timer("timer"),
    @SerialName("undo_action") Undo("undo_action"),
    @SerialName("end_match") EndMatch("match_ended"),
    @SerialName("match_settings") MatchSettings("match_settings"),
}

/**
 * One queued scoring action. [id] doubles as the backend `client_action_id`, so a retry
 * after a dropped connection is applied once. [optimisticState] is the scoreboard the
 * phone shows after this action, before the server confirms it.
 */
@Serializable
data class OfflineMatchAction(
    val id: String = newClientActionId(),
    val matchId: String,
    val kind: OfflineActionKind,
    val scorer: String? = null,
    val playerSide: String? = null,
    val note: String? = null,
    val side: String? = null,
    val currentServer: String? = null,
    val currentServerSide: String? = null,
    val serviceSide: String? = null,
    val matchDurationSeconds: Int? = null,
    val currentServerParticipantId: String? = null,
    val currentReceiver: String? = null,
    val currentReceiverSide: String? = null,
    val currentReceiverParticipantId: String? = null,
    val serveOrder: List<String>? = null,
    val receiverDeuceOrder: Map<String, String>? = null,
    val scoreType: Int? = null,
    val bestOf: Int? = null,
    val player1ShirtColor: String? = null,
    val player2ShirtColor: String? = null,
    val optimisticState: MatchState? = null,
    val createdAtMillis: Long = System.currentTimeMillis(),
) {
    /** Sends this action to the backend, as iOS `OfflineQueuedMatchAction.send`. */
    suspend fun send(api: HitNScoreApi): ApiResult<MatchDetail> = when (kind) {
        OfflineActionKind.ScorePoint -> api.scorePoint(ScorePointRequest(matchId, scorer ?: "player1", id))
        OfflineActionKind.Undo -> api.undo(MatchIdRequest(matchId, id))
        OfflineActionKind.EndMatch -> api.endMatch(
            EndMatchRequest(matchId, endedEarly = true, clientActionId = id, reason = note ?: "Ended by operator", matchDurationSeconds = matchDurationSeconds),
        )
        else -> api.eventAction(
            EventActionRequest(
                matchId = matchId,
                actionType = kind.eventType,
                clientActionId = id,
                playerSide = playerSide,
                note = note,
                side = side,
                currentServer = currentServer,
                currentServerSide = currentServerSide,
                serviceSide = serviceSide,
                matchDurationSeconds = matchDurationSeconds,
                scoreType = scoreType,
                bestOf = bestOf,
                player1ShirtColor = player1ShirtColor,
                player2ShirtColor = player2ShirtColor,
                currentServerParticipantId = currentServerParticipantId,
                currentReceiver = currentReceiver,
                currentReceiverSide = currentReceiverSide,
                currentReceiverParticipantId = currentReceiverParticipantId,
                serveOrder = serveOrder,
                receiverDeuceOrder = receiverDeuceOrder,
            ),
        )
    }
}
