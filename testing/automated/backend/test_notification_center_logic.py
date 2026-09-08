from datetime import datetime, timezone

import pytest

from common.notification_center_logic import create_notification


class _Cursor:
    def __init__(self):
        self.params = None

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def execute(self, _query, params):
        self.params = params

    def fetchone(self):
        return {
            "id": "notification-id",
            "title": self.params["title"],
            "message": self.params["message"],
            "audience": self.params["audience"],
            "created_at": datetime(2026, 9, 8, tzinfo=timezone.utc),
            "read_at": None,
        }


class _Connection:
    def __init__(self):
        self.test_cursor = _Cursor()
        self.committed = False

    def cursor(self):
        return self.test_cursor

    def commit(self):
        self.committed = True


def test_root_admin_can_create_plan_targeted_notification():
    connection = _Connection()
    notification = create_notification(
        connection,
        " Personal+ update ",
        " New performance features are available. ",
        "PERSONAL_PLUS",
        "root-admin",
    )

    assert connection.committed is True
    assert notification["audience"] == "personal_plus"
    assert notification["is_read"] is False


def test_notification_rejects_unsupported_audience():
    with pytest.raises(ValueError, match="audience is not supported"):
        create_notification(_Connection(), "Title", "Message", "unknown-plan", "root-admin")
