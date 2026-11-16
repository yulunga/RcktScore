package com.hitnscore.mobile.data.remote

import com.hitnscore.mobile.core.network.ApiClient
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ScoringWarmRequest(@SerialName("match_id") val matchId: String, val warm: Boolean = true)

@Serializable
data class ScoringWarmResponse(val warmed: Boolean = false)

/**
 * As iOS `warmScoringAPIs`: wakes the scoring services (score point, event action, undo) while
 * the scorer is reading the match or warming up, so the first point isn't slowed by a cold
 * start. A warm request checks access and opens the database path but records nothing.
 * Failures are ignored; the normal queued scoring path handles retries.
 */
class ScoringWarmup(private val client: ApiClient) {
    suspend fun warm(matchId: String) = coroutineScope {
        listOf("score_point", "event_action", "undo_action").map { path ->
            async {
                runCatching {
                    client.post(path, ScoringWarmRequest(matchId), ScoringWarmRequest.serializer(), ScoringWarmResponse.serializer())
                }
            }
        }.awaitAll()
        Unit
    }
}
