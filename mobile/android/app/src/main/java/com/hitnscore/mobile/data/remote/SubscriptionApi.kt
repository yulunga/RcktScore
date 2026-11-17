package com.hitnscore.mobile.data.remote

import com.hitnscore.mobile.core.network.ApiClient
import com.hitnscore.mobile.core.network.ApiResult
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** `GET /subscriptions/google/context/{organization_id}`: who is buying and which yearly plan. */
@Serializable
data class GooglePlayPurchaseContext(
    @SerialName("organization_id") val organizationId: Int,
    /** Passed to Play as the obfuscated account ID; the backend matches it on every verification. */
    @SerialName("obfuscated_account_id") val obfuscatedAccountId: String,
    @SerialName("current_plan") val currentPlan: String = "personal_free",
    @SerialName("purchases_enabled") val purchasesEnabled: Boolean = false,
    @SerialName("product_id") val productId: String,
    @SerialName("base_plan_id") val basePlanId: String,
)

@Serializable
private data class GooglePlayContextResponse(
    @SerialName("googlePlaySubscriptionContext") val context: GooglePlayPurchaseContext,
)

@Serializable
private data class GooglePlayVerifyRequest(
    @SerialName("organization_id") val organizationId: Int,
    @SerialName("purchase_token") val purchaseToken: String,
)

@Serializable
data class GooglePlayVerifiedSubscription(
    @SerialName("current_plan") val currentPlan: String,
    val status: String,
    @SerialName("expires_at") val expiresAt: String? = null,
)

@Serializable
private data class GooglePlayVerifyResponse(
    @SerialName("googlePlaySubscription") val subscription: GooglePlayVerifiedSubscription,
)

class SubscriptionApi(private val client: ApiClient) {
    suspend fun googlePlayContext(organizationId: Int): ApiResult<GooglePlayPurchaseContext> =
        client.get("subscriptions/google/context/$organizationId", GooglePlayContextResponse.serializer())
            .map { it.context }

    /** The server re-reads the token from Google Play, grants Personal Plus and acknowledges it. */
    suspend fun verifyGooglePlay(organizationId: Int, purchaseToken: String): ApiResult<GooglePlayVerifiedSubscription> =
        client.post(
            "subscriptions/google/verify",
            GooglePlayVerifyRequest(organizationId, purchaseToken),
            GooglePlayVerifyRequest.serializer(),
            GooglePlayVerifyResponse.serializer(),
        ).map { it.subscription }
}
