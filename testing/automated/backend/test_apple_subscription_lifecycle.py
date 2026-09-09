from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest

from common.apple_purchase_verification import VerifiedApplePurchase
from common.apple_subscription_lifecycle import (
    _derive_status,
    _entitled,
    apply_lifecycle_state,
    normalize_renewal_info,
)


NOW = datetime(2026, 9, 9, 12, 0, tzinfo=timezone.utc)


@pytest.fixture(autouse=True)
def apple_configuration(monkeypatch):
    monkeypatch.setenv("APPLE_ALLOWED_ENVIRONMENTS", "Sandbox")
    monkeypatch.setenv("APPLE_BUNDLE_ID", "rcktScore.RcktScoreMobile")
    monkeypatch.setenv("APPLE_PERSONAL_PLUS_MONTHLY_PRODUCT_ID", "com.hitnscore.personalplus.monthly")
    monkeypatch.setenv("APPLE_PERSONAL_PLUS_YEARLY_PRODUCT_ID", "com.hitnscore.personalplus.yearly")


def _purchase(**overrides):
    values = {
        "transaction_id": "2000000123456789",
        "original_transaction_id": "2000000123456000",
        "app_account_token": str(uuid4()),
        "product_id": "com.hitnscore.personalplus.monthly",
        "bundle_id": "rcktScore.RcktScoreMobile",
        "app_apple_id": None,
        "app_transaction_id": "app-transaction-1",
        "environment": "Sandbox",
        "product_type": "Auto-Renewable Subscription",
        "transaction_reason": "RENEWAL",
        "purchased_at": NOW - timedelta(minutes=1),
        "expires_at": NOW + timedelta(days=30),
        "revoked_at": None,
        "is_upgraded": False,
        "decoded_payload": {},
    }
    values.update(overrides)
    return VerifiedApplePurchase(**values)


def _renewal(**overrides):
    values = {
        "originalTransactionId": "2000000123456000",
        "productId": "com.hitnscore.personalplus.monthly",
        "autoRenewProductId": "com.hitnscore.personalplus.monthly",
        "rawAutoRenewStatus": 1,
        "isInBillingRetryPeriod": False,
        "gracePeriodExpiresDate": None,
        "rawExpirationIntent": None,
        "renewalDate": int((NOW + timedelta(days=30)).timestamp() * 1000),
        "signedDate": int(NOW.timestamp() * 1000),
        "appAccountToken": None,
        "appTransactionId": None,
    }
    values.update(overrides)
    return normalize_renewal_info(SimpleNamespace(**values))


def test_renewal_remains_active_and_entitled():
    purchase = _purchase()
    renewal = _renewal()
    status = _derive_status("DID_RENEW", None, 1, purchase, renewal, NOW)
    assert status == "active"
    assert _entitled(status, purchase, renewal, NOW) is True


def test_cancelled_auto_renew_keeps_access_until_expiry():
    purchase = _purchase()
    renewal = _renewal(rawAutoRenewStatus=0)
    status = _derive_status("DID_CHANGE_RENEWAL_STATUS", "AUTO_RENEW_DISABLED", 1, purchase, renewal, NOW)
    assert renewal.auto_renew_enabled is False
    assert status == "active"
    assert _entitled(status, purchase, renewal, NOW) is True


def test_billing_retry_without_grace_removes_entitlement():
    purchase = _purchase()
    renewal = _renewal(isInBillingRetryPeriod=True)
    status = _derive_status("DID_FAIL_TO_RENEW", "BILLING_RETRY", 3, purchase, renewal, NOW)
    assert status == "billing_retry"
    assert _entitled(status, purchase, renewal, NOW) is False


def test_grace_period_keeps_entitlement_until_grace_deadline():
    purchase = _purchase(expires_at=NOW - timedelta(minutes=1))
    renewal = _renewal(
        isInBillingRetryPeriod=True,
        gracePeriodExpiresDate=int((NOW + timedelta(days=3)).timestamp() * 1000),
    )
    status = _derive_status("DID_FAIL_TO_RENEW", "GRACE_PERIOD", 4, purchase, renewal, NOW)
    assert status == "grace_period"
    assert _entitled(status, purchase, renewal, NOW) is True
    assert _entitled(status, purchase, renewal, NOW + timedelta(days=4)) is False


@pytest.mark.parametrize("notification_type", ["REFUND", "REVOKE"])
def test_refund_and_revocation_remove_entitlement_immediately(notification_type):
    purchase = _purchase(revoked_at=NOW)
    status = _derive_status(notification_type, None, 5, purchase, _renewal(), NOW)
    assert status == "revoked"
    assert _entitled(status, purchase, _renewal(), NOW) is False


def test_expiry_removes_entitlement():
    purchase = _purchase(expires_at=NOW - timedelta(seconds=1))
    status = _derive_status("EXPIRED", None, 2, purchase, _renewal(), NOW)
    assert status == "expired"
    assert _entitled(status, purchase, _renewal(), NOW) is False


class _StaleCursor:
    def __init__(self, connection):
        self.connection = connection
        self.row = None

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def execute(self, query, _params):
        normalized = " ".join(query.split())
        self.connection.executions.append(normalized)
        if "FROM app_store_subscriptions" in normalized:
            self.row = self.connection.subscription
        elif 'FROM "SkwshOrgSettings"' in normalized:
            self.row = self.connection.account
        else:
            self.row = None

    def fetchone(self):
        return self.row


class _StaleConnection:
    def __init__(self, purchase):
        self.executions = []
        self.subscription = {
            "id": 4,
            "organization_id": 50001,
            "username": "owner@hitnscore.com",
            "app_account_token": purchase.app_account_token,
            "original_transaction_id": purchase.original_transaction_id,
            "latest_transaction_id": "newer-transaction",
            "status": "active",
            "expires_at": NOW + timedelta(days=60),
            "last_apple_signed_at": NOW + timedelta(minutes=5),
        }
        self.account = {
            "id": 50001,
            "org_type": "personal",
            "plan": "personal_plus",
            "owner_username": "owner@hitnscore.com",
            "app_account_token": purchase.app_account_token,
        }

    def cursor(self):
        return _StaleCursor(self)


def test_out_of_order_notification_cannot_replace_newer_state():
    purchase = _purchase()
    connection = _StaleConnection(purchase)
    result = apply_lifecycle_state(
        connection,
        purchase,
        _renewal(),
        apple_status=2,
        source="notification",
        reason="EXPIRED",
        signed_transaction="signed-jws",
        signed_at=NOW,
        notification_uuid="notification-older",
        now=NOW,
    )
    assert result["stale"] is True
    assert result["plan_after"] == "personal_plus"
    assert not any(query.startswith("UPDATE") or query.startswith("INSERT") for query in connection.executions)
