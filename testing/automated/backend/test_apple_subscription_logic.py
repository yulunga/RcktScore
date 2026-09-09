from uuid import UUID, uuid4

import pytest

from common.apple_subscription_logic import (
    AppleSubscriptionError,
    get_or_create_purchase_context,
)


class _Cursor:
    def __init__(self, rows):
        self.rows = list(rows)
        self.executions = []

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def execute(self, query, params):
        self.executions.append((query, params))

    def fetchone(self):
        return self.rows.pop(0) if self.rows else None


class _Connection:
    def __init__(self, rows):
        self.test_cursor = _Cursor(rows)
        self.commits = 0

    def cursor(self):
        return self.test_cursor

    def commit(self):
        self.commits += 1


def _personal_account(token=None):
    return {
        "id": 50001,
        "org_type": "personal",
        "plan": "personal_free",
        "owner_username": "owner@hitnscore.com",
        "app_account_token": token,
    }


def test_existing_account_token_is_stable(monkeypatch):
    monkeypatch.setenv("APPLE_PURCHASES_ENABLED", "false")
    token = uuid4()
    connection = _Connection([_personal_account(token)])

    context = get_or_create_purchase_context(
        connection,
        50001,
        "OWNER@hitnscore.com",
    )

    assert context["app_account_token"] == str(token)
    assert context["current_plan"] == "personal_free"
    assert context["purchases_enabled"] is False
    assert len(connection.test_cursor.executions) == 1
    assert connection.commits == 1


def test_missing_account_token_is_created_once():
    generated = uuid4()
    connection = _Connection([
        _personal_account(None),
        {"app_account_token": generated},
    ])

    context = get_or_create_purchase_context(
        connection,
        50001,
        "owner@hitnscore.com",
    )

    assert UUID(context["app_account_token"]) == generated
    assert len(connection.test_cursor.executions) == 2
    assert "FOR UPDATE" in connection.test_cursor.executions[0][0]
    assert "app_account_token IS NULL" in connection.test_cursor.executions[1][0]


def test_club_or_non_owner_cannot_receive_purchase_context():
    club = {
        **_personal_account(),
        "org_type": "club",
        "owner_username": None,
    }
    with pytest.raises(AppleSubscriptionError, match="personal account"):
        get_or_create_purchase_context(_Connection([club]), 1, "user@hitnscore.com")

    with pytest.raises(AppleSubscriptionError, match="account owner"):
        get_or_create_purchase_context(
            _Connection([_personal_account()]),
            50001,
            "different@hitnscore.com",
        )

