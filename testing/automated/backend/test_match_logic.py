from datetime import datetime, timezone
from itertools import product

import pytest
from psycopg.errors import UndefinedColumn

import common.squash_match_logic as squash_match_logic
from common.squash_match_logic import (
    _build_state,
    _best_of_value,
    _games_to_win,
    _is_game_complete,
    _can_choose_shirt_colors,
    _next_service_side_after_point,
    _prepare_scoring_transition,
    _score_type_value,
    _shirt_color_value,
)


class _RecordingCursor:
    def __init__(self, connection):
        self.connection = connection

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False

    def execute(self, query, params=None):
        self.connection.executions.append((query, params or {}))


class _RecordingConnection:
    def __init__(self):
        self.executions = []
        self.committed = False

    def cursor(self):
        return _RecordingCursor(self)

    def commit(self):
        self.committed = True


class _UndoCursor:
    def __init__(self, connection):
        self.connection = connection

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False

    def execute(self, query, params=None):
        self.last_query = " ".join(query.split())
        self.connection.executions.append((self.last_query, params or {}))

    def fetchone(self):
        if "RETURNING id, event_sequence, created_at" in self.last_query:
            return self.connection.undo_event
        return self.connection.target_event

    def fetchall(self):
        return self.connection.derived_timers


class _UndoConnection:
    def __init__(self, target_event, derived_timers=None):
        self.target_event = target_event
        self.derived_timers = derived_timers or []
        self.undo_event = {
            "id": "undo-event",
            "event_sequence": 44,
            "created_at": datetime.now(timezone.utc),
        }
        self.executions = []

    def cursor(self):
        return _UndoCursor(self)


class _LegacyEventCursor(_UndoCursor):
    def execute(self, query, params=None):
        super().execute(query, params)
        if "event.event_sequence" in self.last_query:
            raise UndefinedColumn("column event.event_sequence does not exist")


class _LegacyEventConnection(_UndoConnection):
    def __init__(self, events):
        super().__init__(None, events)
        self.rolled_back = False

    def cursor(self):
        return _LegacyEventCursor(self)

    def rollback(self):
        self.rolled_back = True


def test_shared_undo_appends_compensation_for_score_and_later_timer():
    created_at = datetime.now(timezone.utc)
    connection = _UndoConnection(
        {"id": "score-event", "event_sequence": 41, "created_at": created_at},
        [{"id": "timer-event", "event_sequence": 42}],
    )

    undo_event = squash_match_logic._compensate_latest_undoable_event(
        connection,
        "match-1",
        ("score_point", "stroke"),
        source="mobile_app",
        actor_username="scorer@example.com",
    )

    assert undo_event == connection.undo_event
    assert connection.executions[0][1]["undoable_event_types"] == ["score_point", "stroke"]
    assert "event_type = ANY" in connection.executions[0][0]
    assert "ORDER BY event.event_sequence DESC" in connection.executions[0][0]
    assert "event.event_type = 'timer'" in connection.executions[1][0]
    assert "INSERT INTO match_events" in connection.executions[2][0]
    assert "'undo'" in connection.executions[2][0]
    assert connection.executions[2][1]["event_source"] == "mobile_app"
    assert connection.executions[2][1]["actor_username"] == "scorer@example.com"
    assert "INSERT INTO match_event_compensations" in connection.executions[3][0]
    assert connection.executions[3][1]["target_event_ids"] == ["score-event", "timer-event"]
    assert "SET status = 'active'" in connection.executions[4][0]
    assert "match_duration_seconds = 0" in connection.executions[4][0]
    assert all("DELETE FROM match_events" not in query for query, _params in connection.executions)


def test_shared_undo_leaves_metadata_untouched_when_no_scoring_event_exists():
    connection = _UndoConnection(None)

    target = squash_match_logic._compensate_latest_undoable_event(
        connection,
        "match-1",
        ("score_point", "stroke"),
    )

    assert target is None
    assert len(connection.executions) == 1


def test_effective_event_fetch_uses_sequence_and_hides_compensated_audit_events():
    expected_events = [{"id": "active-score", "event_sequence": 9}]
    connection = _UndoConnection(None, expected_events)

    events = squash_match_logic._fetch_match_events(connection, "match-1")

    assert events == expected_events
    query, params = connection.executions[0]
    assert params == {"match_id": "match-1"}
    assert "event.event_type <> 'undo'" in query
    assert "match_event_compensations" in query
    assert "ORDER BY event.event_sequence ASC" in query


