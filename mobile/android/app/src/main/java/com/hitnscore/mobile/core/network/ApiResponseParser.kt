package com.hitnscore.mobile.core.network

import kotlinx.serialization.DeserializationStrategy
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull

/** Turns an HTTP status and body into an [ApiResult]. Pure, so it is unit-tested directly. */
class ApiResponseParser(private val json: Json) {

    fun <T> parse(
        httpStatus: Int,
        body: String,
        deserializer: DeserializationStrategy<T>,
    ): ApiResult<T> {
        val isHttpSuccess = httpStatus in 200..299
        val envelope = try {
            json.decodeFromString(ApiEnvelope.serializer(), body)
        } catch (e: IllegalArgumentException) {
            // Not an envelope: an API Gateway error page, an empty body, or a proxy response.
            return ApiResult.Failure(
                if (isHttpSuccess) {
                    ApiError.Decoding(e)
                } else {
                    ApiError.Server(
                        httpStatus = httpStatus,
                        code = "HTTP_$httpStatus",
                        message = "The server returned an unexpected response ($httpStatus).",
                    )
                },
            )
        }

        if (!envelope.success || !isHttpSuccess) {
            val error = envelope.error ?: ApiErrorBody(code = "HTTP_$httpStatus")
            return ApiResult.Failure(
                if (error.code in ApiError.sessionInvalidationCodes) {
                    ApiError.SessionInvalid(error.code, error.message)
                } else {
                    ApiError.Server(httpStatus, error.code, error.message, error.details)
                },
            )
        }

        return try {
            ApiResult.Success(json.decodeFromJsonElement(deserializer, envelope.data ?: JsonNull))
        } catch (e: IllegalArgumentException) {
            ApiResult.Failure(ApiError.Decoding(e))
        }
    }
}
