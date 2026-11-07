from datetime import datetime, timezone

from functions.get_session_status import handler


class ConnectionContext:
    def __enter__(self):
        return object()

    def __exit__(self, exc_type, exc_value, traceback):
        return False


def test_session_status_returns_active_session(monkeypatch):
    monkeypatch.setattr(handler, "get_db_connection", lambda: ConnectionContext())
    monkeypatch.setattr(
        handler,
        "require_org_user_session",
        lambda _connection, _event: {
            "username": "player@example.com",
            "login_source": "web_app",
            "expires_at": datetime.now(timezone.utc),
            "csrf_token": "csrf-value",
        },
    )
    monkeypatch.setattr(handler, "get_org_users", lambda *_args: [])

    response = handler.lambda_handler({"headers": {"authorization": "Bearer token"}}, None)

    assert response["statusCode"] == 200
    assert '"active": true' in response["body"]
    assert '"login_source": "web_app"' in response["body"]