def test_event_fetch_falls_back_to_legacy_order_during_migration_042_rollout():
    expected_events = [{"id": "legacy-score"}]
    connection = _LegacyEventConnection(expected_events)

    events = squash_match_logic._fetch_match_events(connection, "match-1")

    assert events == expected_events
    assert connection.rolled_back is True
    assert len(connection.executions) == 2
    assert "event.event_sequence" in connection.executions[0][0]
    assert "match_event_compensations" in connection.executions[0][0]
    assert "event.event_sequence" not in connection.executions[1][0]
    assert "ORDER BY event.created_at ASC, event.id ASC" in connection.executions[1][0]


def test_delayed_completion_timer_is_ignored_after_undo_reopens_match(monkeypatch):
    active_match = {
        "id": "match-1",
        "status": "active",
        "state": {"match_complete": False, "match_duration_seconds": 0},
    }
    monkeypatch.setattr(squash_match_logic, "get_match", lambda *_args, **_kwargs: active_match)
    monkeypatch.setattr(
        squash_match_logic,
        "_append_event",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError("A delayed timer must not be appended to a reopened match")
        ),
    )

    result = squash_match_logic._record_match_duration(
        object(),
        "match-1",
        {"match_duration_seconds": 120},
    )

    assert result is active_match


def test_best_of_value_only_allows_supported_options():
    assert _best_of_value(1) == 1
    assert _best_of_value(3) == 3
    assert _best_of_value(5) == 5
    assert _best_of_value(7) == 1


def test_games_to_win_is_derived_from_best_of():
    assert _games_to_win(1) == 1
    assert _games_to_win(3) == 2
    assert _games_to_win(5) == 3


def test_score_type_value_defaults_to_par_15_for_invalid_values():
    assert _score_type_value(11) == 11
    assert _score_type_value(15) == 15
    assert _score_type_value(99) == 15


def test_shirt_color_value_falls_back_when_unknown():
    assert _shirt_color_value("blue", "navy") == "blue"
    assert _shirt_color_value("unknown", "navy") == "navy"


def test_shirt_colors_are_available_to_both_personal_plans_and_clubs():
    assert _can_choose_shirt_colors({"org_type": "personal", "plan": "personal_free"}, 50001) is True
    assert _can_choose_shirt_colors({"org_type": "personal", "plan": "personal_plus"}, 50002) is True
    assert _can_choose_shirt_colors({"org_type": "club", "plan": "club_essentials"}, 1) is True


@pytest.mark.parametrize("personal_plan", ["personal_free", "personal_plus"])
def test_personal_match_creation_preserves_handicap_offsets(monkeypatch, personal_plan):
    connection = _RecordingConnection()
    monkeypatch.setattr(
        squash_match_logic,
        "_fetch_tenant_plan",
        lambda _connection, _tenant_id: {"org_type": "personal", "plan": personal_plan},
    )
    monkeypatch.setattr(squash_match_logic, "_find_active_match_for_tenant", lambda *_args: None)
    monkeypatch.setattr(
        squash_match_logic,
        "_ensure_personal_match_court",
        lambda *_args: {"id": 91, "court_name": "Personal Match", "court_alias": "Personal Match"},
    )
    monkeypatch.setattr(squash_match_logic, "get_match", lambda *_args: {"id": "created-match"})

    result = squash_match_logic.create_match(connection, {
        "tenant_id": "50002",
        "sport": "squash",
        "player1_name": "Alex",
        "player2_name": "Blair",
        "score_type": 15,
        "best_of": 3,
        "handicap_enabled": True,
        "player1_band": "A",
        "player2_band": "D",
        "player1_offset": -3,
        "player2_offset": 3,
        "tennis_no_ad_scoring": True,
        "tennis_timed_breaks": True,
    })

    match_insert = next(params for query, params in connection.executions if "INSERT INTO matches" in query)
    assert match_insert["handicap_enabled"] is True
    assert match_insert["player1_offset"] == -3
    assert match_insert["player2_offset"] == 3
    assert match_insert["tennis_no_ad_scoring"] is True
    assert match_insert["tennis_timed_breaks"] is True
    assert connection.committed is True
    assert result == {"id": "created-match"}


