import json

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
