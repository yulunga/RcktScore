package com.hitnscore.mobile.core.auth

import com.hitnscore.mobile.core.network.ApiClient
import com.hitnscore.mobile.core.network.ApiResult
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** `POST /feedback` ("Ping Us", as iOS): the backend emails the message to the HitnScore team. */
@Serializable
data class FeedbackRequest(
    val name: String,
    val email: String,
    val category: String,
    val message: String,
    val username: String = "",
    @SerialName("organization_name") val organizationName: String = "",
    val version: String,
    val build: String,
    @SerialName("page_url") val pageUrl: String,
    @SerialName("user_agent") val userAgent: String,
)

@Serializable
data class FeedbackResponse(val accepted: Boolean = false)

interface FeedbackService {
    suspend fun submit(request: FeedbackRequest): ApiResult<FeedbackResponse>
}

class RemoteFeedbackService(private val apiClient: ApiClient) : FeedbackService {
    override suspend fun submit(request: FeedbackRequest) =
        apiClient.post(
            path = "feedback",
            body = request,
            bodySerializer = FeedbackRequest.serializer(),
            deserializer = FeedbackResponse.serializer(),
        )
}