@pytest.mark.parametrize("club_plan", ["club_essentials", "club_pro"])
def test_club_match_creation_preserves_handicap_offsets(monkeypatch, club_plan):
    connection = _RecordingConnection()
    monkeypatch.setattr(
        squash_match_logic,
        "_fetch_tenant_plan",
        lambda _connection, _tenant_id: {"org_type": "club", "plan": club_plan},
    )
    monkeypatch.setattr(squash_match_logic, "_find_active_match_on_court", lambda *_args, **_kwargs: None)
    monkeypatch.setattr(squash_match_logic, "get_match", lambda *_args: {"id": "created-club-match"})

    result = squash_match_logic.create_match(connection, {
        "tenant_id": "42",
        "court_id": "7",
        "court_name": "Court 1",
        "sport": "racketball",
        "player1_name": "Alex",
        "player2_name": "Blair",
        "score_type": 15,
        "best_of": 3,
        "handicap_enabled": True,
        "player1_offset": -5,
        "player2_offset": 1,
    })

    match_insert = next(params for query, params in connection.executions if "INSERT INTO matches" in query)
    assert match_insert["handicap_enabled"] is True
    assert match_insert["player1_offset"] == -5
    assert match_insert["player2_offset"] == 1
    assert connection.committed is True
    assert result == {"id": "created-club-match"}


def test_personal_scheduled_match_cannot_start_while_another_match_is_active(monkeypatch):
    monkeypatch.setattr(
        squash_match_logic,
        "_fetch_tenant_plan",
        lambda _connection, _tenant_id: {"org_type": "personal", "plan": "personal_plus"},
    )
    monkeypatch.setattr(
        squash_match_logic,
        "_find_active_match_for_tenant",
        lambda *_args: {"id": "already-active"},
    )

    with pytest.raises(ValueError, match="End the current personal match"):
        squash_match_logic.ensure_scheduled_activation_available(
            object(),
            {"id": "scheduled-match", "tenant_id": "50002"},
        )


def test_personal_plus_can_create_scheduled_match_while_another_match_is_active(monkeypatch):
    connection = _RecordingConnection()
    monkeypatch.setattr(
        squash_match_logic,
        "_fetch_tenant_plan",
        lambda _connection, _tenant_id: {"org_type": "personal", "plan": "personal_plus"},
    )
    monkeypatch.setattr(
        squash_match_logic,
        "_find_active_match_for_tenant",
        lambda *_args: {"id": "already-active"},
    )
    monkeypatch.setattr(
        squash_match_logic,
        "_ensure_personal_match_court",
        lambda *_args: {"id": 91, "court_name": "Personal Match", "court_alias": "Personal Match"},
    )
    monkeypatch.setattr(squash_match_logic, "get_match", lambda *_args: {"id": "scheduled-match", "status": "scheduled"})

    result = squash_match_logic.create_match(connection, {
        "tenant_id": "50002",
        "sport": "squash",
        "status": "scheduled",
        "player1_name": "Alex",
        "player2_name": "Blair",
        "score_type": 11,
        "best_of": 3,
    })

    match_insert = next(params for query, params in connection.executions if "INSERT INTO matches" in query)
    assert match_insert["status"] == "scheduled"
    assert result == {"id": "scheduled-match", "status": "scheduled"}


def test_game_completion_requires_target_and_two_point_margin():
    assert _is_game_complete(15, 12, 15) is True
    assert _is_game_complete(15, 14, 15) is False
    assert _is_game_complete(17, 15, 15) is True


def test_golden_point_completes_on_the_next_point_at_target_all():
    assert _is_game_complete(11, 10, 11, golden_point=True) is True
    assert _is_game_complete(15, 14, 15, golden_point=True) is True
    assert _is_game_complete(10, 10, 11, golden_point=True) is False


def _active_match(**state_overrides):
    state = {
        "player1_score": 1,
        "player2_score": 1,
        "player1_games_won": 0,
        "player2_games_won": 0,
        "current_game_number": 1,
        "best_of": 3,
        "games_to_win": 2,
        "current_server": "Alex",
        "current_server_side": "player1",
        "service_side": "Right",
        "game_history": [],
        "match_complete": False,
    }
    state.update(state_overrides)
    return {
        "status": "active",
        "score_type": 11,
        "best_of": 3,
        "player1_name": "Alex",
        "player2_name": "Blair",
        "player1_handedness": "right",
        "player2_handedness": "right",
        "handicap_enabled": False,
        "player1_offset": 0,
        "player2_offset": 0,
        "state": state,
    }


def test_server_win_alternates_from_manually_selected_left_side():
    match = _active_match(service_side="Left")

    transition = _prepare_scoring_transition(match, "player1", "score_point", {"scorer": "player1"})

    assert transition["state"]["player1_score"] == 2
    assert transition["state"]["current_server_side"] == "player1"
    assert transition["state"]["service_side"] == "Right"
    assert transition["payload"]["service_side"] == "Right"


