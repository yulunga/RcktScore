from datetime import datetime, timezone

import pytest

from common.scheduled_match_logic import delete_scheduled_club_match


class FakeCursor:
    def __init__(self, match):
        self.match = match
        self.result = None
        self.statements = []

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def execute(self, statement, params):
        self.statements.append((statement, params))
        if "SELECT id, tenant_id" in statement:
            self.result = self.match
        elif "UPDATE matches" in statement:
            self.result = {
                "id": self.match["id"],
                "tenant_id": self.match["tenant_id"],
                "status": self.match["status"],
                "archived_at": datetime(2026, 11, 17, tzinfo=timezone.utc),
            }

    def fetchone(self):
        return self.result


class FakeConnection:
    def __init__(self, match):
        self.fake_cursor = FakeCursor(match)
        self.committed = False

    def cursor(self):
        return self.fake_cursor

    def commit(self):
        self.committed = True


def scheduled_match(**overrides):
    return {
        "id": "match-1",
        "tenant_id": 42,
        "status": "scheduled",
        "tournament_match_id": None,
        "is_archived": False,
        **overrides,
    }


def test_admin_delete_archives_scheduled_match_under_lock():
    connection = FakeConnection(scheduled_match())

    result = delete_scheduled_club_match(connection, "match-1", 42)

    assert result["id"] == "match-1"
    assert connection.committed is True
    assert "FOR UPDATE" in connection.fake_cursor.statements[0][0]
    assert "is_archived = true" in connection.fake_cursor.statements[1][0]


@pytest.mark.parametrize(
    "overrides, tenant_id, message",
    [
        ({"status": "active"}, 42, "Only a scheduled match"),
        ({"status": "completed"}, 42, "Only a scheduled match"),
        ({"tournament_match_id": "fixture-1"}, 42, "Tournament fixtures"),
    ],
)
def test_delete_rejects_non_scheduled_and_tournament_matches(overrides, tenant_id, message):
    connection = FakeConnection(scheduled_match(**overrides))

    with pytest.raises(ValueError, match=message):
        delete_scheduled_club_match(connection, "match-1", tenant_id)

    assert connection.committed is False


def test_delete_hides_cross_tenant_match():
    connection = FakeConnection(scheduled_match())

    with pytest.raises(LookupError, match="not found"):
        delete_scheduled_club_match(connection, "match-1", 99)

    assert connection.committed is False
