import threading
import time

import pytest

import common.match_logic as match_logic
import common.tournament.tournament_logic as tournament_logic


class _LockedMatchCursor:
    def __init__(self, connection):
        self.connection = connection

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False

    def execute(self, query, params=None):
        normalized = " ".join(query.split())
        self.connection.queries.append((normalized, params or {}))
        if "FROM matches" in normalized and "FOR UPDATE" in normalized:
            self.connection.store.row_lock.acquire()
            self.connection.holds_row_lock = True

    def fetchone(self):
        return self.connection.store.match_row


class _LockedMatchConnection:
    def __init__(self, store):
        self.store = store
        self.queries = []
        self.events = []
        self.holds_row_lock = False
        self.commits = 0
        self.rollbacks = 0

    def cursor(self):
        return _LockedMatchCursor(self)

    def _release_lock(self):
        if self.holds_row_lock:
            self.holds_row_lock = False
            self.store.row_lock.release()

    def commit(self):
        self.events.append("commit")
        self.commits += 1
        self._release_lock()

    def rollback(self):
        self.events.append("rollback")
        self.rollbacks += 1
        self._release_lock()


class _ConcurrentScoreStore:
    def __init__(self):
        self.row_lock = threading.Lock()
        self.score = 0
        self.active_operations = 0
        self.maximum_active_operations = 0
        self.match_row = {"id": "match-1", "sport": "squash", "is_stale": False}


class _ConcurrentEngine:
    def __init__(self, store):
        self.store = store

    def score_point(self, connection, match_id, scorer, source="api", commit=True):
        assert match_id == "match-1"
        assert scorer == "player1"
        assert commit is False
        self.store.active_operations += 1
        self.store.maximum_active_operations = max(
            self.store.maximum_active_operations,
            self.store.active_operations,
        )
        previous_score = self.store.score
        time.sleep(0.02)
        self.store.score = previous_score + 1
        self.store.active_operations -= 1
        return {"id": match_id, "status": "active", "score": self.store.score}


def test_concurrent_match_mutations_are_serialized_before_state_is_rebuilt(monkeypatch):
    store = _ConcurrentScoreStore()
    engine = _ConcurrentEngine(store)
    monkeypatch.setattr(match_logic, "resolve_engine_module", lambda sport: engine)
    start = threading.Barrier(3)
    results = []
    errors = []

    def score(connection):
        try:
            start.wait()
            results.append(match_logic.score_point(connection, "match-1", "player1"))
        except Exception as error:  # pragma: no cover - retained to surface thread failures
            errors.append(error)

    connections = [_LockedMatchConnection(store), _LockedMatchConnection(store)]
    threads = [threading.Thread(target=score, args=(connection,)) for connection in connections]
    for thread in threads:
        thread.start()
    start.wait()
    for thread in threads:
        thread.join(timeout=2)

    assert errors == []
    assert all(not thread.is_alive() for thread in threads)
    assert store.score == 2
    assert store.maximum_active_operations == 1
    assert sorted(result["score"] for result in results) == [1, 2]
    assert [connection.commits for connection in connections] == [1, 1]
    assert all("FOR UPDATE" in connection.queries[0][0] for connection in connections)


def test_match_mutation_rolls_back_and_releases_lock_when_engine_fails(monkeypatch):
    store = _ConcurrentScoreStore()
    connection = _LockedMatchConnection(store)

    class FailingEngine:
        @staticmethod
        def score_point(*args, **kwargs):
            raise ValueError("invalid transition")

    monkeypatch.setattr(match_logic, "resolve_engine_module", lambda sport: FailingEngine)

    with pytest.raises(ValueError, match="invalid transition"):
        match_logic.score_point(connection, "match-1", "player1")

    assert connection.rollbacks == 1
    assert connection.commits == 0
    assert connection.holds_row_lock is False
    assert store.row_lock.acquire(blocking=False) is True
    store.row_lock.release()


def test_stale_match_is_ended_while_the_row_lock_is_still_held(monkeypatch):
    store = _ConcurrentScoreStore()
    store.match_row = {"id": "match-1", "sport": "squash", "is_stale": True}
    connection = _LockedMatchConnection(store)

    class StaleEngine:
        @staticmethod
        def score_point(*args, **kwargs):
            raise AssertionError("A stale match must not accept another point")

        @staticmethod
        def end_match(end_connection, match_id, **kwargs):
            assert end_connection is connection
            assert connection.holds_row_lock is True
            assert match_id == "match-1"
            assert kwargs["source"] == "system"
            assert kwargs["ended_early"] is True
            assert kwargs["commit"] is False
            return {"id": match_id, "status": "completed"}

    monkeypatch.setattr(match_logic, "resolve_engine_module", lambda sport: StaleEngine)

    with pytest.raises(ValueError, match="Match is already complete"):
        match_logic.score_point(connection, "match-1", "player1")

    assert connection.events == ["commit"]
    assert connection.holds_row_lock is False


