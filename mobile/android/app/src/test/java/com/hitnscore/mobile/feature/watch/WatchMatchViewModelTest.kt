package com.hitnscore.mobile.feature.watch

import com.hitnscore.mobile.core.network.ApiError
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchDisplayAccess
import com.hitnscore.mobile.data.model.MatchState
import com.hitnscore.mobile.data.model.MatchWatch
import com.hitnscore.mobile.data.model.WatchCode
import com.hitnscore.mobile.data.remote.MatchWatchApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class WatchMatchViewModelTest {
    private class FakeApi : MatchWatchApi {
        val watchCalls = mutableListOf<Pair<Int, String>>()
        var saveCalls = 0
        var displayCalls = 0
        var points = 0
        var finishAfter = Int.MAX_VALUE
        var failNext: ApiError? = null

        private fun current(saved: Boolean) = MatchWatch(
            code = "ABCD2345",
            saved = saved,
            finished = watchCalls.size >= finishAfter,
            match = MatchDetail(id = "m1", player1Name = "Pat", player2Name = "Sam", state = MatchState(player1Score = points)),
        )

        override suspend fun displayAccess(matchId: String): ApiResult<MatchDisplayAccess> {
            displayCalls++
            return ApiResult.Success(MatchDisplayAccess(matchId = matchId, viewerCode = "ABCD2345"))
        }

        override suspend fun watch(organizationId: Int, code: String): ApiResult<MatchWatch> {
            watchCalls += organizationId to code
            failNext?.let { failNext = null; return ApiResult.Failure(it) }
            points++
            return ApiResult.Success(current(saved = false))
        }

        override suspend fun save(organizationId: Int, code: String): ApiResult<MatchWatch> {
            saveCalls++
            return ApiResult.Success(current(saved = true))
        }
    }

    private val dispatcher = StandardTestDispatcher()

    @Before
    fun setUp() = Dispatchers.setMain(dispatcher)

    @After
    fun tearDown() = Dispatchers.resetMain()

    private fun TestScope.follow(api: FakeApi): WatchMatchViewModel {
        val viewModel = WatchMatchViewModel("ABCD2345", 50011, api, refreshMillis = 5_000)
        viewModel.startFollowing()
        runCurrent()
        return viewModel
    }

    @Test
    fun refreshesEveryFiveSecondsWhileVisible() = runTest(dispatcher) {
        val api = FakeApi()
        val viewModel = follow(api)
        assertEquals(listOf(50011 to "ABCD2345"), api.watchCalls)
        assertEquals(1, viewModel.uiState.value.watch?.match?.state?.player1Score)
        advanceTimeBy(5_001)
        assertEquals(2, api.watchCalls.size)
        assertEquals(2, viewModel.uiState.value.watch?.match?.state?.player1Score)
        viewModel.stopFollowing()
        advanceTimeBy(20_000)
        assertEquals(2, api.watchCalls.size)
    }

    @Test
    fun stopsRefreshingOnceTheMatchHasFinished() = runTest(dispatcher) {
        val api = FakeApi().apply { finishAfter = 2 }
        val viewModel = follow(api)
        advanceTimeBy(30_000)
        assertEquals(2, api.watchCalls.size)
        assertTrue(viewModel.uiState.value.isFinished)
        viewModel.stopFollowing()
    }

    @Test
    fun anErrorIsShownAndTheNextRefreshClearsIt() = runTest(dispatcher) {
        val api = FakeApi().apply { failNext = ApiError.Server(403, "PERSONAL_PLUS_REQUIRED", "Upgrade to Personal Plus to watch matches remotely.") }
        val viewModel = follow(api)
        assertEquals("Upgrade to Personal Plus to watch matches remotely.", viewModel.uiState.value.errorMessage)
        assertFalse(viewModel.uiState.value.isLoading)
        advanceTimeBy(5_001)
        assertEquals(null, viewModel.uiState.value.errorMessage)
        viewModel.stopFollowing()
    }

    @Test
    fun savingAddsToViewedMatchesOnce() = runTest(dispatcher) {
        val api = FakeApi()
        val viewModel = follow(api)
        var saved = 0
        viewModel.save { saved++ }
        runCurrent()
        viewModel.save { saved++ }
        runCurrent()
        assertTrue(viewModel.uiState.value.watch?.saved == true)
        assertEquals(1, api.saveCalls)
        assertEquals(1, saved)
        viewModel.stopFollowing()
    }

    @Test
    fun shareSheetLoadsTheViewingCodeOnce() = runTest(dispatcher) {
        val api = FakeApi()
        val viewModel = ShareLiveScoreViewModel("m1", api)
        viewModel.load()
        runCurrent()
        viewModel.load()
        runCurrent()
        assertEquals("ABCD2345", viewModel.uiState.value.viewerCode)
        assertFalse(viewModel.uiState.value.showsSpectatorDisplay)
        assertEquals(1, api.displayCalls)
    }

    @Test
    fun viewingCodesAreNormalisedAsTyped() {
        assertEquals("ABCD2345", WatchCode.normalize(" abcd-2345 "))
        assertEquals("ABCD2345", WatchCode.normalize("abcd2345xyz"))
        assertTrue(WatchCode.isComplete("abcd 2345"))
        assertFalse(WatchCode.isComplete("ABC123"))
        assertEquals("AB", WatchCode.normalize("Aé B"))
    }
}
