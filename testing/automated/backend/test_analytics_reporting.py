from datetime import datetime, timezone

from common.analytics_logic import build_analytics_export, get_match_setup_analytics
from functions.export_analytics.handler import _period_days


class _Cursor:
    def __init__(self, row):
        self.row = row
        self.query = ""
        self.params = None

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def execute(self, query, params):
        self.query = query
        self.params = params

    def fetchone(self):
        return self.row


class _Connection:
    def __init__(self, row):
        self.cursor_instance = _Cursor(row)

    def cursor(self):
        return self.cursor_instance


def test_match_setup_analytics_reports_completion_and_abandonment():
    connection = _Connection({
        "completed": 7,
        "abandoned": 3,
        "open": 2,
        "web": 8,
        "mobile": 4,
        "active_users": 5,
    })

    result = get_match_setup_analytics(
        connection,
        42,
        period_days=30,
        now=datetime(2026, 11, 8, tzinfo=timezone.utc),
    )

    assert result["tracked"] is True
    assert result["started"] == 12
    assert result["completed"] == 7
    assert result["abandoned"] == 3
    assert result["rate"] == 70.0
    assert result["abandonment_rate"] == 30.0
    assert result["client_usage"] == {"web": 8, "mobile": 4}
    assert result["active_users"] == 5
    assert connection.cursor_instance.params["organization_id"] == 42
    assert "started_at >=" in connection.cursor_instance.query


def test_club_export_contains_aggregates_without_player_or_member_details():
    dashboard = {
        "app_analytics": {
            "matches_scored": 12,
            "completed_matches": 10,
            "completed_match_rate": 83.3,
            "average_match_duration_seconds": 1800,
            "matches_by_sport": [{"sport": "squash", "count": 12}],
            "setup_completion": {"started": 14, "completed": 12, "abandoned": 2, "rate": 85.7},
        },
        "club_analytics": {
            "club_matches_scored": 12,
            "peak_time_concentration": 40,
            "off_peak_matches": 7,
            "simultaneous_court_activity": 2,
            "court_usage": [{"court": "Court 1", "matches": 8}],
        },
        "player_analytics": {"opponents": [{"name": "Private Player"}]},
        "performance": {"opponents": [{"name": "Another Private Player"}]},
    }

    report = build_analytics_export(dashboard, "club", 30)

    assert "Court 1" in report
    assert "Private Player" not in report
    assert "Another Private Player" not in report
    assert "email" not in report.lower()
    assert "username" not in report.lower()


def test_personal_export_includes_enhanced_player_summary():
    dashboard = {
        "app_analytics": {"matches_scored": 4, "matches_by_sport": [], "setup_completion": {}},
        "performance": {
            "matches_played": 4,
            "matches_won": 3,
            "win_percentage": 75.0,
            "games_won": 9,
            "point_win_percentage": 61.2,
            "service_point_win_percentage": 58.0,
            "playing_time_seconds": 7200,
            "current_win_streak": 2,
            "best_win_streak": 3,
            "sports": [{"sport": "tennis", "won": 3, "lost": 1}],
        },
    }

    report = build_analytics_export(dashboard, "personal", 30)

    assert "Matches won,3" in report
    assert "Serve point win percentage,58.0" in report
    assert "Player sport,Tennis,3-1" in report


def test_export_period_supports_all_time_and_defaults_to_thirty_days():
    assert _period_days({"queryStringParameters": {"period_days": "0"}}) == 0
    assert _period_days({"queryStringParameters": None}) == 30
