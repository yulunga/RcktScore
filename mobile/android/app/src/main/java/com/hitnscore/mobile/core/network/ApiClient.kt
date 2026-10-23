package com.hitnscore.mobile.core.network

import java.io.IOException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.DeserializationStrategy
import kotlinx.serialization.SerializationStrategy
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

/**
 * Thin client for the HitNScore v2 API, mirroring `APIClient.swift`.
 * Repositories call it; screens never do.
 */
class ApiClient(
    private val baseUrl: String,
    private val httpClient: OkHttpClient,
    private val json: Json,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    private val parser = ApiResponseParser(json)

    suspend fun <T> get(path: String, deserializer: DeserializationStrategy<T>): ApiResult<T> =
        execute(Request.Builder().url(urlFor(path)).get().build(), deserializer)

    suspend fun <B, T> post(
        path: String,
        body: B,
        bodySerializer: SerializationStrategy<B>,
        deserializer: DeserializationStrategy<T>,
    ): ApiResult<T> = execute(
        Request.Builder().url(urlFor(path)).post(encode(body, bodySerializer)).build(),
        deserializer,
    )

    suspend fun <B, T> put(
        path: String,
        body: B,
        bodySerializer: SerializationStrategy<B>,
        deserializer: DeserializationStrategy<T>,
    ): ApiResult<T> = execute(
        Request.Builder().url(urlFor(path)).put(encode(body, bodySerializer)).build(),
        deserializer,
    )

    suspend fun <T> delete(path: String, deserializer: DeserializationStrategy<T>): ApiResult<T> =
        execute(Request.Builder().url(urlFor(path)).delete().build(), deserializer)

    private fun <B> encode(body: B, serializer: SerializationStrategy<B>) =
        json.encodeToString(serializer, body).toRequestBody(JSON_MEDIA_TYPE)

    private fun urlFor(path: String): String = "${baseUrl.trimEnd('/')}/${path.trimStart('/')}"

    private suspend fun <T> execute(
        request: Request,
        deserializer: DeserializationStrategy<T>,
    ): ApiResult<T> = withContext(ioDispatcher) {
        try {
            httpClient.newCall(request).execute().use { response ->
                parser.parse(response.code, response.body.string(), deserializer)
            }
        } catch (e: IOException) {
            ApiResult.Failure(ApiError.Network(e))
        }
    }

    private companion object {
        val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()
    }
}
