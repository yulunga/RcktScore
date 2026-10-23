package com.hitnscore.mobile.core.network

import okhttp3.Interceptor
import okhttp3.Response

/** Adds JSON headers and, when signed in, `Authorization: Bearer <token>`. */
class AuthInterceptor(private val accessToken: () -> String?) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val original = chain.request()
        val request = original.newBuilder()
            .header("Accept", "application/json")
            .apply {
                // A request that already names its token (logout of a cleared session) keeps it.
                if (original.header("Authorization") == null) {
                    accessToken()?.takeIf { it.isNotBlank() }?.let { header("Authorization", "Bearer $it") }
                }
            }
            .build()
        return chain.proceed(request)
    }
}
