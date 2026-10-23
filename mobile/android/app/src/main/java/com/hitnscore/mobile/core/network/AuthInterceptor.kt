package com.hitnscore.mobile.core.network

import okhttp3.Interceptor
import okhttp3.Response

/** Adds JSON headers and, when signed in, `Authorization: Bearer <token>`. */
class AuthInterceptor(private val accessToken: () -> String?) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request().newBuilder()
            .header("Accept", "application/json")
            .apply {
                accessToken()?.takeIf { it.isNotBlank() }?.let { header("Authorization", "Bearer $it") }
            }
            .build()
        return chain.proceed(request)
    }
}
