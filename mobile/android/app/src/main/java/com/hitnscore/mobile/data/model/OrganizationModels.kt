package com.hitnscore.mobile.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class OrganizationSettingsResponseData(
    // The backend sends this key in camelCase.
    val organizationSettings: OrganizationSettings,
)

/** `GET /organization_settings/{organization_id}` (club admins). */
@Serializable
data class OrganizationSettings(
    val organization: OrganizationProfile,
    val users: List<OrganizationUser> = emptyList(),
    val courts: List<CourtSummary> = emptyList(),
)

@Serializable
data class OrganizationProfile(
    val id: Int,
    @SerialName("organization_name") val organizationName: String = "",
    @SerialName("org_address") val address: String = "",
    @SerialName("org_postcode") val postcode: String = "",
    @SerialName("org_contact") val contact: String = "",
    @SerialName("org_telephone") val telephone: String = "",
    @SerialName("org_email") val email: String = "",
    @SerialName("org_webaddress") val webAddress: String = "",
    @SerialName("org_type") val type: String = "club",
    val plan: String? = null,
    @SerialName("enabled_sports") val enabledSports: List<String> = listOf("squash", "racketball", "tennis"),
    /** Per sport: whether timed warm-up and breaks are on by default. */
    @SerialName("timed_break_defaults") val timedBreakDefaults: Map<String, Boolean> = emptyMap(),
    /** Facebook, Instagram, X, YouTube links (empty until the backend stores them). */
    @SerialName("social_profiles") val socialProfiles: Map<String, String> = emptyMap(),
)

@Serializable
data class OrganizationUser(
    val id: Int,
    val username: String = "",
    val email: String = "",
    /** `admin`, `scorer` or `read_only` (legacy `user` is treated as `scorer`). */
    val role: String = "scorer",
    /** `approved`, or `pending` until the invited person sets their password. */
    val status: String = "approved",
    @SerialName("first_name") val firstName: String = "",
    val surname: String = "",
    val country: String = "",
    val telephone: String = "",
    @SerialName("city_location") val cityLocation: String = "",
)

@Serializable
data class CourtSummary(
    val id: Int,
    @SerialName("court_name") val courtName: String = "",
    @SerialName("court_alias") val courtAlias: String = "",
    val sport: String? = null,
    @SerialName("display_code_enabled") val displayCodeEnabled: Boolean = false,
    /** The scoreboard screen code. Sent to club admins only. */
    @SerialName("display_code") val displayCode: String? = null,
)

/** Club roles, as `backend/common/access_control.py`. */
object ClubRoles {
    const val ADMIN = "admin"
    const val SCORER = "scorer"
    const val READ_ONLY = "read_only"
    val all = listOf(ADMIN, SCORER, READ_ONLY)

    fun normalize(role: String?): String = when (role?.trim()?.lowercase()) {
        ADMIN -> ADMIN
        READ_ONLY, "read-only", "readonly" -> READ_ONLY
        else -> SCORER
    }

    fun canManageMatches(role: String?): Boolean = normalize(role) != READ_ONLY
}

// Settings requests (M6). Null fields are left out of the JSON and left unchanged.

/** `PUT /personal_profile/{organization_id}`. Changing [email] signs out every device. */
@Serializable
data class PersonalProfileRequest(
    @SerialName("first_name") val firstName: String,
    val surname: String,
    val email: String,
    val telephone: String,
    val country: String,
    @SerialName("city_location") val cityLocation: String,
)

/** `PUT /organization_details/{organization_id}` (club admins). */
@Serializable
data class OrganizationDetailsRequest(
    @SerialName("organization_name") val organizationName: String? = null,
    @SerialName("org_address") val address: String? = null,
    @SerialName("org_postcode") val postcode: String? = null,
    @SerialName("org_contact") val contact: String? = null,
    @SerialName("org_telephone") val telephone: String? = null,
    @SerialName("org_email") val email: String? = null,
    @SerialName("org_webaddress") val webAddress: String? = null,
    @SerialName("enabled_sports") val enabledSports: List<String>? = null,
    @SerialName("timed_break_defaults") val timedBreakDefaults: Map<String, Boolean>? = null,
    /** Facebook, Instagram, X and YouTube links; "" for a profile that is switched off. */
    @SerialName("social_profiles") val socialProfiles: Map<String, String>? = null,
)

/** `DELETE /personal_account/{organization_id}`. */
@Serializable
data class DeletePersonalAccountRequest(
    // No default: a value equal to its default would be left out of the JSON.
    val confirmation: String,
) {
    companion object {
        const val CONFIRMATION_TEXT = "DELETE MY ACCOUNT"
    }
}

/** `POST /organization_users`: invites the person by email; they set their own password. */
@Serializable
data class CreateOrganizationUserRequest(
    @SerialName("organization_id") val organizationId: Int,
    val username: String,
    val role: String,
    @SerialName("first_name") val firstName: String,
    val surname: String,
)

/** `PUT /organization_users/{user_id}`. Passwords can't be set here; send a reset email instead. */
@Serializable
data class UpdateOrganizationUserRequest(
    @SerialName("organization_id") val organizationId: Int,
    val username: String? = null,
    val role: String? = null,
    @SerialName("first_name") val firstName: String? = null,
    val surname: String? = null,
)

/** Body for deletes and display codes, which only need the organisation. */
@Serializable
data class OrganizationIdRequest(@SerialName("organization_id") val organizationId: Int)

/** `POST /organization_courts` and `PUT /organization_courts/{court_id}`. A null [sport] means any sport. */
@Serializable
data class CourtRequest(
    @SerialName("organization_id") val organizationId: Int,
    @SerialName("court_name") val courtName: String,
    @SerialName("court_alias") val courtAlias: String,
    // No default, so null is sent and clears the court's sport.
    val sport: String?,
)

@Serializable
data class OrganizationUserResponseData(val user: OrganizationUser)

@Serializable
data class CourtResponseData(
    val court: CourtSummary,
    val organizationSettings: OrganizationSettings? = null,
)

@Serializable
data class ScoreboardPairingApprovalRequest(
    @SerialName("organization_id") val organizationId: Int,
    val token: String,
)

@Serializable
data class ScoreboardPairingApproval(val approved: Boolean = false)

@Serializable
data class ScoreboardPairingApprovalData(val pairing: ScoreboardPairingApproval)

@Serializable
data class DeletedResponseData(val deleted: Boolean = false)

@Serializable
data class ProfileImagePayload(
    val available: Boolean = false,
    val url: String? = null,
    val version: String? = null,
)

@Serializable
data class ProfileImageResponseData(@SerialName("profile_image") val profileImage: ProfileImagePayload)

@Serializable
data class ProfileImageUploadPayload(
    val url: String,
    val fields: Map<String, String>,
    @SerialName("object_key") val objectKey: String,
    @SerialName("content_type") val contentType: String,
    @SerialName("max_bytes") val maxBytes: Int,
)

@Serializable
data class ProfileImageUploadResponseData(val upload: ProfileImageUploadPayload)

@Serializable
data class CompleteProfileImageRequest(@SerialName("object_key") val objectKey: String)

@Serializable
data object EmptyRequest