def test_tournament_sync_runs_before_the_match_transaction_commits(monkeypatch):
    store = _ConcurrentScoreStore()
    connection = _LockedMatchConnection(store)

    class CompletingEngine:
        @staticmethod
        def score_point(*args, **kwargs):
            assert kwargs["commit"] is False
            return {
                "id": "match-1",
                "status": "completed",
                "tournament_match_id": "fixture-1",
            }

    def sync_result(sync_connection, match, natural_completion=False, commit=True):
        assert sync_connection is connection
        assert match["tournament_match_id"] == "fixture-1"
        assert natural_completion is True
        assert commit is False
        assert connection.commits == 0
        connection.events.append("tournament-sync")

    monkeypatch.setattr(match_logic, "resolve_engine_module", lambda sport: CompletingEngine)
    monkeypatch.setattr(tournament_logic, "sync_tournament_scoring_result", sync_result)

    result = match_logic.score_point(connection, "match-1", "player1")

    assert result["status"] == "completed"
    assert connection.events == ["tournament-sync", "commit"]


def test_early_end_waits_for_tournament_admin_resolution_before_commit(monkeypatch):
    store = _ConcurrentScoreStore()
    connection = _LockedMatchConnection(store)

    class EarlyEndEngine:
        @staticmethod
        def end_match(*args, **kwargs):
            assert kwargs["commit"] is False
            return {
                "id": "match-1",
                "status": "completed",
                "ended_early": True,
                "tournament_match_id": "fixture-1",
                "tournament_event_id": "event-1",
                "tenant_id": 7,
            }

    def mark_awaiting(mark_connection, match, commit=True):
        assert mark_connection is connection
        assert match["ended_early"] is True
        assert commit is False
        assert connection.commits == 0
        connection.events.append("awaiting-resolution")

    monkeypatch.setattr(match_logic, "resolve_engine_module", lambda sport: EarlyEndEngine)
    monkeypatch.setattr(tournament_logic, "mark_tournament_match_awaiting_resolution", mark_awaiting)

    result = match_logic.end_match(connection, "match-1", ended_early=True)

    assert result["status"] == "completed"
    assert connection.events == ["awaiting-resolution", "commit"]


def test_non_scoring_event_cannot_turn_an_early_end_into_natural_progression(monkeypatch):
    store = _ConcurrentScoreStore()
    connection = _LockedMatchConnection(store)

    class CompletedEngine:
        @staticmethod
        def event_action(*args, **kwargs):
            return {
                "id": "match-1",
                "status": "completed",
                "ended_early": False,
                "tournament_match_id": "fixture-1",
            }

    monkeypatch.setattr(match_logic, "resolve_engine_module", lambda sport: CompletedEngine)
    monkeypatch.setattr(
        tournament_logic,
        "sync_tournament_scoring_result",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(AssertionError("timer must not progress a fixture")),
    )

    result = match_logic.event_action(connection, "match-1", "timer", {"match_duration_seconds": 60})

    assert result["status"] == "completed"
    assert connection.events == ["commit"]


def test_completed_tournament_match_cannot_be_reopened_by_undo(monkeypatch):
    store = _ConcurrentScoreStore()
    connection = _LockedMatchConnection(store)

    class TournamentEngine:
        @staticmethod
        def get_match(*_args, **_kwargs):
            return {
                "id": "match-1",
                "status": "completed",
                "tournament_match_id": "fixture-1",
            }

        @staticmethod
        def undo_last_action(*_args, **_kwargs):
            raise AssertionError("Tournament progression must not be silently reopened")

    monkeypatch.setattr(match_logic, "resolve_engine_module", lambda sport: TournamentEngine)

    with pytest.raises(ValueError, match="cannot be undone after bracket progression"):
        match_logic.undo_last_action(connection, "match-1")

    assert connection.events == ["rollback"]


def test_undo_audit_identity_is_forwarded_inside_the_locked_transaction(monkeypatch):
    store = _ConcurrentScoreStore()
    connection = _LockedMatchConnection(store)
    captured = {}

    class ActiveEngine:
        @staticmethod
        def get_match(*_args, **_kwargs):
            return {"id": "match-1", "status": "active", "tournament_match_id": None}

        @staticmethod
        def undo_last_action(*_args, **kwargs):
            captured.update(kwargs)
            return {"id": "match-1", "status": "active"}

    monkeypatch.setattr(match_logic, "resolve_engine_module", lambda sport: ActiveEngine)

    result = match_logic.undo_last_action(
        connection,
        "match-1",
        source="mobile_app",
        actor_username="scorer@example.com",
    )

    assert result["status"] == "active"
    assert captured == {
        "source": "mobile_app",
        "actor_username": "scorer@example.com",
        "commit": False,
    }
    assert connection.events == ["commit"]
