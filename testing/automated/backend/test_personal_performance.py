from datetime import datetime, timezone

from common.dashboard_logic import (
    _locked_history_preview,
    build_personal_performance,
    personal_free_can_access_completed_match,
)


class _EntitlementCursor:
    def __init__(self, available):
        self.available = available
        self.params = None

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def execute(self, _query, params):
        self.params = params

    def fetchone(self):
        return {"is_available": self.available}


class _EntitlementConnection:
    def __init__(self, available):
        self.test_cursor = _EntitlementCursor(available)

    def cursor(self):
        return self.test_cursor


def _match(match_id, completed_at, winner_side, sport="squash", p1_games=3, p2_games=1, events=None):
    return {
        "id": match_id,
        "sport": sport,
        "player1_name": "Alex",
        "player1_surname": "Player",
        "player2_name": "Sam",
        "player2_surname": "Opponent",
        "winner_side": winner_side,
        "completed_at": completed_at,
        "match_duration_seconds": 3600,
        "state": {
            "player1_games_won": p1_games,
            "player2_games_won": p2_games,
            "game_history": [
                {"player1_score": 11, "player2_score": 9},
                {"player1_score": 8, "player2_score": 11},
                {"player1_score": 12, "player2_score": 10},
                {"player1_score": 11, "player2_score": 6},
            ],
            "events": events or [],
        },
    }


def test_personal_performance_uses_account_holder_side_and_event_server():
    performance = build_personal_performance(
        [
            _match(
                "one",
                "2026-09-02T12:00:00+00:00",
                "player1",
                events=[
                    {"event_type": "match_created", "payload": {"current_server_side": "player1"}},
                    {"event_type": "score_point", "payload": {"scorer": "player1", "current_server_side": "player1"}},
                    {"event_type": "score_point", "payload": {"scorer": "player2", "current_server_side": "player2"}},
                    {"event_type": "score_point", "payload": {"scorer": "player1", "current_server_side": "player1"}},
                ],
            ),
            _match("two", "2026-08-20T12:00:00+00:00", "player2", p1_games=2, p2_games=3),
        ],
        "Alex",
        "Player",
        now=datetime(2026, 9, 8, tzinfo=timezone.utc),
    )

    assert performance["matches_played"] == 2
    assert performance["matches_won"] == 1
    assert performance["matches_lost"] == 1
    assert performance["win_percentage"] == 50.0
    assert performance["service_points_won"] == 1
    assert performance["service_points_lost"] == 1
    assert performance["service_point_win_percentage"] == 50.0
    assert performance["monthly_improvement"][0]["percentage_point_change"] == 100.0
    assert performance["opponents"][0]["matches_played"] == 2


def test_personal_performance_reports_matches_without_an_exact_player_identity():
    match = _match("one", "2026-09-02T12:00:00+00:00", "player1")
    performance = build_personal_performance(
        [match],
        "Different",
        "Person",
        now=datetime(2026, 9, 8, tzinfo=timezone.utc),
    )

    assert performance["matches_played"] == 0
    assert performance["unclassified_match_count"] == 1
    assert performance["win_percentage"] is None


def test_personal_performance_attributes_a_tennis_doubles_partner():
    match = _match("doubles", "2026-09-02T12:00:00+00:00", "player1", sport="tennis")
    match["state"]["tennis_teams"] = {
        "player1": [
            {"first_name": "Alex", "surname": "Player"},
            {"first_name": "Jamie", "surname": "Partner"},
        ],
        "player2": [
            {"first_name": "Sam", "surname": "Opponent"},
            {"first_name": "Taylor", "surname": "Opponent"},
        ],
    }

    performance = build_personal_performance(
        [match],
        "Jamie",
        "Partner",
        now=datetime(2026, 9, 8, tzinfo=timezone.utc),
    )

    assert performance["matches_played"] == 1
    assert performance["matches_won"] == 1
    assert performance["opponents"][0]["name"] == "Sam Opponent / Taylor Opponent"


def test_personal_free_locked_preview_does_not_expose_match_details():
    preview = _locked_history_preview({
        "id": "sensitive-match-id",
        "sport": "tennis",
        "player1_name": "Alex",
        "player2_name": "Sam",
        "winner_name": "Alex",
        "updated_at": "2026-09-08T12:00:00+00:00",
    })

    assert preview["locked"] is True
    assert preview["id"] == "locked-history-preview"
    assert preview["player1_name"] == "Locked"
    assert preview["player2_name"] == "Match"
    assert preview["winner_name"] is None
    assert preview["state"] is None


def test_personal_free_direct_history_access_uses_latest_three_window():
    connection = _EntitlementConnection(True)

    assert personal_free_can_access_completed_match(connection, 50001, "match-id") is True
    assert connection.test_cursor.params["organization_id"] == 50001
    assert connection.test_cursor.params["history_limit"] == 3
