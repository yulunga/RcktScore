import json
from datetime import datetime, timedelta, timezone

from common.auth_logic import IdentityPasswordResetRequired
from functions.login import handler
from functions.login.handler import default_identity_membership, identity_first_login_enabled


class ConnectionContext:
    def __enter__(self):
        return object()

    def __exit__(self, exc_type, exc_value, traceback):
        return False


def test_identity_first_login_defaults_on(monkeypatch):
    monkeypatch.delenv("IDENTITY_FIRST_LOGIN_ENABLED", raising=False)
    assert identity_first_login_enabled() is True


def test_identity_first_login_can_restore_legacy_chooser(monkeypatch):
    monkeypatch.setenv("IDENTITY_FIRST_LOGIN_ENABLED", "false")
    assert identity_first_login_enabled() is False


def test_identity_session_prefers_personal_membership():
    club = {"id": 1, "organization_type": "club"}
    personal = {"id": 2, "organization_type": "personal"}
    assert default_identity_membership([club, personal]) == personal


def test_identity_session_uses_first_membership_without_personal_account():
    first_club = {"id": 1, "organization_type": "club"}
    second_club = {"id": 2, "organization_type": "club"}
    assert default_identity_membership([first_club, second_club]) == first_club


def test_login_detects_an_active_session_across_client_types(monkeypatch):
    observed = {}
    monkeypatch.setattr(handler, "get_db_connection", lambda: ConnectionContext())
    monkeypatch.setattr(
        handler,
        "authenticate_org_user_memberships",
        lambda *_args, **_kwargs: {
            "approved_memberships": [{"id": 1, "organization_id": 42, "organization_type": "club"}],
            "pending_memberships": [],
        },
    )

    def active_session(_connection, username, login_source=None):
        observed["username"] = username
        observed["login_source"] = login_source
        return {"login_source": "web_app", "last_seen_at": None}

    monkeypatch.setattr(handler, "get_active_session_for_username", active_session)

    response = handler.lambda_handler(
        {
            "body": json.dumps({
                "username": "player@example.com",
                "password": "secret",
                "client_type": "mobile_app",
            })
        },
        None,
    )

    assert response["statusCode"] == 409
    assert observed == {"username": "player@example.com", "login_source": None}
    assert '"client_type": "web_app"' in response["body"]


def test_partial_membership_password_match_returns_reset_required_and_sends_email(monkeypatch):
    observed = {}
    monkeypatch.setattr(handler, "get_db_connection", lambda: ConnectionContext())
    monkeypatch.setattr(
        handler,
        "authenticate_org_user_memberships",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(IdentityPasswordResetRequired()),
    )
    monkeypatch.setattr(
        handler,
        "request_password_reset",
        lambda db, username, **kwargs: observed.update(db=db, username=username, **kwargs),
    )
    monkeypatch.setenv("PASSWORD_RESET_FROM_EMAIL", "hello@hitnscore.com")
    monkeypatch.setenv("PASSWORD_RESET_BASE_URL", "https://app.hitnscore.com")

    response = handler.lambda_handler(
        {
            "headers": {"origin": "https://app.hitnscore.com"},
            "body": json.dumps({"username": "player@example.com", "password": "old-password"}),
        },
        None,
    )

    assert response["statusCode"] == 403
    assert '"code": "PASSWORD_RESET_REQUIRED"' in response["body"]
    assert observed["username"] == "player@example.com"
    assert observed["source_email"] == "hello@hitnscore.com"
    assert observed["reset_base_url"] == "https://app.hitnscore.com"


def test_invalid_login_logs_only_a_masked_email(monkeypatch):
    warnings = []
    monkeypatch.setattr(handler, "get_db_connection", lambda: ConnectionContext())
    monkeypatch.setattr(
        handler,
        "authenticate_org_user_memberships",
        lambda *_args, **_kwargs: {"approved_memberships": [], "pending_memberships": []},
    )
    monkeypatch.setattr(handler.logger, "warning", lambda message, *args: warnings.append((message, args)))

    response = handler.lambda_handler(
        {
            "headers": {"origin": "https://app.hitnscore.com"},
            "body": json.dumps({"username": "sarah@example.com", "password": "wrong"}),
        },
        None,
    )

    assert response["statusCode"] == 401
    assert warnings == [("Invalid login attempt for username=%s", ("s***@example.com",))]
    assert "sarah@example.com" not in repr(warnings)


def test_web_login_sets_httponly_cookie_and_omits_json_token(monkeypatch):
    monkeypatch.setattr(handler, "get_db_connection", lambda: ConnectionContext())
    monkeypatch.setattr(
        handler,
        "authenticate_org_user_memberships",
        lambda *_args, **_kwargs: {
            "approved_memberships": [{"id": 1, "username": "player@example.com", "organization_id": 42, "organization_type": "personal"}],
            "pending_memberships": [],
        },
    )
    monkeypatch.setattr(handler, "get_active_session_for_username", lambda *_args: None)
    monkeypatch.setattr(
        handler,
        "create_org_user_session",
        lambda *_args, **_kwargs: {
            "token": "opaque-secret",
            "csrf_token": "csrf-value",
            "expires_at": datetime.now(timezone.utc) + timedelta(days=30),
        },
    )
    response = handler.lambda_handler(
        {
            "headers": {"origin": "https://app.hitnscore.com"},
            "body": json.dumps({"username": "player@example.com", "password": "secret", "client_type": "web_app"}),
        },
        None,
    )
    assert response["statusCode"] == 200
    assert "opaque-secret" not in response["body"]
    assert '"csrf_token": "csrf-value"' in response["body"]
    cookie = response["cookies"][0]
    assert cookie.startswith("__Host-hitnscore_session=opaque-secret;")
    assert "Secure" in cookie and "HttpOnly" in cookie and "SameSite=Strict" in cookie and "Path=/" in cookie


def test_native_login_retains_json_bearer_without_cookie(monkeypatch):
    monkeypatch.setattr(handler, "get_db_connection", lambda: ConnectionContext())
    monkeypatch.setattr(
        handler,
        "authenticate_org_user_memberships",
        lambda *_args, **_kwargs: {
            "approved_memberships": [{"id": 1, "username": "player@example.com", "organization_id": 42, "organization_type": "personal"}],
            "pending_memberships": [],
        },
    )
    monkeypatch.setattr(handler, "get_active_session_for_username", lambda *_args: None)
    monkeypatch.setattr(
        handler,
        "create_org_user_session",
        lambda *_args, **_kwargs: {
            "token": "native-secret",
            "csrf_token": "unused",
            "expires_at": datetime.now(timezone.utc) + timedelta(days=30),
        },
    )
    response = handler.lambda_handler(
        {"body": json.dumps({"username": "player@example.com", "password": "secret", "client_type": "mobile_app"})},
        None,
    )
    assert '"session_token": "native-secret"' in response["body"]
    assert "cookies" not in response
