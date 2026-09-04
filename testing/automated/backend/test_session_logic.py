from datetime import datetime, timezone

from common.session_logic import (
    create_org_user_session,
    login_source_label,
    normalize_login_source,
    session_token_from_event,
)


class RecordingCursor:
    def __init__(self, statements):
        self.statements = statements

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


def test_normalize_login_source_defaults_to_web_app():
    assert normalize_login_source("") == "web_app"
    assert normalize_login_source(None) == "web_app"
    assert normalize_login_source("browser") == "web_app"


def test_normalize_login_source_recognizes_mobile_aliases():
    assert normalize_login_source("mobile") == "mobile_app"
    assert normalize_login_source("ios") == "mobile_app"
    assert normalize_login_source("mobile_app") == "mobile_app"


def test_login_source_label_is_human_readable():
    assert login_source_label("mobile") == "mobile app"
    assert login_source_label("web") == "web app"


def test_session_token_prefers_bearer_authorization_header():
    event = {
        "headers": {
            "Authorization": "Bearer abc123",
            "x-session-token": "fallback-token",
        }
    }

    assert session_token_from_event(event) == "abc123"


def test_session_token_falls_back_to_custom_header():
    event = {
        "headers": {
            "x-session-token": "custom-token",
        }
    }

    assert session_token_from_event(event) == "custom-token"


def test_org_user_session_has_a_capped_expiry(monkeypatch):
    monkeypatch.setenv("ORG_USER_SESSION_TTL_DAYS", "365")
    connection = RecordingConnection()

    session = create_org_user_session(connection, "player@example.com", login_source="mobile")

    insert_parameters = next(
        parameters
        for statement, parameters in connection.statements
        if "INSERT INTO org_user_sessions" in statement
    )
    assert session["token"]
    assert insert_parameters["token_hash"] != session["token"]
    assert insert_parameters["expires_at"] > datetime.now(timezone.utc)
    lifetime = insert_parameters["expires_at"] - insert_parameters["created_at"]
    assert lifetime.total_seconds() == 90 * 24 * 60 * 60
    assert connection.commits == 1
