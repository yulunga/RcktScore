from datetime import datetime, timezone

from common.session_logic import (
    WEB_SESSION_COOKIE,
    SessionAuthError,
    authorize_organization_session,
    create_org_user_session,
    get_active_session_for_username,
    login_source_label,
    normalize_login_source,
    require_org_user_session,
    session_credentials_from_event,
    session_token_from_event,
)
from common.access_control import CAPABILITY_MATCH_MANAGE
import common.session_logic as session_logic
import pytest


class RecordingCursor:
    def __init__(self, statements):
        self.statements = statements

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False

    def execute(self, statement, parameters=None):
        self.statements.append((statement, parameters or {}))

    def fetchone(self):
        return None


class RecordingConnection:
    def __init__(self):
        self.statements = []
        self.commits = 0

    def cursor(self):
        return RecordingCursor(self.statements)

    def commit(self):
        self.commits += 1


class ScorerTakeoverCursor:
    def __init__(self, connection):
        self.connection = connection
        self.result = None

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False

    def execute(self, statement, parameters=None):
        parameters = parameters or {}
        normalized = " ".join(statement.split())
        self.connection.statements.append((normalized, parameters))
        if "SELECT tenant_id, status, scoring_owner_membership_id" in normalized:
            self.result = dict(self.connection.match)
        elif normalized.startswith("UPDATE matches"):
            self.connection.match["scoring_owner_membership_id"] = parameters["membership_id"]
            self.connection.match["scoring_locked_at"] = parameters["locked_at"]
        elif "SELECT tenant_id, sport, status, scoring_owner_membership_id" in normalized:
            self.result = dict(self.connection.match)

    def fetchone(self):
        return self.result


class ScorerTakeoverConnection:
    def __init__(self):
        self.match = {
            "tenant_id": 12,
            "sport": "squash",
            "status": "active",
            "scoring_owner_membership_id": 101,
            "scoring_locked_at": datetime.now(timezone.utc),
        }
        self.statements = []
        self.commits = 0

    def cursor(self):
        return ScorerTakeoverCursor(self)

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


def test_session_token_does_not_accept_legacy_custom_header():
    event = {
        "headers": {
            "x-session-token": "custom-token",
        }
    }

    assert session_token_from_event(event) == ""


def test_cookie_and_bearer_credentials_are_rejected_as_ambiguous():
    event = {
        "headers": {
            "authorization": "Bearer native-token",
            "cookie": f"{WEB_SESSION_COOKIE}=browser-token",
        }
    }
    with pytest.raises(SessionAuthError) as error:
        session_credentials_from_event(event)
    assert error.value.code == "AMBIGUOUS_SESSION_CREDENTIALS"


def test_cookie_mutation_requires_matching_origin_and_csrf(monkeypatch):
    connection = RecordingConnection()
    session_row = {
        "id": 8,
        "username": "player@example.com",
        "expires_at": datetime.now(timezone.utc).replace(year=datetime.now(timezone.utc).year + 1),
        "login_source": "web_app",
        "csrf_token": "expected-csrf",
    }
    monkeypatch.setattr(session_logic, "_get_session_row", lambda *_args, **_kwargs: session_row)
    event = {
        "requestContext": {"http": {"method": "POST"}},
        "headers": {
            "origin": "https://app.hitnscore.com",
            "x-csrf-token": "expected-csrf",
            "cookie": f"{WEB_SESSION_COOKIE}=browser-token",
        },
    }
    session = require_org_user_session(connection, event)
    assert session["credential_type"] == "cookie"

    event["headers"].pop("x-csrf-token")
    with pytest.raises(SessionAuthError) as error:
        require_org_user_session(connection, event)
    assert error.value.code == "CSRF_VALIDATION_FAILED"


def test_web_session_cannot_be_replayed_as_bearer(monkeypatch):
    connection = RecordingConnection()
    monkeypatch.setattr(
        session_logic,
        "_get_session_row",
        lambda *_args, **_kwargs: {
            "id": 8,
            "username": "player@example.com",
            "expires_at": datetime.now(timezone.utc).replace(year=datetime.now(timezone.utc).year + 1),
            "login_source": "web_app",
            "csrf_token": "csrf",
        },
    )
    with pytest.raises(SessionAuthError) as error:
        require_org_user_session(connection, {"headers": {"authorization": "Bearer browser-token"}})
    assert error.value.code == "SESSION_TRANSPORT_MISMATCH"


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

    revoke_statement, revoke_parameters = next(
        (statement, parameters)
        for statement, parameters in connection.statements
        if "UPDATE org_user_sessions" in statement
    )
    assert "login_source =" not in revoke_statement
    assert "login_source" not in revoke_parameters


def test_active_session_lookup_is_identity_wide_by_default():
    connection = RecordingConnection()

    get_active_session_for_username(connection, "player@example.com")

    statement, parameters = connection.statements[-1]
    assert "{source_clause}" not in statement
    assert "login_source =" not in statement
    assert "login_source" not in parameters


