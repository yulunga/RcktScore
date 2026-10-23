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
import com.hitnscore.mobile.core.network.ApiResult

/** Read-only backend calls for M2. An interface so ViewModels can be tested with fakes. */
interface HitNScoreApi {
    suspend fun dashboard(organizationId: Int): ApiResult<Dashboard>
    suspend fun match(matchId: String): ApiResult<MatchDetail>
    suspend fun notifications(organizationId: Int): ApiResult<List<AppNotification>>
    suspend fun markNotificationRead(notificationId: String, organizationId: Int): ApiResult<Boolean>
    suspend fun organizationSettings(organizationId: Int): ApiResult<OrganizationSettings>
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

    private companion object {
        const val ACTIVE_LIMIT = 200
        const val RECENT_LIMIT = 1000
    }
}

inline fun <T, R> ApiResult<T>.map(transform: (T) -> R): ApiResult<R> = when (this) {
    is ApiResult.Success -> ApiResult.Success(transform(value))
    is ApiResult.Failure -> this
}
