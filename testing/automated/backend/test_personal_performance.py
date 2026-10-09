from datetime import datetime, timezone

from common.dashboard_logic import (
    _history_limit_for_plan,
    _locked_history_preview,
    build_app_analytics,
    build_club_usage_analytics,
    build_extended_app_analytics,
    build_player_usage_analytics,
    build_personal_performance,
    personal_can_access_completed_match,
    personal_free_can_access_completed_match,
)
from common.plan_entitlements import personal_plan_contract, personal_plan_entitlements


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


class _AnalyticsCursor:
    def __init__(self, rows):
        self.rows = rows
        self.query = ""
        self.params = None

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def execute(self, query, params):
        self.query = query
        self.params = params

    def fetchall(self):
        return self.rows


class _AnalyticsConnection:
    def __init__(self, rows):
        self.test_cursor = _AnalyticsCursor(rows)

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


def test_app_analytics_groups_sports_and_excludes_scheduled_matches_from_abandoned_rate():
    connection = _AnalyticsConnection([
        {"sport": "squash", "status": "completed", "match_count": 6},
        {"sport": "squash", "status": "active", "match_count": 2},
        {"sport": "tennis", "status": "scheduled", "match_count": 2},
    ])

    analytics = build_app_analytics(connection, 42, period_days=30)

    assert analytics["matches_scored"] == 10
    assert analytics["completed_match_rate"] == 60.0
    assert analytics["abandoned_match_rate"] == 25.0
    assert analytics["matches_by_sport"] == [
        {"sport": "squash", "count": 8},
        {"sport": "racketball", "count": 0},
        {"sport": "tennis", "count": 2},
        {"sport": "padel", "count": 0},
    ]
    assert connection.test_cursor.params["period_days"] == 30
    assert "created_at >=" in connection.test_cursor.query


def test_extended_analytics_builds_duration_rules_competitiveness_and_club_usage():
    records = [{
        "id": "match-one",
        "court_id": 1,
        "court_name": "Show Court",
        "sport": "squash",
        "player1_name": "Alex",
        "player1_surname": "Player",
        "player2_name": "Sam",
        "player2_surname": "Opponent",
        "score_type": 11,
        "best_of": 5,
        "player1_games_won": 3,
        "player2_games_won": 2,
        "winner_side": "player1",
        "handicap_enabled": True,
        "status": "completed",
        "match_duration_seconds": 3600,
        "created_at": "2026-09-01T18:00:00+00:00",
        "completed_at": "2026-09-01T19:00:00+00:00",
        "updated_at": "2026-09-01T19:00:00+00:00",
        "events": [
            {
                "event_type": "match_started",
                "event_source": "web_app",
                "created_at": "2026-09-01T18:00:00+00:00",
                "payload": {"tennis_no_ad_scoring": True, "tennis_timed_breaks": True},
            },
            {
                "event_type": "score_point",
                "event_source": "web_app",
                "created_at": "2026-09-01T18:10:00+00:00",
                "payload": {"scorer": "player2", "game_result": {"player1_score": 10, "player2_score": 12, "winner_side": "player2"}},
            },
            {
                "event_type": "score_point",
                "event_source": "web_app",
                "created_at": "2026-09-01T18:25:00+00:00",
                "payload": {"scorer": "player1", "game_result": {"player1_score": 13, "player2_score": 11, "winner_side": "player1"}},
            },
        ],
    }]

    app = build_extended_app_analytics(records, 30)
    player = build_player_usage_analytics(records, "Alex", "Player")
    club = build_club_usage_analytics(records, app, 10)

    assert app["average_match_duration_seconds"] == 3600
    assert app["duration_distribution"]["60_90"] == 1
    assert app["most_used_match_format"] == {"label": "Best of 5", "count": 1}
    assert app["golden_point_usage_rate"] == 100.0
    assert app["handicap_match_usage_rate"] == 100.0
    assert app["close_match_frequency"] == 100.0
    assert app["extra_points_frequency"] == 100.0
    assert app["comeback_match_frequency"] == 100.0
    assert app["platform_usage"]["web"] == 1
    assert app["unique_participant_names"] == 2
    assert player["matches_played"] == 1
    assert player["matches_won"] == 1
    assert club["court_usage"][0]["court"] == "Show Court"
    assert club["simultaneous_court_activity"] == 1


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

    personal_can_access_completed_match(connection, 50001, "match-id", "personal_plus")
    assert connection.test_cursor.params["history_limit"] == 100


def test_personal_contract_caps_history_server_side():
    assert _history_limit_for_plan("personal", "personal_free", 1000) == 3
    assert _history_limit_for_plan("personal", "personal_plus", 1000) == 100
    assert _history_limit_for_plan("club", "club_pro", 1000) == 1000
    assert personal_plan_entitlements("personal_free") == {
        "history_limit": 3,
        "performance_enabled": False,
    }
    assert personal_plan_entitlements("personal_plus") == {
        "history_limit": 100,
        "performance_enabled": True,
    }
    assert personal_plan_contract()["personal_free"]["history_limit"] == 3
    assert personal_plan_contract()["personal_plus"]["history_limit"] == 100
