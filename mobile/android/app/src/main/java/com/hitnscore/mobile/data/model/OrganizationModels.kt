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
)

@Serializable
data class OrganizationUser(
    val id: Int,
    val username: String = "",
    val role: String = "user",
    val status: String = "approved",
    @SerialName("first_name") val firstName: String = "",
    val surname: String = "",
)

@Serializable
data class CourtSummary(
    val id: Int,
    @SerialName("court_name") val courtName: String = "",
    @SerialName("court_alias") val courtAlias: String = "",
    val sport: String? = null,
    @SerialName("display_code_enabled") val displayCodeEnabled: Boolean = false,
)
