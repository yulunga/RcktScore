package com.hitnscore.mobile.feature.scoring.offline

import android.content.SharedPreferences
import com.hitnscore.mobile.core.network.ApiError
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.data.model.MatchDetail
import com.hitnscore.mobile.data.model.MatchSummary
import com.hitnscore.mobile.data.remote.HitNScoreApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/** Whose match this is: offline data is only ever shown to the same user in the same account. */
@Serializable
data class OfflineOwner(val username: String, val organizationId: Int) {
    fun matches(other: OfflineOwner?): Boolean =
        other != null && username.equals(other.username, ignoreCase = true) && organizationId == other.organizationId
}

/** A match held on this phone, plus the actions not yet confirmed by the server. */
@Serializable
data class OfflineMatchSnapshot(
    val owner: OfflineOwner,
    val serverMatch: MatchDetail,
    val queuedActions: List<OfflineMatchAction> = emptyList(),
    val cachedAtMillis: Long = 0,
) {
    /** What the scorer shows: the server's match with every queued action applied. */
    val projectedMatch: MatchDetail
        get() = queuedActions.lastOrNull()?.optimisticState?.let { serverMatch.copy(state = it) } ?: serverMatch
}

/** Where the snapshot is kept. An interface so the store can be unit-tested without Android. */
interface OfflineSnapshotStorage {
    fun read(): String?
    fun write(value: String?)
}

class SharedPreferencesSnapshotStorage(private val preferences: SharedPreferences) : OfflineSnapshotStorage {
    override fun read(): String? = preferences.getString(KEY, null)

    override fun write(value: String?) {
        preferences.edit().apply { if (value == null) remove(KEY) else putString(KEY, value) }.apply()
    }

    private companion object {
        const val KEY = "held_matches"
    }
}

/** The server refused a queued action for [matchId]; the scorer offers Retry or Discard. */
data class OfflineSyncFailure(val matchId: String, val message: String)

/**
 * Offline scoring, the Android counterpart of iOS `OfflineMatchStore`. Every scoring
 * action is queued with its projected scoreboard, shown at once, then sent to the
 * backend in order with its own `client_action_id`. While offline the queue waits and
 * is sent when the connection returns. Unlike iOS, which holds one match, a few
 * recent matches are kept so a club scorer can move between courts without losing
 * unsent points. Everything survives the app being closed. Use from the main thread.
 */
class OfflineMatchStore(private val storage: OfflineSnapshotStorage) {

