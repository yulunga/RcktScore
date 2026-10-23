package com.hitnscore.mobile.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.nullable
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ApiResponseParserTest {
    @Serializable
    private data class MatchStub(
        @SerialName("match_id") val matchId: Int,
        @SerialName("sport_type") val sportType: String,
    )

    private val parser = ApiResponseParser(Json { ignoreUnknownKeys = true })

    @Test
    fun decodesSnakeCaseDataFromASuccessEnvelope() {
        val body = """{"success":true,"data":{"match_id":7,"sport_type":"squash","extra":1},"error":null,"meta":{}}"""
        val result = parser.parse(200, body, MatchStub.serializer())
        assertEquals(ApiResult.Success(MatchStub(7, "squash")), result)
    }

    @Test
    fun mapsAnErrorEnvelopeToServerError() {
        val body = """{"success":false,"data":null,"error":{"code":"COURT_BUSY","message":"Court 2 is in use"},"meta":{}}"""
        val error = (parser.parse(409, body, MatchStub.serializer()) as ApiResult.Failure).error
        assertTrue(error is ApiError.Server)
        error as ApiError.Server
        assertEquals(409, error.httpStatus)
        assertEquals("COURT_BUSY", error.code)
        assertEquals("Court 2 is in use", error.message)
    }

    @Test
    fun treatsSessionCodesAsSessionInvalid() {
        ApiError.sessionInvalidationCodes.forEach { code ->
            val body = """{"success":false,"error":{"code":"$code","message":"Signed out"}}"""
            val error = (parser.parse(401, body, MatchStub.serializer()) as ApiResult.Failure).error
            assertEquals(ApiError.SessionInvalid(code, "Signed out"), error)
        }
    }

    @Test
    fun mapsANonJsonGatewayErrorToServerError() {
        val error = (parser.parse(502, "<html>Bad Gateway</html>", MatchStub.serializer()) as ApiResult.Failure).error
        assertEquals("HTTP_502", (error as ApiError.Server).code)
    }

    @Test
    fun reportsDecodingErrorForAMismatchedSuccessBody() {
        val body = """{"success":true,"data":{"match_id":"not a number","sport_type":"squash"}}"""
        val error = (parser.parse(200, body, MatchStub.serializer()) as ApiResult.Failure).error
        assertTrue(error is ApiError.Decoding)
    }

    @Test
    fun allowsMissingDataWithANullableSerializer() {
        val result = parser.parse(200, """{"success":true}""", MatchStub.serializer().nullable)
        assertNull((result as ApiResult.Success).value)
    }

    @Test
    fun keepsErrorDetailsWhenPresent() {
        val body = """{"success":false,"error":{"code":"VALIDATION","message":"Bad input","details":{"field":"court_id"}}}"""
        val error = (parser.parse(400, body, MatchStub.serializer()) as ApiResult.Failure).error as ApiError.Server
        assertTrue(error.details.toString().contains("court_id"))
    }
}