def test_read_only_membership_is_rejected_for_match_management(monkeypatch):
    monkeypatch.setattr(
        session_logic,
        "require_org_user_session",
        lambda *_args: {"username": "viewer@example.com", "login_source": "web_app"},
    )
    monkeypatch.setattr(session_logic, "_get_membership_row", lambda *_args: {"id": 1})
    monkeypatch.setattr(
        session_logic,
        "_serialize_org_user",
        lambda *_args, **_kwargs: {
            "role": "read_only",
            "organization_type": "club",
            "status": "approved",
        },
    )

    with pytest.raises(SessionAuthError) as error:
        authorize_organization_session(
            object(),
            {},
            12,
            required_capability=CAPABILITY_MATCH_MANAGE,
        )

    assert error.value.code == "SESSION_CAPABILITY_REQUIRED"


def test_club_scorer_cannot_mutate_a_match_owned_by_another_membership(monkeypatch):
    monkeypatch.setattr(
        session_logic,
        "_get_match_access_context",
        lambda *_args: {
            "tenant_id": 12,
            "sport": "squash",
            "status": "active",
            "scoring_owner_membership_id": 101,
            "scoring_locked_at": datetime.now(timezone.utc),
        },
    )
    monkeypatch.setattr(
        session_logic,
        "authorize_organization_session",
        lambda *_args, **_kwargs: {
            "membership": {
                "id": 202,
                "organization_id": 12,
                "organization_type": "club",
                "role": "scorer",
                "enabled_sports": ["squash"],
            }
        },
    )

    with pytest.raises(SessionAuthError) as error:
        session_logic.authorize_match_session(
            object(),
            {},
            "match-1",
            required_capability=CAPABILITY_MATCH_MANAGE,
        )

    assert error.value.code == "MATCH_SCORER_LOCKED"
    assert error.value.details == {"can_take_over": False}


def test_club_admin_must_explicitly_take_over_a_locked_match(monkeypatch):
    monkeypatch.setattr(
        session_logic,
        "_get_match_access_context",
        lambda *_args: {
            "tenant_id": 12,
            "sport": "squash",
            "status": "active",
            "scoring_owner_membership_id": 101,
            "scoring_locked_at": datetime.now(timezone.utc),
        },
    )
    monkeypatch.setattr(
        session_logic,
        "authorize_organization_session",
        lambda *_args, **_kwargs: {
            "membership": {
                "id": 303,
                "organization_id": 12,
                "organization_type": "club",
                "role": "admin",
                "enabled_sports": ["squash"],
            }
        },
    )

    with pytest.raises(SessionAuthError) as error:
        session_logic.authorize_match_session(
            object(),
            {},
            "match-1",
            required_capability=CAPABILITY_MATCH_MANAGE,
        )

    assert error.value.code == "MATCH_SCORER_LOCKED"
    assert error.value.details == {"can_take_over": True}


def test_match_owner_keeps_mutation_access(monkeypatch):
    monkeypatch.setattr(
        session_logic,
        "_get_match_access_context",
        lambda *_args: {
            "tenant_id": 12,
            "sport": "squash",
            "status": "active",
            "scoring_owner_membership_id": 101,
            "scoring_locked_at": datetime.now(timezone.utc),
        },
    )
    monkeypatch.setattr(
        session_logic,
        "authorize_organization_session",
        lambda *_args, **_kwargs: {
            "membership": {
                "id": 101,
                "organization_id": 12,
                "organization_type": "club",
                "role": "scorer",
                "enabled_sports": ["squash"],
            }
        },
    )

    context = session_logic.authorize_match_session(
        object(),
        {},
        "match-1",
        required_capability=CAPABILITY_MATCH_MANAGE,
    )

    assert context["scoring_access"] == {
        "locked": True,
        "is_owner": True,
        "can_score": True,
        "can_take_over": False,
    }


def test_club_admin_takeover_transfers_owner_and_appends_audit():
    connection = ScorerTakeoverConnection()
    context = {
        "membership": {
            "id": 303,
            "organization_id": 12,
            "organization_type": "club",
            "role": "admin",
        }
    }

    access = session_logic.take_over_match_scoring(connection, "match-1", context)

    assert connection.match["scoring_owner_membership_id"] == 303
    assert connection.commits == 1
    audit_parameters = next(
        parameters
        for statement, parameters in connection.statements
        if statement.startswith("INSERT INTO match_scorer_lock_audit")
    )
    assert audit_parameters["previous_membership_id"] == 101
    assert audit_parameters["new_membership_id"] == 303
    assert audit_parameters["action"] == "admin_takeover"
    assert access == {
        "locked": True,
        "is_owner": True,
        "can_score": True,
        "can_take_over": False,
    }
