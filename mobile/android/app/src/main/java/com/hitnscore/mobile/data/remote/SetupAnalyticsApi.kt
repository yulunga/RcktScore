package com.hitnscore.mobile.data.remote

import com.hitnscore.mobile.core.network.ApiClient
import com.hitnscore.mobile.core.network.ApiResult
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class SetupAnalyticsStartRequest(val sport: String)

@Serializable
data class SetupAnalyticsFinishRequest(val outcome: String, @SerialName("match_id") val matchId: String? = null)

@Serializable
data class SetupAnalyticsRecord(val id: String = "")

@Serializable
data class SetupAnalyticsResponseData(val setup: SetupAnalyticsRecord = SetupAnalyticsRecord())

/**
 * Match setup funnel analytics (`/analytics/setup`), as iOS: begin when the setup form opens,
 * finish as `completed` with the match id or `abandoned` when the form closes without one.
 * Failures are ignored; analytics never block scoring.
 */
interface SetupAnalyticsApi {
    suspend fun begin(organizationId: Int, sport: String): ApiResult<String>
    suspend fun finish(organizationId: Int, setupId: String, outcome: String, matchId: String? = null): ApiResult<Unit>
}

class RemoteSetupAnalyticsApi(private val client: ApiClient) : SetupAnalyticsApi {
    override suspend fun begin(organizationId: Int, sport: String) =
        client.post(
            "analytics/setup/$organizationId",
            SetupAnalyticsStartRequest(sport),
            SetupAnalyticsStartRequest.serializer(),
            SetupAnalyticsResponseData.serializer(),
        ).map { it.setup.id }

    override suspend fun finish(organizationId: Int, setupId: String, outcome: String, matchId: String?) =
        client.put(
            "analytics/setup/$organizationId/$setupId",
            SetupAnalyticsFinishRequest(outcome, matchId),
            SetupAnalyticsFinishRequest.serializer(),
            SetupAnalyticsResponseData.serializer(),
        ).map { }
}