def test_racket_golden_point_ends_game_with_one_point_lead():
    match = _active_match(
        player1_score=10,
        player2_score=10,
        tennis_no_ad_scoring=True,
    )

    transition = _prepare_scoring_transition(match, "player1", "score_point", {"scorer": "player1"})

    assert transition["payload"]["game_completed"] is True
    assert transition["payload"]["game_result"]["player1_score"] == 11
    assert transition["payload"]["game_result"]["player2_score"] == 10


def test_service_transfer_uses_receivers_handedness_default():
    match = _active_match(
        current_server="Blair",
        current_server_side="player2",
        service_side="Left",
    )
    match["player2_handedness"] = "left"

    transition = _prepare_scoring_transition(match, "player1", "score_point", {"scorer": "player1"})

    assert transition["state"]["current_server_side"] == "player1"
    assert transition["state"]["service_side"] == "Left"


def test_legacy_event_replay_preserves_previous_server_for_service_transfer():
    match_row = {
        **_active_match(),
        "status": "active",
        "current_game_number": 1,
        "player1_games_won": 0,
        "player2_games_won": 0,
        "winner_side": None,
        "winner_name": None,
        "ended_early": False,
        "end_reason": None,
        "match_duration_seconds": 0,
    }
    match_row.pop("state")
    event_rows = [
        {
            "id": "start",
            "event_type": "match_started",
            "event_source": "api",
            "created_at": datetime.now(timezone.utc),
            "payload": {
                "current_server": "Blair",
                "current_server_side": "player2",
                "service_side": "Right",
                "player1_score": 0,
                "player2_score": 1,
            },
        },
        {
            "id": "legacy-point",
            "event_type": "score_point",
            "event_source": "api",
            "created_at": datetime.now(timezone.utc),
            "payload": {"scorer": "player1"},
        },
    ]

    state = _build_state(match_row, event_rows)

    assert state["current_server_side"] == "player1"
    assert state["service_side"] == "Right"


def test_service_side_helper_does_not_change_score_or_server():
    match = _active_match()

    assert _next_service_side_after_point(match, "player1", "Left", "player1") == "Right"
    assert _next_service_side_after_point(match, "player2", "Left", "player1") == "Right"


def test_exhaustive_six_point_sequences_keep_server_and_service_side_consistent():
    for player1_handedness, player2_handedness in product(("right", "left"), repeat=2):
        for scorers in product(("player1", "player2"), repeat=6):
            match = _active_match(player1_score=0, player2_score=0)
            match["player1_handedness"] = player1_handedness
            match["player2_handedness"] = player2_handedness
            expected_player1 = 0
            expected_player2 = 0

            for scorer in scorers:
                previous_server = match["state"]["current_server_side"]
                previous_side = match["state"]["service_side"]
                expected_side = (
                    "Left" if previous_side == "Right" else "Right"
                ) if scorer == previous_server else (
                    "Left"
                    if (
                        player2_handedness if scorer == "player1" else player1_handedness
                    ) == "left"
                    else "Right"
                )

                transition = _prepare_scoring_transition(
                    match,
                    scorer,
                    "score_point",
                    {"scorer": scorer},
                )
                match["state"] = transition["state"]
                expected_player1 += scorer == "player1"
                expected_player2 += scorer == "player2"

                assert transition["state"]["player1_score"] == expected_player1
                assert transition["state"]["player2_score"] == expected_player2
                assert transition["state"]["current_server_side"] == scorer
                assert transition["state"]["service_side"] == expected_side


def test_game_and_match_boundaries_reset_only_when_another_game_is_required():
    match = _active_match(player1_score=10, player2_score=4)

    game_transition = _prepare_scoring_transition(
        match,
        "player1",
        "score_point",
        {"scorer": "player1"},
    )

    assert game_transition["payload"]["game_result"]["player1_score"] == 11
    assert game_transition["state"]["current_game_number"] == 2
    assert game_transition["state"]["player1_games_won"] == 1
    assert game_transition["state"]["player1_score"] == 0
    assert game_transition["state"]["player2_score"] == 0
    assert game_transition["state"]["match_complete"] is False

    match["state"] = {
        **game_transition["state"],
        "player1_score": 10,
        "player2_score": 5,
    }
    match_transition = _prepare_scoring_transition(
        match,
        "player1",
        "score_point",
        {"scorer": "player1"},
    )

    assert match_transition["state"]["match_complete"] is True
    assert match_transition["state"]["player1_games_won"] == 2
    assert match_transition["state"]["player1_score"] == 11
    assert match_transition["state"]["winner_name"] == "Alex"