    private val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
        // Keep every value, including defaults, so a stored action always round-trips intact.
        encodeDefaults = true
    }

    private val mutableSnapshots = MutableStateFlow(load())
    val snapshots: StateFlow<List<OfflineMatchSnapshot>> = mutableSnapshots.asStateFlow()

    private val mutableSyncing = MutableStateFlow(false)
    val isSyncing: StateFlow<Boolean> = mutableSyncing.asStateFlow()

    /** Set when the server refused an action (not when the phone is merely offline). */
    private val mutableSyncFailure = MutableStateFlow<OfflineSyncFailure?>(null)
    val syncFailure: StateFlow<OfflineSyncFailure?> = mutableSyncFailure.asStateFlow()

    private fun find(matchId: String): OfflineMatchSnapshot? = mutableSnapshots.value.firstOrNull { it.serverMatch.id == matchId }

    fun pendingCount(matchId: String): Int = find(matchId)?.queuedActions?.size ?: 0

    /** Unsent actions for this user across every held match. */
    fun pendingCount(owner: OfflineOwner?): Int =
        mutableSnapshots.value.filter { it.owner.matches(owner) }.sumOf { it.queuedActions.size }

    fun cachedMatch(matchId: String, owner: OfflineOwner?): MatchDetail? =
        find(matchId)?.takeIf { it.owner.matches(owner) }?.serverMatch

    fun projectedMatch(matchId: String, owner: OfflineOwner?): MatchDetail? =
        find(matchId)?.takeIf { it.owner.matches(owner) }?.projectedMatch

    /** Live matches this user can carry on scoring offline (iOS "Continue Offline"). */
    fun cachedActiveMatches(owner: OfflineOwner?): List<MatchDetail> =
        mutableSnapshots.value
            .filter { it.owner.matches(owner) }
            .filter { !it.serverMatch.status.equals("completed", ignoreCase = true) || it.queuedActions.isNotEmpty() }
            .filterNot { it.serverMatch.status.equals("scheduled", ignoreCase = true) }
            .sortedByDescending { it.cachedAtMillis }
            .map { it.projectedMatch }

    /** Remembers the server's latest copy of a match, keeping any queued actions for it. */
    fun cache(match: MatchDetail, owner: OfflineOwner) {
        val existing = find(match.id)
        val updated = if (existing != null && existing.owner.matches(owner)) {
            existing.copy(serverMatch = match, cachedAtMillis = System.currentTimeMillis())
        } else {
            OfflineMatchSnapshot(owner, match, emptyList(), System.currentTimeMillis())
        }
        replace(updated)
    }

    /**
     * Queues [action] with its projected scoreboard. Returns false when this match has not
     * been opened on the phone yet (it must be opened online once).
     */
    fun enqueue(action: OfflineMatchAction): Boolean {
        val current = find(action.matchId) ?: return false
        val state = current.queuedActions.lastOrNull()?.optimisticState ?: current.serverMatch.state ?: return false
        val projected = OfflineScoringReducer.apply(action, state, current.serverMatch)
        replace(current.copy(queuedActions = current.queuedActions + action.copy(optimisticState = projected), cachedAtMillis = System.currentTimeMillis()))
        clearFailure(action.matchId)
        return true
    }

    /** Takes back the newest action that has not reached the server yet. */
    fun undoLastQueued(matchId: String): Boolean {
        val current = find(matchId) ?: return false
        if (current.queuedActions.isEmpty()) return false
        replace(current.copy(queuedActions = current.queuedActions.dropLast(1)))
        if (current.queuedActions.size == 1) clearFailure(matchId)
        return true
    }

    /** Drops actions the server refused, so the scorer returns to the server's score. */
    fun discardPending(matchId: String) {
        val current = find(matchId) ?: return
        replace(current.copy(queuedActions = emptyList()))
        clearFailure(matchId)
    }

    /**
     * Sends this user's queued actions, oldest first, match by match. Stops a match at its
     * first failure and keeps the rest: a lost connection is retried later, a refusal is
     * reported in [syncFailure]. Returns true when nothing is left to send.
     */
    suspend fun sync(api: HitNScoreApi, owner: OfflineOwner?): Boolean {
        if (mutableSyncing.value || owner == null) return pendingCount(owner) == 0
        mutableSyncing.value = true
        try {
            val matchIds = mutableSnapshots.value.filter { it.owner.matches(owner) && it.queuedActions.isNotEmpty() }.map { it.serverMatch.id }
            for (matchId in matchIds) {
                while (true) {
                    val current = find(matchId) ?: break
                    if (!current.owner.matches(owner)) break
                    val action = current.queuedActions.firstOrNull() ?: break
                    when (val result = action.send(api)) {
                        is ApiResult.Success -> {
                            val latest = find(matchId) ?: break
                            replace(
                                latest.copy(
                                    serverMatch = result.value,
                                    queuedActions = latest.queuedActions.filterNot { it.id == action.id },
                                    cachedAtMillis = System.currentTimeMillis(),
                                ),
                            )
                            clearFailure(matchId)
                        }
                        is ApiResult.Failure -> {
                            when (result.error) {
                                // Still offline, or signed out: keep everything and try again later.
                                is ApiError.Network, is ApiError.SessionInvalid -> return false
                                else -> {
                                    mutableSyncFailure.value = OfflineSyncFailure(matchId, result.error.message)
                                    break
                                }
                            }
                        }
                    }
                }
            }
            return pendingCount(owner) == 0
        } finally {
            mutableSyncing.value = false
        }
    }

    /** Forgets everything, e.g. when the user signs out. */
    fun clear() {
        mutableSnapshots.value = emptyList()
        mutableSyncFailure.value = null
        storage.write(null)
    }

    private fun clearFailure(matchId: String) {
        if (mutableSyncFailure.value?.matchId == matchId) mutableSyncFailure.value = null
    }

    private fun replace(snapshot: OfflineMatchSnapshot) {
        val others = mutableSnapshots.value.filterNot { it.serverMatch.id == snapshot.serverMatch.id }
        // Keep the newest few; never drop a match that still has unsent actions.
        val kept = (listOf(snapshot) + others)
            .sortedByDescending { it.cachedAtMillis }
            .filterIndexed { index, held -> index < MAX_MATCHES || held.queuedActions.isNotEmpty() }
        mutableSnapshots.value = kept
        storage.write(json.encodeToString(SNAPSHOTS, kept))
    }

    private fun load(): List<OfflineMatchSnapshot> {
        val stored = storage.read() ?: return emptyList()
        return try {
            json.decodeFromString(SNAPSHOTS, stored)
        } catch (unreadable: SerializationException) {
            emptyList()
        } catch (unreadable: IllegalArgumentException) {
            emptyList()
        }
    }

    private companion object {
        const val MAX_MATCHES = 5
        val SNAPSHOTS = ListSerializer(OfflineMatchSnapshot.serializer())
    }
}

/** A held match as a list card, for Home's "Continue offline" section. */
fun MatchDetail.toSummary(): MatchSummary = MatchSummary(
    id = id,
    player1Name = player1Name,
    player1Surname = player1Surname,
    player2Name = player2Name,
    player2Surname = player2Surname,
    courtName = courtName,
    sport = sport,
    status = status,
    bestOf = state?.bestOf ?: bestOf,
    scoreType = state?.scoreType ?: scoreType,
    updatedAt = updatedAt,
    matchDurationSeconds = matchDurationSeconds,
    winnerName = state?.winnerName,
    state = state,
)
