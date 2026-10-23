package com.hitnscore.mobile.core.auth

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Body of `POST /login`. Android uses the shared `mobile_app` client type, like iOS. */
@Serializable
data class LoginRequest(
    val username: String,
    val password: String,
    @SerialName("client_type") val clientType: String,
    @SerialName("force_logout_other") val forceLogoutOther: Boolean,
) {
    companion object {
        const val MOBILE_CLIENT_TYPE = "mobile_app"
    }
}

/** One organisation the user can act in (personal account or club). */
@Serializable
data class UserMembership(
    val id: Int,
    val username: String,
    val role: String,
    @SerialName("organization_id") val organizationId: Int,
    @SerialName("organization_name") val organizationName: String,
    @SerialName("organization_type") val organizationType: String? = null,
    val plan: String? = null,
    @SerialName("enabled_sports") val enabledSports: List<String>? = null,
    @SerialName("first_name") val firstName: String? = null,
    val surname: String? = null,
    @SerialName("full_name") val fullName: String? = null,
    val email: String? = null,
    val country: String? = null,
    val telephone: String? = null,
) {
    val isPersonal: Boolean
        get() = organizationType?.lowercase() == "personal" || organizationId >= PERSONAL_ORGANIZATION_ID_FLOOR

    companion object {
        /** Same rule as iOS `UserSession.isPersonalAccount`. */
        const val PERSONAL_ORGANIZATION_ID_FLOOR = 50_000
    }
}

/** `data.session` from `POST /login`: the chosen membership plus token and all memberships. */
@Serializable
data class LoginSessionPayload(
    val id: Int,
    val username: String,
    val role: String,
    @SerialName("organization_id") val organizationId: Int,
    @SerialName("organization_name") val organizationName: String,
    @SerialName("organization_type") val organizationType: String? = null,
    val plan: String? = null,
    @SerialName("enabled_sports") val enabledSports: List<String>? = null,
    @SerialName("first_name") val firstName: String? = null,
    val surname: String? = null,
    @SerialName("full_name") val fullName: String? = null,
    val email: String? = null,
    val country: String? = null,
    val telephone: String? = null,
    @SerialName("session_token") val sessionToken: String? = null,
    @SerialName("session_expires_at") val sessionExpiresAt: String? = null,
    @SerialName("available_memberships") val availableMemberships: List<UserMembership>? = null,
) {
    fun toMembership() = UserMembership(
        id = id,
        username = username,
        role = role,
        organizationId = organizationId,
        organizationName = organizationName,
        organizationType = organizationType,
        plan = plan,
        enabledSports = enabledSports,
        firstName = firstName,
        surname = surname,
        fullName = fullName,
        email = email,
        country = country,
        telephone = telephone,
    )
}

/** Legacy `data.organizationSelection`, used when the backend's identity-first flag is off. */
@Serializable
data class OrganizationSelectionPayload(
    val username: String,
    val memberships: List<UserMembership>,
    @SerialName("session_token") val sessionToken: String,
    @SerialName("session_expires_at") val sessionExpiresAt: String,
)

@Serializable
data class LoginResponseData(
    val session: LoginSessionPayload? = null,
    // The backend sends this key in camelCase.
    val organizationSelection: OrganizationSelectionPayload? = null,
)

@Serializable
data class PasswordResetRequest(val email: String)

@Serializable
data class AcceptedResponse(
    val accepted: Boolean? = null,
    @SerialName("logged_out") val loggedOut: Boolean? = null,
)

@Serializable
internal class EmptyBody
