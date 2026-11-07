import json
from datetime import datetime, timedelta, timezone

from common.utils import success_response
from functions.root_admin_login import handler as root_login_handler


class ConnectionContext:
    def __enter__(self):
        return object()

    def __exit__(self, exc_type, exc_value, traceback):
        return False


def test_api_responses_use_exact_credentialed_cors(monkeypatch):
    monkeypatch.setenv("WEB_APP_ORIGIN", "https://app.hitnscore.com")
    response = success_response(200, {"ok": True})
    assert response["headers"]["Access-Control-Allow-Origin"] == "https://app.hitnscore.com"
    assert response["headers"]["Access-Control-Allow-Credentials"] == "true"
    assert response["headers"]["Vary"] == "Origin"
    assert response["headers"]["Cache-Control"] == "no-store"
    assert "X-CSRF-Token" in response["headers"]["Access-Control-Allow-Headers"]


def test_root_admin_login_uses_separate_cookie_and_no_json_token(monkeypatch):
    monkeypatch.setattr(root_login_handler, "get_db_connection", lambda: ConnectionContext())
    monkeypatch.setattr(
        root_login_handler,
        "authenticate_root_admin",
        lambda *_args: {"id": 7, "username": "root@example.com", "role": "root_admin"},
    )
    monkeypatch.setattr(
        root_login_handler,
        "create_root_admin_session",
        lambda *_args: {
            "token": "rra_secret-value",
            "csrf_token": "root-csrf",
            "expires_at": datetime.now(timezone.utc) + timedelta(hours=8),
        },
    )
    response = root_login_handler.lambda_handler(
        {
            "headers": {"origin": "https://app.hitnscore.com"},
            "body": json.dumps({"username": "root@example.com", "password": "secret"}),
        },
        None,
    )
    assert response["statusCode"] == 200
    assert "rra_secret-value" not in response["body"]
    assert '"csrf_token": "root-csrf"' in response["body"]
    cookie = response["cookies"][0]
    assert cookie.startswith("__Host-hitnscore_root_admin=rra_secret-value;")
    assert "Secure" in cookie and "HttpOnly" in cookie and "SameSite=Strict" in cookie and "Path=/" in cookie


def test_root_admin_login_rejects_wrong_origin_before_authentication(monkeypatch):
    monkeypatch.setattr(root_login_handler, "get_db_connection", lambda: ConnectionContext())
    response = root_login_handler.lambda_handler(
        {
            "headers": {"origin": "https://attacker.example"},
            "body": json.dumps({"username": "root@example.com", "password": "secret"}),
        },
        None,
    )
    assert response["statusCode"] == 403
    assert '"code": "ORIGIN_REJECTED"' in response["body"]
