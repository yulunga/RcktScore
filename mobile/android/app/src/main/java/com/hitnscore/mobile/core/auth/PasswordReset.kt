package com.hitnscore.mobile.core.auth

import android.net.Uri
import com.hitnscore.mobile.core.network.ApiClient
import com.hitnscore.mobile.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * A secure link from a HitnScore email, e.g.
 * `https://app.hitnscore.com/help?mode=reset&token=…` (password reset) or
 * `…/help?mode=confirm-email&token=setup_…` (new account: confirm email and create a password).
 */
data class PasswordLink(val token: String, val isAccountSetup: Boolean) {
    companion object {
        private val HOSTS = setOf("app.hitnscore.com")
        private const val MIN_TOKEN_LENGTH = 16

        /** The link the app was opened with, or null when it is not a password link. */
        fun from(uri: Uri?): PasswordLink? {
            uri ?: return null
            if (!uri.scheme.equals("https", ignoreCase = true)) return null
            if (uri.host?.lowercase() !in HOSTS) return null
            if (uri.path?.trimEnd('/')?.lowercase() != "/help") return null
            return build(uri.getQueryParameter("mode"), uri.getQueryParameter("token"))
        }

        /**
         * A link pasted by the user (when the email opened in a browser). Accepts the whole
         * address or just the query part; does not need Android's [Uri] so it is unit-testable.
         */
        fun fromText(text: String): PasswordLink? {
            val trimmed = text.trim()
            // Just the token on its own, copied from the link.
            if ('=' !in trimmed && '?' !in trimmed && '/' !in trimmed && trimmed.length >= MIN_TOKEN_LENGTH && trimmed.none(Char::isWhitespace)) {
                return build(null, trimmed)
            }
            val query = text.trim().substringAfter('?', missingDelimiterValue = text.trim()).substringBefore('#')
            val params = query.split('&').mapNotNull { pair ->
                val key = pair.substringBefore('=', missingDelimiterValue = "")
                if (key.isEmpty()) null else key to java.net.URLDecoder.decode(pair.substringAfter('='), Charsets.UTF_8.name())
            }.toMap()
            return build(params["mode"], params["token"])
        }

        internal fun build(mode: String?, token: String?): PasswordLink? {
            val cleanToken = token?.trim().orEmpty()
            if (cleanToken.isEmpty()) return null
            val setup = mode == "confirm-email" || cleanToken.startsWith("setup_")
            if (mode != null && mode != "reset" && mode != "confirm-email") return null
            return PasswordLink(cleanToken, isAccountSetup = setup)
        }
    }
}

/** Holds a link that arrived while the app was opening, until the set-password screen takes it. */
class PasswordLinkInbox {
    private val mutable = MutableStateFlow<PasswordLink?>(null)
    val pending: StateFlow<PasswordLink?> = mutable.asStateFlow()

    fun deliver(link: PasswordLink?) {
        if (link != null) mutable.value = link
    }

    fun clear() {
        mutable.value = null
    }
}

/**
 * The same password rules the backend enforces (`backend/common/password_policy.py`) and the
 * web shows (`frontend/src/utils/passwordPolicy.js`), checked as the user types.
 */
object PasswordPolicy {
    const val MIN_LENGTH = 8
    private val COMMON_TERMS = listOf(
        "password", "passw0rd", "qwerty", "welcome", "letmein", "changeme", "admin", "login", "secret", "abc123", "hitnscore",
    )

    enum class Rule { Length, Uppercase, Number, Symbol, NotCommon }

    fun unmet(password: String): List<Rule> {
        val normalized = password.lowercase().replace(Regex("[^a-z0-9]"), "")
        return buildList {
            if (password.length < MIN_LENGTH) add(Rule.Length)
            if (!password.any { it in 'A'..'Z' }) add(Rule.Uppercase)
            if (!password.any { it.isDigit() }) add(Rule.Number)
            if (!Regex("[^A-Za-z0-9\\s]").containsMatchIn(password)) add(Rule.Symbol)
            if (password.isEmpty() || COMMON_TERMS.any { it in normalized }) add(Rule.NotCommon)
        }
    }

    fun isValid(password: String): Boolean = unmet(password).isEmpty()
}

@Serializable
data class PasswordTokenRequest(val token: String)

@Serializable
data class PasswordConfirmRequest(val token: String, val password: String)

@Serializable
data class PasswordValidateResponse(val valid: Boolean = false)

@Serializable
data class PasswordConfirmResponse(@SerialName("reset") val reset: Boolean = false)

/** `POST /password_reset/validate` and `POST /password_reset/confirm` (no session needed). */
interface PasswordResetService {
    suspend fun validate(token: String): ApiResult<PasswordValidateResponse>
    suspend fun confirm(token: String, password: String): ApiResult<PasswordConfirmResponse>
}

class RemotePasswordResetService(private val apiClient: ApiClient) : PasswordResetService {
    override suspend fun validate(token: String) = apiClient.post(
        path = "password_reset/validate",
        body = PasswordTokenRequest(token),
        bodySerializer = PasswordTokenRequest.serializer(),
        deserializer = PasswordValidateResponse.serializer(),
    )

    override suspend fun confirm(token: String, password: String) = apiClient.post(
        path = "password_reset/confirm",
        body = PasswordConfirmRequest(token, password),
        bodySerializer = PasswordConfirmRequest.serializer(),
        deserializer = PasswordConfirmResponse.serializer(),
    )
}
