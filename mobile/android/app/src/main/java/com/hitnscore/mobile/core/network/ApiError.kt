package com.hitnscore.mobile.core.network

import java.io.IOException
import kotlinx.serialization.json.JsonElement

/** Result of one API call. Screens map [ApiResult.Failure] to a message; they never throw. */
sealed interface ApiResult<out T> {
    data class Success<out T>(val value: T) : ApiResult<T>
    data class Failure(val error: ApiError) : ApiResult<Nothing>
}

sealed interface ApiError {
    val message: String

    /** The backend ended this session. The app must clear the token and return to sign-in. */
    data class SessionInvalid(val code: String, override val message: String) : ApiError

    /** The backend answered with `success: false`, or a non-2xx status. */
    data class Server(
        val httpStatus: Int,
        val code: String,
        override val message: String,
        val details: JsonElement? = null,
    ) : ApiError

    /** No response: offline, DNS failure, timeout, TLS failure. */
    data class Network(val cause: IOException) : ApiError {
        override val message: String
            get() = "Can't reach HitNScore. Check your connection and try again."
    }

    /** A 2xx response whose body did not match the expected model. */
    data class Decoding(val cause: Throwable) : ApiError {
        override val message: String
            get() = "The server response could not be read."
    }

    companion object {
        const val UNKNOWN_CODE = "UNKNOWN_ERROR"
        const val GENERIC_MESSAGE = "Something went wrong. Please try again."

        /** Same set the iOS client treats as a forced sign-out. */
        val sessionInvalidationCodes: Set<String> = setOf(
            "SESSION_REQUIRED",
            "SESSION_INVALID",
            "SESSION_REPLACED",
            "SESSION_EXPIRED",
        )
    }
}
