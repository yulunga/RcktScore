package com.hitnscore.mobile.core.auth

import com.hitnscore.mobile.core.network.ApiError
import com.hitnscore.mobile.core.network.ApiResponseParser
import com.hitnscore.mobile.core.network.ApiResult
import java.time.Instant
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AuthModelsTest {
    private val json = Json { ignoreUnknownKeys = true }
    private val parser = ApiResponseParser(json)

    @Test
    fun decodesIdentityFirstSession() {
        val data = (parser.parse(200, LoginFixtures.identityFirstSession, LoginResponseData.serializer())
            as ApiResult.Success).value
        val session = assertNotNullAndGet(data.session)
        assertEquals("token-abc", session.sessionToken)
        assertEquals(2, session.availableMemberships?.size)
        assertTrue(session.toMembership().isPersonal)
        assertNull(data.organizationSelection)
    }

    @Test
    fun decodesLegacyOrganizationSelection() {
        val data = (parser.parse(200, LoginFixtures.organizationSelection, LoginResponseData.serializer())
            as ApiResult.Success).value
        val selection = assertNotNullAndGet(data.organizationSelection)
        assertEquals("token-xyz", selection.sessionToken)
        assertFalse(selection.memberships.last().isPersonal)
    }

    @Test
    fun conflictIsAServerErrorWithItsCode() {
        val error = (parser.parse(409, LoginFixtures.activeSessionConflict, LoginResponseData.serializer())
            as ApiResult.Failure).error as ApiError.Server
        assertEquals("ACTIVE_SESSION_EXISTS", error.code)
    }

    @Test
    fun loginRequestUsesTheMobileClientTypeAndSnakeCase() {
        val body = json.encodeToString(
            LoginRequest.serializer(),
            LoginRequest("a@b.com", "pw", LoginRequest.MOBILE_CLIENT_TYPE, forceLogoutOther = true),
        )
        assertTrue(body.contains("\"client_type\":\"mobile_app\""))
        assertTrue(body.contains("\"force_logout_other\":true"))
    }

    @Test
    fun expiryParsingAcceptsBackendFormats() {
        val now = Instant.parse("2026-10-23T12:00:00Z")
        fun session(expiry: String) = StoredSession("t", expiry, "u", membership, listOf(membership))
        assertFalse(session("2026-10-30T12:00:00.123456+00:00").isExpired(now))
        assertFalse(session("2026-10-30T12:00:00Z").isExpired(now))
        assertFalse(session("2026-10-30T12:00:00.123456").isExpired(now))
        assertTrue(session("2026-10-23T11:59:59+00:00").isExpired(now))
        assertTrue(session("not a date").isExpired(now))
    }

    private val membership = UserMembership(1, "u", "admin", 50001, "Me", "personal")

    private fun <T> assertNotNullAndGet(value: T?): T {
        assertNotNull(value)
        return value!!
    }
}
