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
import com.hitnscore.mobile.data.model.CompleteProfileImageRequest
import com.hitnscore.mobile.data.model.EmptyRequest
import com.hitnscore.mobile.data.model.ProfileImagePayload
import com.hitnscore.mobile.data.model.ProfileImageResponseData
import com.hitnscore.mobile.data.model.ProfileImageUploadPayload
import com.hitnscore.mobile.data.model.ProfileImageUploadResponseData
import com.hitnscore.mobile.data.model.ScoreboardPairingApprovalData
import com.hitnscore.mobile.data.model.ScoreboardPairingApprovalRequest
import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

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
    suspend fun approveScoreboardPairing(courtId: Int, organizationId: Int, token: String): ApiResult<Boolean>
    suspend fun getProfileImage(organizationId: Int): ApiResult<ProfileImagePayload>
    suspend fun beginProfileImageUpload(organizationId: Int): ApiResult<ProfileImageUploadPayload>
    suspend fun uploadProfileImage(upload: ProfileImageUploadPayload, jpeg: ByteArray): ApiResult<Unit>
    suspend fun completeProfileImageUpload(organizationId: Int, objectKey: String): ApiResult<ProfileImagePayload>
    suspend fun deleteProfileImage(organizationId: Int): ApiResult<Boolean>
    suspend fun downloadProfileImage(url: String): ApiResult<ByteArray>
}

class RemoteSettingsApi(
    private val client: ApiClient,
    private val externalHttpClient: OkHttpClient,
) : SettingsApi {
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

    override suspend fun approveScoreboardPairing(courtId: Int, organizationId: Int, token: String) =
        client.post(
            "organization_courts/$courtId/scoreboard-pairing",
            ScoreboardPairingApprovalRequest(organizationId, token),
            ScoreboardPairingApprovalRequest.serializer(),
            ScoreboardPairingApprovalData.serializer(),
        ).map { it.pairing.approved }

    override suspend fun getProfileImage(organizationId: Int) =
        client.get("profile_image/$organizationId", ProfileImageResponseData.serializer()).map { it.profileImage }

    override suspend fun beginProfileImageUpload(organizationId: Int) =
        client.post(
            "profile_image/$organizationId/upload",
            EmptyRequest,
            EmptyRequest.serializer(),
            ProfileImageUploadResponseData.serializer(),
        ).map { it.upload }

    override suspend fun uploadProfileImage(upload: ProfileImageUploadPayload, jpeg: ByteArray): ApiResult<Unit> =
        withContext(Dispatchers.IO) {
            try {
                val body = MultipartBody.Builder().setType(MultipartBody.FORM).apply {
                    upload.fields.toSortedMap().forEach { (name, value) -> addFormDataPart(name, value) }
                    addFormDataPart("file", "profile.jpg", jpeg.toRequestBody("image/jpeg".toMediaType()))
                }.build()
                externalHttpClient.newCall(Request.Builder().url(upload.url).post(body).build()).execute().use { response ->
                    if (response.isSuccessful) ApiResult.Success(Unit)
                    else ApiResult.Failure(com.hitnscore.mobile.core.network.ApiError.Server(response.code, "PROFILE_IMAGE_UPLOAD_FAILED", "The compressed image could not be uploaded."))
                }
            } catch (error: IOException) {
                ApiResult.Failure(com.hitnscore.mobile.core.network.ApiError.Network(error))
            }
        }

    override suspend fun completeProfileImageUpload(organizationId: Int, objectKey: String) =
        client.post(
            "profile_image/$organizationId/complete",
            CompleteProfileImageRequest(objectKey),
            CompleteProfileImageRequest.serializer(),
            ProfileImageResponseData.serializer(),
        ).map { it.profileImage }

    override suspend fun deleteProfileImage(organizationId: Int) =
        client.delete("profile_image/$organizationId", DeletedResponseData.serializer()).map { it.deleted }

    override suspend fun downloadProfileImage(url: String): ApiResult<ByteArray> = withContext(Dispatchers.IO) {
        try {
            externalHttpClient.newCall(Request.Builder().url(url).get().build()).execute().use { response ->
                if (response.isSuccessful) ApiResult.Success(response.body.bytes())
                else ApiResult.Failure(com.hitnscore.mobile.core.network.ApiError.Server(response.code, "PROFILE_IMAGE_DOWNLOAD_FAILED", "The profile image could not be downloaded."))
            }
        } catch (error: IOException) {
            ApiResult.Failure(com.hitnscore.mobile.core.network.ApiError.Network(error))
        }
    }
}
