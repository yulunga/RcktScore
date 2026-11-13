package com.hitnscore.mobile.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** `GET /organizations/{organization_id}/tournaments` (as iOS `TournamentSummary`). */
@Serializable
data class TournamentSummary(
    val id: String,
    @SerialName("organization_id") val organizationId: Int = 0,
    val name: String = "",
    val sport: String = "",
    val status: String = "",
    @SerialName("starts_on") val startsOn: String? = null,
    @SerialName("ends_on") val endsOn: String? = null,
    @SerialName("venue_name") val venueName: String = "",
    @SerialName("entry_count") val entryCount: Int = 0,
)

@Serializable
data class TournamentListResponseData(val tournaments: List<TournamentSummary> = emptyList())
