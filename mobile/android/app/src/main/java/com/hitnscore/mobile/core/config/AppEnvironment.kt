package com.hitnscore.mobile.core.config

import com.hitnscore.mobile.BuildConfig

/** Build-time environment, set per product flavour (dev / staging / prod) in app/build.gradle.kts. */
data object AppEnvironment {
    const val UNCONFIGURED_API_BASE_URL = "https://example.invalid"

    val apiBaseUrl: String = BuildConfig.API_BASE_URL.trimEnd('/')

    /** "development", "staging" or "production". */
    val environmentName: String = BuildConfig.ENVIRONMENT_NAME

    val versionName: String = BuildConfig.VERSION_NAME

    val isProduction: Boolean
        get() = environmentName == "production"

    val isConfigured: Boolean
        get() = apiBaseUrl.isNotBlank() && apiBaseUrl != UNCONFIGURED_API_BASE_URL

    val identityFirstLoginEnabled: Boolean = BuildConfig.IDENTITY_FIRST_LOGIN_ENABLED
}
