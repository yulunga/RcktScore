from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

from common import apple_subscription_reconciliation as reconciliation


NOW = datetime(2026, 9, 10, 15, 47, 38, tzinfo=timezone.utc)


class _Cursor:
    def __init__(self, connection):
        self.connection = connection

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def execute(self, query, params):
        self.connection.executions.append((" ".join(query.split()), params))

    def fetchall(self):
        return list(self.connection.due)


class _Connection:
    def __init__(self):
        self.due = [
            {
                "id": 1,
                "original_transaction_id": "original-1",
                "environment": "Sandbox",
                "reconciliation_retry_count": 0,
            }
        ]
        self.executions = []
        self.commits = 0
        self.rollbacks = 0

    def cursor(self):
        return _Cursor(self)

    def commit(self):
        self.commits += 1

    def rollback(self):
        self.rollbacks += 1


def test_elapsed_subscription_is_checked_with_apple_before_local_expiry(monkeypatch):
    connection = _Connection()
    calls = []
    purchase = SimpleNamespace(
        original_transaction_id="original-1",
        expires_at=NOW + timedelta(hours=1),
    )
    renewal = SimpleNamespace(signed_at=NOW)

    class _Client:
        def get_all_subscription_statuses(self, original_transaction_id):
            assert original_transaction_id == "original-1"
            calls.append("apple")
            return object()

    monkeypatch.setattr(
        reconciliation,
        "_server_api_credentials",
        lambda: {"private_key": "key", "key_id": "id", "issuer_id": "issuer"},
    )
    monkeypatch.setattr(reconciliation, "_api_client", lambda _environment: _Client())
    monkeypatch.setattr(reconciliation, "_response_candidates", lambda _response: [object()])
    monkeypatch.setattr(
        reconciliation,
        "_verified_candidate",
        lambda _item, _environment, _original: (
            5,
            purchase.expires_at,
            purchase,
            renewal,
            1,
            "signed-transaction",
        ),
    )

    def apply_state(*_args, **_kwargs):
        calls.append("apply")

    def expire(_connection, *, now):
        assert now == NOW
        calls.append("expire")
        return 0

    monkeypatch.setattr(reconciliation, "apply_lifecycle_state", apply_state)
    monkeypatch.setattr(reconciliation, "expire_elapsed_entitlements", expire)

    result = reconciliation.reconcile_subscriptions(connection, now=NOW)

    assert result == {"expired": 0, "reconciled": 1, "failed": 0}
    assert calls == ["apple", "apply", "expire"]
    due_query = connection.executions[0][0]
    assert "status = 'active' AND expires_at <= %(now)s" in due_query
    assert "status IN ('grace_period', 'billing_retry')" in due_query

