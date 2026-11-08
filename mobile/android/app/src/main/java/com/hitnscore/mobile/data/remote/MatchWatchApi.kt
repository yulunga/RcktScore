package com.hitnscore.mobile.data.remote

import com.hitnscore.mobile.core.network.ApiClient
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.data.model.MatchDisplayAccess
import com.hitnscore.mobile.data.model.MatchDisplayAccessResponseData
import com.hitnscore.mobile.data.model.MatchWatch
import com.hitnscore.mobile.data.model.MatchWatchRequest
import com.hitnscore.mobile.data.model.MatchWatchResponseData
import java.net.URLEncoder

/**
 * Score Stream routes, the same ones iOS and the web use. Sharing works for anyone who can
 * score the match; watching needs a Personal Plus account (the server answers
 * `PERSONAL_PLUS_REQUIRED` otherwise).
 */
interface MatchWatchApi {
    /** The match's viewing code (created on first request) and, for clubs, the court display. */
    suspend fun displayAccess(matchId: String): ApiResult<MatchDisplayAccess>

    /** The live match behind a viewing code. */
    suspend fun watch(organizationId: Int, code: String): ApiResult<MatchWatch>

    /** Adds the match to the viewer's Viewed Matches (shared with web and iOS). */
    suspend fun save(organizationId: Int, code: String): ApiResult<MatchWatch>
}

class RemoteMatchWatchApi(private val client: ApiClient) : MatchWatchApi {
    override suspend fun displayAccess(matchId: String) =
        client.get(
            "match_display_access/${URLEncoder.encode(matchId, Charsets.UTF_8.name())}",
            MatchDisplayAccessResponseData.serializer(),
        ).map { it.displayAccess }

    override suspend fun watch(organizationId: Int, code: String) =
        client.post("match_watch/lookup", MatchWatchRequest(organizationId, code), MatchWatchRequest.serializer(), MatchWatchResponseData.serializer())
            .map { it.watch }

    override suspend fun save(organizationId: Int, code: String) =
        client.post("match_watch/save", MatchWatchRequest(organizationId, code), MatchWatchRequest.serializer(), MatchWatchResponseData.serializer())
            .map { it.watch }
}
