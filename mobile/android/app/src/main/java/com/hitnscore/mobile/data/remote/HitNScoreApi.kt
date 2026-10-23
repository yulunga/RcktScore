package com.hitnscore.mobile.data.remote

import com.hitnscore.mobile.data.model.Dashboard
import com.hitnscore.mobile.data.model.DashboardResponseData
import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchResponseData
import com.hitnscore.mobile.data.model.NotificationListResponseData
import com.hitnscore.mobile.data.model.NotificationReadRequest
import com.hitnscore.mobile.data.model.NotificationReadResponseData
import com.hitnscore.mobile.data.model.OrganizationSettings
import com.hitnscore.mobile.data.model.OrganizationSettingsResponseData
import com.hitnscore.mobile.data.model.AppNotification
import com.hitnscore.mobile.core.network.ApiClient
import com.hitnscore.mobile.data.model.CreateMatchRequest
import com.hitnscore.mobile.data.model.EndMatchRequest
import com.hitnscore.mobile.data.model.EventActionRequest
import com.hitnscore.mobile.data.model.MatchIdRequest
import com.hitnscore.mobile.data.model.MatchSetupLookupResponseData
import com.hitnscore.mobile.data.model.MatchSetupLookups
import com.hitnscore.mobile.data.model.ScorePointRequest
import java.net.URLEncoder
import com.hitnscore.mobile.core.network.ApiResult

/** Read-only backend calls for M2. An interface so ViewModels can be tested with fakes. */
interface HitNScoreApi {
    suspend fun dashboard(organizationId: Int): ApiResult<Dashboard>
    suspend fun match(matchId: String): ApiResult<MatchDetail>
    suspend fun notifications(organizationId: Int): ApiResult<List<AppNotification>>
    suspend fun markNotificationRead(notificationId: String, organizationId: Int): ApiResult<Boolean>
    suspend fun organizationSettings(organizationId: Int): ApiResult<OrganizationSettings>

    // Match setup and scoring (M3). Every call returns the server's updated match.
    suspend fun setupLookup(organizationId: Int, query: String): ApiResult<MatchSetupLookups>
    suspend fun createMatch(request: CreateMatchRequest): ApiResult<MatchDetail>
    suspend fun startScheduledMatch(matchId: String): ApiResult<MatchDetail>
    suspend fun scorePoint(request: ScorePointRequest): ApiResult<MatchDetail>
    suspend fun eventAction(request: EventActionRequest): ApiResult<MatchDetail>
    suspend fun undo(request: MatchIdRequest): ApiResult<MatchDetail>
    suspend fun endMatch(request: EndMatchRequest): ApiResult<MatchDetail>
}

class RemoteHitNScoreApi(private val client: ApiClient) : HitNScoreApi {

    override suspend fun dashboard(organizationId: Int): ApiResult<Dashboard> =
        // Same generous limits as iOS so Matches and History have the full list.
        client.get(
            "dashboard/$organizationId?active_limit=$ACTIVE_LIMIT&recent_limit=$RECENT_LIMIT",
            DashboardResponseData.serializer(),
        ).map { it.dashboard }

    override suspend fun match(matchId: String): ApiResult<MatchDetail> =
        client.get("get_score/$matchId", MatchResponseData.serializer()).map { it.match }

    override suspend fun notifications(organizationId: Int): ApiResult<List<AppNotification>> =
        client.get("notifications/$organizationId", NotificationListResponseData.serializer())
            .map { it.notifications }

    override suspend fun markNotificationRead(notificationId: String, organizationId: Int): ApiResult<Boolean> =
        client.post(
            path = "notifications/$notificationId/read",
            body = NotificationReadRequest(organizationId),
            bodySerializer = NotificationReadRequest.serializer(),
            deserializer = NotificationReadResponseData.serializer(),
        ).map { it.read }

    override suspend fun organizationSettings(organizationId: Int): ApiResult<OrganizationSettings> =
        client.get("organization_settings/$organizationId", OrganizationSettingsResponseData.serializer())
            .map { it.organizationSettings }

    override suspend fun setupLookup(organizationId: Int, query: String): ApiResult<MatchSetupLookups> =
        client.get(
            "match_setup_lookup/$organizationId?q=${URLEncoder.encode(query, Charsets.UTF_8.name())}",
            MatchSetupLookupResponseData.serializer(),
        ).map { it.lookups }

    override suspend fun createMatch(request: CreateMatchRequest): ApiResult<MatchDetail> =
        client.post("start_match", request, CreateMatchRequest.serializer(), MatchResponseData.serializer()).map { it.match }

    override suspend fun startScheduledMatch(matchId: String): ApiResult<MatchDetail> =
        client.post("start_scheduled_match", MatchIdRequest(matchId), MatchIdRequest.serializer(), MatchResponseData.serializer())
            .map { it.match }

    override suspend fun scorePoint(request: ScorePointRequest): ApiResult<MatchDetail> =
        client.post("score_point", request, ScorePointRequest.serializer(), MatchResponseData.serializer()).map { it.match }

    override suspend fun eventAction(request: EventActionRequest): ApiResult<MatchDetail> =
        client.post("event_action", request, EventActionRequest.serializer(), MatchResponseData.serializer()).map { it.match }

    override suspend fun undo(request: MatchIdRequest): ApiResult<MatchDetail> =
        client.post("undo_action", request, MatchIdRequest.serializer(), MatchResponseData.serializer()).map { it.match }

    override suspend fun endMatch(request: EndMatchRequest): ApiResult<MatchDetail> =
        client.post("end_match", request, EndMatchRequest.serializer(), MatchResponseData.serializer()).map { it.match }

    private companion object {
        const val ACTIVE_LIMIT = 200
        const val RECENT_LIMIT = 1000
    }
}

inline fun <T, R> ApiResult<T>.map(transform: (T) -> R): ApiResult<R> = when (this) {
    is ApiResult.Success -> ApiResult.Success(transform(value))
    is ApiResult.Failure -> this
}
