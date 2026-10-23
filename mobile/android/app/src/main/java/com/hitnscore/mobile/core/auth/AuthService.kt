package com.hitnscore.mobile.core.auth

import com.hitnscore.mobile.core.network.ApiClient
import com.hitnscore.mobile.core.network.ApiResult

/** Backend calls used by sign-in. An interface so the session logic can be unit-tested. */
interface AuthService {
    suspend fun login(username: String, password: String, forceLogoutOther: Boolean): ApiResult<LoginResponseData>

    /** Ends the backend session for [sessionToken]. Best effort: callers ignore failures. */
    suspend fun logout(sessionToken: String): ApiResult<AcceptedResponse>

    suspend fun requestPasswordReset(email: String): ApiResult<AcceptedResponse>
}

class RemoteAuthService(private val apiClient: ApiClient) : AuthService {
    override suspend fun login(username: String, password: String, forceLogoutOther: Boolean) =
        apiClient.post(
            path = "login",
            body = LoginRequest(username, password, LoginRequest.MOBILE_CLIENT_TYPE, forceLogoutOther),
            bodySerializer = LoginRequest.serializer(),
            deserializer = LoginResponseData.serializer(),
        )

    override suspend fun logout(sessionToken: String) =
        apiClient.post(
            path = "logout",
            body = EmptyBody(),
            bodySerializer = EmptyBody.serializer(),
            deserializer = AcceptedResponse.serializer(),
            bearerToken = sessionToken,
        )

    override suspend fun requestPasswordReset(email: String) =
        apiClient.post(
            path = "password_reset/request",
            body = PasswordResetRequest(email),
            bodySerializer = PasswordResetRequest.serializer(),
            deserializer = AcceptedResponse.serializer(),
        )
}
