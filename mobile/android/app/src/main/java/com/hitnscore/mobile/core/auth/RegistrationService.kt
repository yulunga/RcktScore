package com.hitnscore.mobile.core.auth

import com.hitnscore.mobile.core.network.ApiClient
import com.hitnscore.mobile.core.network.ApiResult
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * `POST /register_interest`, used by "Want In" on the sign-in screen (iOS `registerInterest`).
 * `use_type = personal` creates a Personal Free account and emails a link to verify the
 * address and set a password; `use_type = club` sends a club enquiry to the HitnScore team.
 */
@Serializable
data class RegisterInterestRequest(
    @SerialName("first_name") val firstName: String,
    val surname: String,
    val email: String,
    @SerialName("use_type") val useType: String,
    @SerialName("club_name") val clubName: String,
    /** Honeypot field: always empty from a real person, so it is never sent. */
    val company: String = "",
    @SerialName("page_url") val pageUrl: String,
    @SerialName("user_agent") val userAgent: String,
    // Club subscription enquiry from Settings › Subscription (as iOS); left out when empty.
    @SerialName("requested_plan") val requestedPlan: String = "",
    @SerialName("club_address") val clubAddress: String = "",
    @SerialName("club_postcode") val clubPostcode: String = "",
    @SerialName("club_email") val clubEmail: String = "",
    @SerialName("club_website") val clubWebsite: String = "",
    @SerialName("club_telephone") val clubTelephone: String = "",
)

@Serializable
data class RegisterInterestResponse(
    val accepted: Boolean = false,
    @SerialName("account_created") val accountCreated: Boolean = false,
)

interface RegistrationService {
    suspend fun registerInterest(request: RegisterInterestRequest): ApiResult<RegisterInterestResponse>
}

class RemoteRegistrationService(private val apiClient: ApiClient) : RegistrationService {
    override suspend fun registerInterest(request: RegisterInterestRequest) =
        apiClient.post(
            path = "register_interest",
            body = request,
            bodySerializer = RegisterInterestRequest.serializer(),
            deserializer = RegisterInterestResponse.serializer(),
        )
}
