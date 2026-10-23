package com.hitnscore.mobile.feature.scoring

import android.content.SharedPreferences
import kotlinx.serialization.json.Json

/** Keeps each match's clock on the device so it survives leaving the scorer or closing the app. */
interface MatchTimerStore {
    fun load(matchId: String): MatchTimer?
    fun save(matchId: String, timer: MatchTimer)
    fun clear(matchId: String)
}

class SharedPreferencesTimerStore(private val preferences: SharedPreferences, private val json: Json) : MatchTimerStore {
    override fun load(matchId: String): MatchTimer? = preferences.getString(key(matchId), null)?.let {
        try {
            json.decodeFromString(MatchTimer.serializer(), it)
        } catch (unreadable: IllegalArgumentException) {
            null
        }
    }

    override fun save(matchId: String, timer: MatchTimer) {
        preferences.edit().putString(key(matchId), json.encodeToString(MatchTimer.serializer(), timer)).apply()
    }

    override fun clear(matchId: String) {
        preferences.edit().remove(key(matchId)).apply()
    }

    private fun key(matchId: String) = "timer.$matchId"
}
