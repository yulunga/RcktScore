package com.hitnscore.mobile.core.network

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

/**
 * The v2 backend wraps every response as `{ success, data, error, meta }`.
 * `data` stays as raw JSON here so each call can decode it with its own model.
 */
@Serializable
data class ApiEnvelope(
    val success: Boolean,
    val data: JsonElement? = null,
    val error: ApiErrorBody? = null,
    val meta: JsonElement? = null,
)

@Serializable
data class ApiErrorBody(
    val code: String = ApiError.UNKNOWN_CODE,
    val message: String = ApiError.GENERIC_MESSAGE,
    val details: JsonElement? = null,
)
