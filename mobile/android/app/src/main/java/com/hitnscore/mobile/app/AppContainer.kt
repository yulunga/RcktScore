package com.hitnscore.mobile.app

import android.content.Context
import com.hitnscore.mobile.core.auth.AuthService
import com.hitnscore.mobile.core.auth.EncryptedSessionStore
import com.hitnscore.mobile.core.auth.KeystoreCipher
import com.hitnscore.mobile.core.auth.RemoteAuthService
import com.hitnscore.mobile.core.auth.SharedSessionPreferences
import com.hitnscore.mobile.core.config.AppEnvironment
import com.hitnscore.mobile.core.connectivity.AndroidConnectivityMonitor
import com.hitnscore.mobile.core.connectivity.ConnectivityMonitor
import com.hitnscore.mobile.data.remote.HitNScoreApi
import com.hitnscore.mobile.data.remote.RemoteHitNScoreApi
import com.hitnscore.mobile.core.network.ApiClient
import com.hitnscore.mobile.core.network.AuthInterceptor
import com.hitnscore.mobile.core.session.AuthSessionRepository
import com.hitnscore.mobile.core.session.SessionRepository
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient

/**
 * Manual dependency container, the Android counterpart of iOS `AppContainer.swift`.
 * Kept deliberately small; move to Hilt only if wiring grows beyond a single module.
 */
class AppContainer(context: Context) {
    private val appContext = context.applicationContext

    val environment: AppEnvironment = AppEnvironment

    /** Work that must outlive a screen, such as telling the backend about a sign-out. */
    val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    val json: Json = Json {
        ignoreUnknownKeys = true
        // A null where a default exists (e.g. "best_of": null) uses the default, as iOS decodes.
        coerceInputValues = true
    }

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
        ApiClient(
            baseUrl = environment.apiBaseUrl,
            httpClient = httpClient,
            json = json,
            onSessionInvalidated = { code -> sessionRepository.onSessionInvalidated(code) },
        )
    }

    val authService: AuthService by lazy { RemoteAuthService(apiClient) }

    val api: HitNScoreApi by lazy { RemoteHitNScoreApi(apiClient) }

    val connectivity: ConnectivityMonitor by lazy { AndroidConnectivityMonitor(appContext) }

    val sessionRepository: SessionRepository by lazy {
        AuthSessionRepository(
            authService = authService,
            sessionStore = EncryptedSessionStore(
                preferences = appContext.getSharedPreferences("hitnscore_session", Context.MODE_PRIVATE),
                cipher = KeystoreCipher(),
                json = json,
            ),
            preferences = SharedSessionPreferences(
                appContext.getSharedPreferences("hitnscore_preferences", Context.MODE_PRIVATE),
            ),
            backgroundScope = applicationScope,
        )
    }
}
