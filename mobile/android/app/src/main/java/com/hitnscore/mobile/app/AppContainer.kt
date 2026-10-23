package com.hitnscore.mobile.app

import com.hitnscore.mobile.core.config.AppEnvironment
import com.hitnscore.mobile.core.network.ApiClient
import com.hitnscore.mobile.core.network.AuthInterceptor
import com.hitnscore.mobile.core.session.PreviewSessionRepository
import com.hitnscore.mobile.core.session.SessionRepository
import java.util.concurrent.TimeUnit
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient

/**
 * Manual dependency container, the Android counterpart of iOS `AppContainer.swift`.
 * Kept deliberately small; move to Hilt only if wiring grows beyond a single module.
 */
class AppContainer {
    val environment: AppEnvironment = AppEnvironment

    val json: Json = Json {
        ignoreUnknownKeys = true
    }

    // M1 replaces this with the encrypted, backend-backed session repository.
    val sessionRepository: SessionRepository = PreviewSessionRepository()

    val httpClient: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(20, TimeUnit.SECONDS)
            .writeTimeout(20, TimeUnit.SECONDS)
            .callTimeout(30, TimeUnit.SECONDS)
            .addInterceptor(AuthInterceptor { sessionRepository.currentAccessToken() })
            .build()
    }

    val apiClient: ApiClient by lazy {
        ApiClient(baseUrl = environment.apiBaseUrl, httpClient = httpClient, json = json)
    }
}
