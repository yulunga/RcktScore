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
            get() = networkMessage(cause)
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

/**
 * A plainer reason for the common no-response failures, so a device that cannot connect
 * (wrong clock, no internet on the Wi-Fi, DNS blocked) says why. Debug builds add the
 * exception type to help diagnose a particular device.
 */
internal fun networkMessage(cause: Throwable): String {
    val chain = generateSequence(cause) { it.cause }.take(6).toList()
    val text = when {
        chain.any { it is javax.net.ssl.SSLException || it is java.security.cert.CertificateException } ->
            "Can't make a secure connection to HitnScore. Check this device's date and time are set automatically, then try again."
        chain.any { it is java.net.UnknownHostException } ->
            "Can't find HitnScore. Check this device is online (open a website in Chrome) and that Private DNS is off or Automatic, then try again."
        chain.any { it is java.net.SocketTimeoutException } ->
            "HitnScore took too long to answer. Check your connection and try again."
        else -> "Can't reach HitnScore. Check your connection and try again."
    }
    return if (com.hitnscore.mobile.core.config.AppEnvironment.isProduction) {
        text
    } else {
        "$text (${cause.javaClass.simpleName}: ${cause.message.orEmpty().take(120)})"
    }
}
