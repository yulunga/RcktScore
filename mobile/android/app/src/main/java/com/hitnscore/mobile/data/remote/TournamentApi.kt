package com.hitnscore.mobile.data.remote

import com.hitnscore.mobile.core.network.ApiClient
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.data.model.OrganizationSettings
import com.hitnscore.mobile.data.model.OrganizationSettingsResponseData
import com.hitnscore.mobile.data.model.TournamentListResponseData
import com.hitnscore.mobile.data.model.TournamentSummary

/** Tournament Manager reads used by the Tournaments tab (same routes as iOS). */
interface TournamentApi {
    suspend fun organizationSettings(organizationId: Int): ApiResult<OrganizationSettings>
    suspend fun tournaments(organizationId: Int): ApiResult<List<TournamentSummary>>
}

class RemoteTournamentApi(private val client: ApiClient) : TournamentApi {
    override suspend fun organizationSettings(organizationId: Int) =
        client.get("organization_settings/$organizationId", OrganizationSettingsResponseData.serializer())
            .map { it.organizationSettings }

    override suspend fun tournaments(organizationId: Int) =
        client.get("organizations/$organizationId/tournaments", TournamentListResponseData.serializer())
            .map { it.tournaments }
}
