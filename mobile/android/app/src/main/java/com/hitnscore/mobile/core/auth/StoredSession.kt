package com.hitnscore.mobile.core.auth

import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeParseException
import kotlinx.serialization.Serializable

/** The signed-in session as kept (encrypted) on the device. */
@Serializable
data class StoredSession(
    val token: String,
    val expiresAt: String,
    val username: String,
    val activeMembership: UserMembership,
    val memberships: List<UserMembership>,
) {
    /** Server-provided expiry. An unreadable expiry counts as expired, as on iOS. */
    fun isExpired(now: Instant): Boolean {
        val expiry = parseExpiry(expiresAt) ?: return true
        return !expiry.isAfter(now)
    }

    val displayName: String
        get() = activeMembership.firstName?.takeIf { it.isNotBlank() }
            ?: activeMembership.fullName?.takeIf { it.isNotBlank() }
            ?: username

    companion object {
        /** Accepts Python `isoformat()` output with or without an offset, and `Z`. */
        fun parseExpiry(value: String): Instant? = try {
            OffsetDateTime.parse(value).toInstant()
        } catch (ignored: DateTimeParseException) {
            try {
                LocalDateTime.parse(value).toInstant(ZoneOffset.UTC)
            } catch (notLocal: DateTimeParseException) {
                null
            }
        }
    }
}
