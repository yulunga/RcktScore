from datetime import datetime, timedelta, timezone

import pytest

from common import scoreboard_logic
from common.scoreboard_logic import (
    DisplaySessionError,
    approve_scoreboard_pairing,
    create_scoreboard_pairing_request,
    exchange_scoreboard_pairing,
)
from common.session_logic import SessionAuthError
from functions.approve_scoreboard_pairing import handler as approve_handler


NOW = datetime.now(timezone.utc)


class _Cursor:
    def __init__(self, connection):
        self.connection = connection

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def execute(self, query, params=None):
        self.connection.executed.append((" ".join(query.split()), params or {}))

    def fetchone(self):
        if not self.connection.rows:
            return None
        return self.connection.rows.pop(0)


class _Connection:
    def __init__(self, *rows):
        self.rows = list(rows)
        self.executed = []
        self.commits = 0
        self.rollbacks = 0

    def cursor(self):
        return _Cursor(self)

    def commit(self):
        self.commits += 1

    def rollback(self):
        self.rollbacks += 1

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False


def _pairing(**overrides):
    row = {
        "id": 41,
        "expires_at": NOW + timedelta(seconds=90),
        "approved_at": None,
        "consumed_at": None,
    }
    row.update(overrides)
    return row


def test_admin_approval_is_single_use_and_court_is_tenant_scoped():
    connection = _Connection(_pairing(), {"id": 9})
    result = approve_scoreboard_pairing(connection, 500, 9, 88, "opaque-token")

    assert result["approved"] is True
    update = next(params for query, params in connection.executed if query.startswith("UPDATE scoreboard_pairing_requests"))
    assert update["organization_id"] == 500
    assert update["court_id"] == 9
    assert update["membership_id"] == 88
    assert connection.commits == 1


def test_pairing_creation_stores_hashes_not_raw_token(monkeypatch):
    connection = _Connection({"request_count": 0})
    raw_token = "raw-pairing-token-value-that-is-long-enough"
    monkeypatch.setattr(scoreboard_logic.secrets, "token_urlsafe", lambda _length: raw_token)

    pairing = create_scoreboard_pairing_request(
        connection,
        {"requestContext": {"http": {"sourceIp": "203.0.113.8"}}},
    )

    insert_params = next(
        params for query, params in connection.executed if query.startswith("INSERT INTO scoreboard_pairing_requests")
    )
    assert pairing["token"] == raw_token
    assert insert_params["token_hash"] != raw_token
    assert insert_params["request_ip_hash"] != "203.0.113.8"
    assert pairing["qr_value"].startswith("https://app.hitnscore.com/scoreboard?qr=")


def test_pairing_creation_is_rate_limited_per_source_ip():
    connection = _Connection({"request_count": scoreboard_logic.PAIRING_CREATE_RATE_LIMIT})
    with pytest.raises(DisplaySessionError) as raised:
        create_scoreboard_pairing_request(
            connection,
            {"requestContext": {"http": {"sourceIp": "203.0.113.8"}}},
        )
    assert raised.value.code == "PAIRING_RATE_LIMITED"
    assert connection.rollbacks == 1


def test_approval_rejects_expired_and_reused_tokens():
    with pytest.raises(DisplaySessionError) as expired:
        approve_scoreboard_pairing(
            _Connection(_pairing(expires_at=NOW - timedelta(seconds=1))), 500, 9, 88, "expired"
        )
    assert expired.value.code == "PAIRING_EXPIRED"

    with pytest.raises(DisplaySessionError) as reused:
        approve_scoreboard_pairing(
            _Connection(_pairing(consumed_at=NOW)), 500, 9, 88, "used"
        )
    assert reused.value.code == "PAIRING_ALREADY_USED"


def test_approval_rejects_court_from_wrong_tenant():
    with pytest.raises(DisplaySessionError) as raised:
        approve_scoreboard_pairing(_Connection(_pairing(), None), 500, 99, 88, "opaque-token")
    assert raised.value.code == "COURT_NOT_FOUND"


def test_exchange_waits_until_approved_then_consumes_once(monkeypatch):
    pending_connection = _Connection(
        {
            "pairing_id": 41,
            "expires_at": NOW + timedelta(seconds=90),
            "approved_at": None,
            "consumed_at": None,
            "exchange_attempts": 2,
            "id": None,
        }
    )
    pending = exchange_scoreboard_pairing(pending_connection, "opaque-token")
    assert pending["state"] == "pending"
    assert pending_connection.commits == 1

    approved_row = {
        "pairing_id": 41,
        "expires_at": NOW + timedelta(seconds=90),
        "approved_at": NOW,
        "consumed_at": None,
        "exchange_attempts": 3,
        "id": 9,
        "organization_name": 500,
        "court_name": "Court 1",
        "court_alias": "C1",
    }
    approved_connection = _Connection(approved_row)
    monkeypatch.setattr(
        scoreboard_logic,
        "_create_scoreboard_display_session_for_court",
        lambda _connection, court, commit=False: {
            "display_session_token": "display-token",
            "court": {"id": court["id"]},
        },
    )
    approved = exchange_scoreboard_pairing(approved_connection, "opaque-token")
    assert approved["state"] == "approved"
    assert approved["display_session_token"] == "display-token"
    assert any("SET consumed_at" in query for query, _params in approved_connection.executed)


def test_exchange_rejects_an_already_consumed_token():
    with pytest.raises(DisplaySessionError) as raised:
        exchange_scoreboard_pairing(
            _Connection(
                {
                    "pairing_id": 41,
                    "expires_at": NOW + timedelta(seconds=90),
                    "approved_at": NOW,
                    "consumed_at": NOW,
                    "exchange_attempts": 1,
                    "id": 9,
                }
            ),
            "used-token",
        )
    assert raised.value.code == "PAIRING_ALREADY_USED"


def test_pairing_handler_rejects_non_admin_members(monkeypatch):
    monkeypatch.setattr(approve_handler, "get_db_connection", lambda: _Connection())

    def reject_non_admin(*_args, **_kwargs):
        raise SessionAuthError(403, "SESSION_ADMIN_REQUIRED", "Administrator access is required for this action.")

    monkeypatch.setattr(approve_handler, "authorize_organization_session", reject_non_admin)
    response = approve_handler.lambda_handler(
        {
            "pathParameters": {"court_id": "9"},
            "body": '{"organization_id": 500, "token": "opaque-token"}',
        },
        None,
    )
    assert response["statusCode"] == 403
