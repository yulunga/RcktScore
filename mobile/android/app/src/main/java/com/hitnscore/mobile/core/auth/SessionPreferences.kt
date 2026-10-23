package com.hitnscore.mobile.core.auth

import android.content.SharedPreferences

/** Non-secret, per-device settings for sign-in. */
interface SessionPreferences {
    var biometricUnlockEnabled: Boolean
}

class SharedSessionPreferences(private val preferences: SharedPreferences) : SessionPreferences {
    override var biometricUnlockEnabled: Boolean
        get() = preferences.getBoolean(KEY_BIOMETRIC, false)
        set(value) {
            preferences.edit().putBoolean(KEY_BIOMETRIC, value).apply()
        }

    private companion object {
        const val KEY_BIOMETRIC = "biometric_unlock_enabled"
    }
}
