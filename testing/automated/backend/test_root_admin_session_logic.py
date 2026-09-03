from datetime import datetime, timezone

import pytest

from common.root_admin_session_logic import create_root_admin_session, require_root_admin_session
from common.session_logic import SessionAuthError


class RecordingCursor:
    def __init__(self, statements):
        self.statements = statements
        self.rowcount = 1

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False

    def execute(self, statement, parameters=None):
        self.statements.append((statement, parameters or {}))


class RecordingConnection:
    def __init__(self):
        self.statements = []
        self.commits = 0

    def cursor(self):
        return RecordingCursor(self.statements)

    def commit(self):
        self.commits += 1


def test_root_admin_session_requires_a_bearer_token():
    with pytest.raises(SessionAuthError) as error:
        require_root_admin_session(RecordingConnection(), {"headers": {}})

    assert error.value.status_code == 401
    assert error.value.code == "ROOT_ADMIN_SESSION_REQUIRED"


def test_root_admin_session_stores_only_a_hash(monkeypatch):
    monkeypatch.setenv("ROOT_ADMIN_SESSION_TTL_HOURS", "8")
    connection = RecordingConnection()

    session = create_root_admin_session(connection, {"id": 42, "username": "root"})

    insert_parameters = next(
        parameters
        for statement, parameters in connection.statements
        if "INSERT INTO root_admin_sessions" in statement
    )
    assert session["token"]
    assert insert_parameters["token_hash"] != session["token"]
    assert len(insert_parameters["token_hash"]) == 64
    assert insert_parameters["expires_at"] > datetime.now(timezone.utc)
    assert connection.commits == 1


def test_root_admin_session_ttl_is_capped_at_24_hours(monkeypatch):
    monkeypatch.setenv("ROOT_ADMIN_SESSION_TTL_HOURS", "72")
    connection = RecordingConnection()

    create_root_admin_session(connection, {"id": 42, "username": "root"})

    insert_parameters = next(
        parameters
        for statement, parameters in connection.statements
        if "INSERT INTO root_admin_sessions" in statement
    )
    lifetime = insert_parameters["expires_at"] - insert_parameters["created_at"]
    assert lifetime.total_seconds() == 24 * 60 * 60
