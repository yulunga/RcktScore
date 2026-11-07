package com.hitnscore.mobile.data.remote

import com.hitnscore.mobile.core.network.ApiClient
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.data.model.CourtRequest
import com.hitnscore.mobile.data.model.CourtResponseData
import com.hitnscore.mobile.data.model.CourtSummary
import com.hitnscore.mobile.data.model.CreateOrganizationUserRequest
import com.hitnscore.mobile.data.model.DeletePersonalAccountRequest
import com.hitnscore.mobile.data.model.DeletedResponseData
import com.hitnscore.mobile.data.model.OrganizationDetailsRequest
import com.hitnscore.mobile.data.model.OrganizationIdRequest
import com.hitnscore.mobile.data.model.OrganizationSettings
import com.hitnscore.mobile.data.model.OrganizationSettingsResponseData
import com.hitnscore.mobile.data.model.OrganizationUser
import com.hitnscore.mobile.data.model.OrganizationUserResponseData
import com.hitnscore.mobile.data.model.PersonalProfileRequest
import com.hitnscore.mobile.data.model.UpdateOrganizationUserRequest

/**
 * Settings changes (M6), the same routes iOS and the web use. Every route is authorised
 * on the server: club pages need an admin session; profile and deletion act on the
 * signed-in person only.
 */
interface SettingsApi {
    suspend fun updateProfile(organizationId: Int, request: PersonalProfileRequest): ApiResult<OrganizationSettings>
    suspend fun deletePersonalAccount(organizationId: Int): ApiResult<Boolean>
    suspend fun updateOrganization(organizationId: Int, request: OrganizationDetailsRequest): ApiResult<OrganizationSettings>
    suspend fun createUser(request: CreateOrganizationUserRequest): ApiResult<OrganizationUser>
    suspend fun updateUser(userId: Int, request: UpdateOrganizationUserRequest): ApiResult<OrganizationUser>
    suspend fun deleteUser(userId: Int, organizationId: Int): ApiResult<Boolean>
    suspend fun createCourt(request: CourtRequest): ApiResult<CourtSummary>
    suspend fun updateCourt(courtId: Int, request: CourtRequest): ApiResult<CourtSummary>
    suspend fun deleteCourt(courtId: Int, organizationId: Int): ApiResult<Boolean>
    suspend fun newDisplayCode(courtId: Int, organizationId: Int): ApiResult<CourtSummary>
}

class RemoteSettingsApi(private val client: ApiClient) : SettingsApi {
    override suspend fun updateProfile(organizationId: Int, request: PersonalProfileRequest) =
        client.put("personal_profile/$organizationId", request, PersonalProfileRequest.serializer(), OrganizationSettingsResponseData.serializer())
            .map { it.organizationSettings }

    override suspend fun deletePersonalAccount(organizationId: Int) =
        client.delete(
            "personal_account/$organizationId",
            DeletePersonalAccountRequest(DeletePersonalAccountRequest.CONFIRMATION_TEXT),
            DeletePersonalAccountRequest.serializer(),
            DeletedResponseData.serializer(),
        ).map { it.deleted }

    override suspend fun updateOrganization(organizationId: Int, request: OrganizationDetailsRequest) =
        client.put("organization_details/$organizationId", request, OrganizationDetailsRequest.serializer(), OrganizationSettingsResponseData.serializer())
            .map { it.organizationSettings }

    override suspend fun createUser(request: CreateOrganizationUserRequest) =
        client.post("organization_users", request, CreateOrganizationUserRequest.serializer(), OrganizationUserResponseData.serializer())
            .map { it.user }

    override suspend fun updateUser(userId: Int, request: UpdateOrganizationUserRequest) =
        client.put("organization_users/$userId", request, UpdateOrganizationUserRequest.serializer(), OrganizationUserResponseData.serializer())
            .map { it.user }

    override suspend fun deleteUser(userId: Int, organizationId: Int) =
        client.delete("organization_users/$userId", OrganizationIdRequest(organizationId), OrganizationIdRequest.serializer(), DeletedResponseData.serializer())
            .map { it.deleted }

    override suspend fun createCourt(request: CourtRequest) =
        client.post("organization_courts", request, CourtRequest.serializer(), CourtResponseData.serializer()).map { it.court }

    override suspend fun updateCourt(courtId: Int, request: CourtRequest) =
        client.put("organization_courts/$courtId", request, CourtRequest.serializer(), CourtResponseData.serializer()).map { it.court }

    override suspend fun deleteCourt(courtId: Int, organizationId: Int) =
        client.delete("organization_courts/$courtId", OrganizationIdRequest(organizationId), OrganizationIdRequest.serializer(), DeletedResponseData.serializer())
            .map { it.deleted }

    override suspend fun newDisplayCode(courtId: Int, organizationId: Int) =
        client.post(
            "organization_courts/$courtId/display-code",
            OrganizationIdRequest(organizationId),
            OrganizationIdRequest.serializer(),
            CourtResponseData.serializer(),
        ).map { it.court }
}
