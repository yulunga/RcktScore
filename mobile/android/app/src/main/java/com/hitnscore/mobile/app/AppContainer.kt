package com.hitnscore.mobile.app

import android.content.Context
import com.hitnscore.mobile.core.auth.AuthService
import com.hitnscore.mobile.core.auth.EncryptedSessionStore
import com.hitnscore.mobile.core.auth.KeystoreCipher
import com.hitnscore.mobile.core.auth.PasswordLinkInbox
import com.hitnscore.mobile.core.auth.PasswordResetService
import com.hitnscore.mobile.core.auth.RegistrationService
import com.hitnscore.mobile.core.auth.RemotePasswordResetService
import com.hitnscore.mobile.core.auth.RemoteAuthService
import com.hitnscore.mobile.core.auth.RemoteRegistrationService
import com.hitnscore.mobile.core.auth.FeedbackService
import com.hitnscore.mobile.core.auth.RemoteFeedbackService
import com.hitnscore.mobile.core.auth.SharedSessionPreferences
import com.hitnscore.mobile.core.config.AppEnvironment
import com.hitnscore.mobile.core.connectivity.AndroidConnectivityMonitor
import com.hitnscore.mobile.core.connectivity.ConnectivityMonitor
import com.hitnscore.mobile.data.remote.HitNScoreApi
import com.hitnscore.mobile.feature.scoring.LiveMatchNotifier
import com.hitnscore.mobile.feature.scoring.MatchTimerStore
import com.hitnscore.mobile.feature.scoring.SharedPreferencesTimerStore
import com.hitnscore.mobile.data.remote.RemoteHitNScoreApi
import com.hitnscore.mobile.data.remote.RemoteSettingsApi
import com.hitnscore.mobile.data.remote.MatchWatchApi
import com.hitnscore.mobile.data.remote.RemoteMatchWatchApi
import com.hitnscore.mobile.data.remote.RemoteTournamentApi
import com.hitnscore.mobile.data.remote.RemoteSetupAnalyticsApi
import com.hitnscore.mobile.data.remote.SetupAnalyticsApi
import com.hitnscore.mobile.data.remote.TournamentApi
import com.hitnscore.mobile.data.remote.SettingsApi
import com.hitnscore.mobile.core.network.ApiClient
import com.hitnscore.mobile.core.profile.ProfilePhotoStore
import com.hitnscore.mobile.core.network.AuthInterceptor
import com.hitnscore.mobile.core.session.AuthSessionRepository
import com.hitnscore.mobile.core.session.SessionRepository
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.core.session.SignOutReason
import com.hitnscore.mobile.feature.scoring.offline.OfflineMatchStore
import com.hitnscore.mobile.feature.scoring.offline.OfflineOwner
import com.hitnscore.mobile.feature.scoring.offline.SharedPreferencesSnapshotStorage
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import java.io.File
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

    val registrationService: RegistrationService by lazy { RemoteRegistrationService(apiClient) }
    val feedbackService: FeedbackService by lazy { RemoteFeedbackService(apiClient) }

    val passwordResetService: PasswordResetService by lazy { RemotePasswordResetService(apiClient) }

    /** Password set-up/reset links the app was opened with (App Links) or that were pasted in. */
    val passwordLinks = PasswordLinkInbox()

    val api: HitNScoreApi by lazy { RemoteHitNScoreApi(apiClient) }

    private val externalUploadClient: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .callTimeout(45, TimeUnit.SECONDS)
            .build()
    }

    val settingsApi: SettingsApi by lazy { RemoteSettingsApi(apiClient, externalUploadClient) }

    /** Score Stream: share a live match's viewing code, and watch one by code (Personal Plus). */
    val matchWatchApi: MatchWatchApi by lazy { RemoteMatchWatchApi(apiClient) }
    val tournamentApi: TournamentApi by lazy { RemoteTournamentApi(apiClient) }
    val setupAnalyticsApi: SetupAnalyticsApi by lazy { RemoteSetupAnalyticsApi(apiClient) }

    val connectivity: ConnectivityMonitor by lazy { AndroidConnectivityMonitor(appContext) }

    val timerStore: MatchTimerStore by lazy {
        SharedPreferencesTimerStore(appContext.getSharedPreferences("hitnscore_match_timers", Context.MODE_PRIVATE), json)
    }

    val liveMatchNotifier: LiveMatchNotifier by lazy { LiveMatchNotifier(appContext) }

    /** Matches held on the phone for offline scoring (M5). */
    val offlineMatchStore: OfflineMatchStore by lazy {
        OfflineMatchStore(SharedPreferencesSnapshotStorage(appContext.getSharedPreferences("hitnscore_offline_matches", Context.MODE_PRIVATE)))
    }

    /** Local cache of the centrally stored, compressed profile photograph for offline display. */
    val profilePhotos: ProfilePhotoStore by lazy { ProfilePhotoStore(File(appContext.noBackupFilesDir, "profile_photos")) }

    /** The signed-in user and account that offline data belongs to. */
    fun offlineOwner(): OfflineOwner? =
        (sessionRepository.state.value as? SessionState.SignedIn)?.let { OfflineOwner(it.username, it.activeContext.organizationId) }

    /**
     * Sends offline scoring whenever the phone is online with a signed-in user, even if the
     * scorer is closed (as iOS `AppContainer`), and forgets it when the user signs out.
     * Called once from [com.hitnscore.mobile.HitNScoreApplication.onCreate].
     */
    fun startOfflineSync() {
        mainScope.launch {
            combine(connectivity.isOnline, sessionRepository.state) { online, session -> online to session }
                .collect { (online, session) ->
                    when {
                        session is SessionState.SignedOut && session.reason in CLEARS_OFFLINE_DATA -> offlineMatchStore.clear()
                        online && session is SessionState.SignedIn -> offlineMatchStore.sync(api, offlineOwner())
                    }
                }
        }
    }

    private val mainScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    private companion object {
        /** Sign-outs the user chose. A session ended elsewhere keeps unsent points for the next sign-in. */
        val CLEARS_OFFLINE_DATA = setOf(SignOutReason.UserRequested, SignOutReason.AccountDeleted)
    }

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
