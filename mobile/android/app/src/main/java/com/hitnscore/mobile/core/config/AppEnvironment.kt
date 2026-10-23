package com.hitnscore.mobile.core.config

import com.hitnscore.mobile.BuildConfig

data object AppEnvironment {
    val apiBaseUrl: String = BuildConfig.API_BASE_URL.trimEnd('/')

    val isConfigured: Boolean
        get() = apiBaseUrl.isNotBlank() && apiBaseUrl != "https://example.invalid"
}
