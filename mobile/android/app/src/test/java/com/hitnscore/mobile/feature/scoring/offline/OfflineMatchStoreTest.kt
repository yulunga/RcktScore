package com.hitnscore.mobile.feature.scoring.offline

import com.hitnscore.mobile.core.network.ApiError
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.data.model.AppNotification
import com.hitnscore.mobile.data.model.CreateMatchRequest
import com.hitnscore.mobile.data.model.Dashboard
import com.hitnscore.mobile.data.model.EndMatchRequest
import com.hitnscore.mobile.data.model.EventActionRequest
import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchIdRequest
import com.hitnscore.mobile.data.model.MatchSetupLookups
import com.hitnscore.mobile.data.model.MatchState
import com.hitnscore.mobile.data.model.OrganizationSettings
import com.hitnscore.mobile.data.model.ScorePointRequest
import com.hitnscore.mobile.data.remote.HitNScoreApi
import java.io.IOException
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OfflineMatchStoreTest {
    private val owner = OfflineOwner("pat@example.com", 50011)
    private val match = MatchDetail(
        id = "m1",
        sport = "squash",
        status = "active",
        player1Name = "Ann",
        player2Name = "Bea",
        state = MatchState(scoreType = 11, bestOf = 3, currentServerSide = "player1", serviceSide = "Right"),
    )

    private class MemoryStorage : OfflineSnapshotStorage {
        var value: String? = null
        override fun read() = value
        override fun write(value: String?) {
            this.value = value
        }
    }

    /** Counts points like the server would, or fails every call while [offline]. */
    private inner class FakeApi : HitNScoreApi {
        var offline = false
        var refuse = false
        val clientActionIds = mutableListOf<String>()
        private var server = match

        override suspend fun scorePoint(request: ScorePointRequest): ApiResult<MatchDetail> {
            if (offline) return ApiResult.Failure(ApiError.Network(IOException("offline")))
            if (refuse) return ApiResult.Failure(ApiError.Server(409, "MATCH_COMPLETED", "This match has already finished."))
            clientActionIds += request.clientActionId
            val state = server.state!!
            server = server.copy(
                state = if (request.scorer == "player1") state.copy(player1Score = state.player1Score + 1) else state.copy(player2Score = state.player2Score + 1),
            )
            return ApiResult.Success(server)
        }

        override suspend fun dashboard(organizationId: Int): ApiResult<Dashboard> = error("unused")
        override suspend fun match(matchId: String): ApiResult<MatchDetail> = ApiResult.Success(server)
        override suspend fun notifications(organizationId: Int): ApiResult<List<AppNotification>> = error("unused")
        override suspend fun markNotificationRead(notificationId: String, organizationId: Int): ApiResult<Boolean> = error("unused")
        override suspend fun organizationSettings(organizationId: Int): ApiResult<OrganizationSettings> = error("unused")
        override suspend fun setupLookup(organizationId: Int, query: String): ApiResult<MatchSetupLookups> = error("unused")
        override suspend fun createMatch(request: CreateMatchRequest): ApiResult<MatchDetail> = error("unused")
        override suspend fun startScheduledMatch(matchId: String): ApiResult<MatchDetail> = error("unused")
        override suspend fun eventAction(request: EventActionRequest): ApiResult<MatchDetail> = ApiResult.Success(server)
        override suspend fun undo(request: MatchIdRequest): ApiResult<MatchDetail> = error("unused")
        override suspend fun endMatch(request: EndMatchRequest): ApiResult<MatchDetail> = error("unused")
    }

    private fun point(side: String) = OfflineMatchAction(matchId = "m1", kind = OfflineActionKind.ScorePoint, scorer = side)

    @Test
    fun queuedPointsShowAtOnceAndSurviveARestart() {
        val storage = MemoryStorage()
        val store = OfflineMatchStore(storage)
        store.cache(match, owner)
        assertTrue(store.enqueue(point("player1")))
        assertTrue(store.enqueue(point("player1")))
        assertEquals(2, store.projectedMatch("m1", owner)?.state?.player1Score)
        assertEquals(0, store.cachedMatch("m1", owner)?.state?.player1Score)

        val reopened = OfflineMatchStore(storage)
        assertEquals(2, reopened.pendingCount("m1"))
        assertEquals(2, reopened.projectedMatch("m1", owner)?.state?.player1Score)
    }

    @Test
    fun anotherUserNeverSeesTheHeldMatch() {
        val store = OfflineMatchStore(MemoryStorage())
        store.cache(match, owner)
        assertNull(store.projectedMatch("m1", OfflineOwner("someone@else.com", 50011)))
        assertNull(store.projectedMatch("m1", owner.copy(organizationId = 42)))
        assertNotNull(store.projectedMatch("m1", owner.copy(username = "PAT@example.com")))
    }

    @Test
    fun syncSendsInOrderWithTheQueuedActionIds() = runTest {
        val store = OfflineMatchStore(MemoryStorage())
        val api = FakeApi()
        store.cache(match, owner)
        val first = point("player1")
        val second = point("player2")
        store.enqueue(first)
        store.enqueue(second)
        assertTrue(store.sync(api, owner))
        assertEquals(listOf(first.id, second.id), api.clientActionIds)
        assertEquals(0, store.pendingCount("m1"))
        assertEquals(1, store.cachedMatch("m1", owner)?.state?.player2Score)
    }

    @Test
    fun offlineSyncKeepsTheQueueAndReportsNoError() = runTest {
        val store = OfflineMatchStore(MemoryStorage())
        val api = FakeApi().apply { offline = true }
        store.cache(match, owner)
        store.enqueue(point("player1"))
        assertFalse(store.sync(api, owner))
        assertEquals(1, store.pendingCount("m1"))
        assertNull(store.syncFailure.value)

        api.offline = false
        assertTrue(store.sync(api, owner))
        assertEquals(1, store.cachedMatch("m1", owner)?.state?.player1Score)
    }

    @Test
    fun refusedActionIsReportedAndCanBeDiscarded() = runTest {
        val store = OfflineMatchStore(MemoryStorage())
        val api = FakeApi().apply { refuse = true }
        store.cache(match, owner)
        store.enqueue(point("player1"))
        assertFalse(store.sync(api, owner))
        assertEquals("m1", store.syncFailure.value?.matchId)
        store.discardPending("m1")
        assertEquals(0, store.pendingCount("m1"))
        assertNull(store.syncFailure.value)
        assertEquals(0, store.projectedMatch("m1", owner)?.state?.player1Score)
    }

    @Test
    fun undoTakesBackOnlyUnsentActions() {
        val store = OfflineMatchStore(MemoryStorage())
        store.cache(match, owner)
        store.enqueue(point("player1"))
        assertTrue(store.undoLastQueued("m1"))
        assertEquals(0, store.projectedMatch("m1", owner)?.state?.player1Score)
        assertFalse(store.undoLastQueued("m1"))
    }

    @Test
    fun unknownMatchCannotBeQueued() {
        val store = OfflineMatchStore(MemoryStorage())
        assertFalse(store.enqueue(point("player1")))
    }
}
