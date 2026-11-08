package com.hitnscore.mobile.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/*
 * Score Stream (remote match viewing), as iOS `MatchWatchPayload` / `MatchDisplayAccess`
 * and `backend/common/match_watch_logic.py`. The scorer shares an 8-character viewing code;
 * a Personal Plus member enters it to follow the score live.
 */

/** `GET /match_display_access/{match_id}`: the viewing code, and the court display for clubs. */
@Serializable
data class MatchDisplayAccess(
    @SerialName("match_id") val matchId: String = "",
    @SerialName("tenant_id") val tenantId: Int? = null,
    @SerialName("court_id") val courtId: Int? = null,
    @SerialName("court_name") val courtName: String = "",
    @SerialName("court_alias") val courtAlias: String = "",
    @SerialName("display_code") val displayCode: String = "",
    @SerialName("display_code_enabled") val displayCodeEnabled: Boolean = false,
    @SerialName("viewer_code") val viewerCode: String = "",
)

@Serializable
data class MatchDisplayAccessResponseData(@SerialName("display_access") val displayAccess: MatchDisplayAccess)

/** A followed match, refreshed until [finished]. [saved]: in the viewer's Viewed Matches. */
@Serializable
data class MatchWatch(
    val code: String = "",
    val saved: Boolean = false,
    val finished: Boolean = false,
    val match: MatchDetail,
)

@Serializable
data class MatchWatchResponseData(val watch: MatchWatch)

@Serializable
data class MatchWatchRequest(
    @SerialName("organization_id") val organizationId: Int,
    val code: String,
)

/** The viewing code rules shared by the backend, web and iOS. */
object WatchCode {
    const val LENGTH = 8

    /** Upper case, letters and digits only, at most eight characters (as typed). */
    fun normalize(input: String): String = input.uppercase().filter { it.isLetterOrDigit() && it.code < 128 }.take(LENGTH)

    fun isComplete(code: String): Boolean = normalize(code).length == LENGTH
}
