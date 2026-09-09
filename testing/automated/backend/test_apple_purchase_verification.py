from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest

from common.apple_purchase_verification import (
    ApplePurchaseVerificationError,
    OfficialAppleSignedDataVerifier,
    VerifiedApplePurchase,
    verify_and_apply_purchase,
)


NOW = datetime(2026, 9, 9, 12, 0, tzinfo=timezone.utc)


class _Verifier:
    def __init__(self, purchase):
        self.purchase = purchase

    def verify(self, _signed_transaction, _signed_app_transaction):
        return self.purchase


class _Cursor:
    def __init__(self, connection):
        self.connection = connection
        self.current_row = None

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def execute(self, query, params):
        normalized = " ".join(query.split())
        self.connection.executions.append((normalized, params))
        self.current_row = None

        if normalized.startswith('SELECT id, org_type, plan, owner_username, app_account_token FROM "SkwshOrgSettings"'):
            self.current_row = dict(self.connection.account)
        elif normalized.startswith("SELECT transaction_id, original_transaction_id"):
            self.current_row = self.connection.existing_transaction
        elif normalized.startswith("SELECT organization_id, app_account_token FROM app_store_subscriptions"):
            self.current_row = self.connection.existing_subscription
        elif normalized.startswith("INSERT INTO app_store_transactions"):
            self.connection.transaction_inserts += 1
        elif normalized.startswith("INSERT INTO app_store_subscriptions"):
            self.current_row = {
                "original_transaction_id": params["original_transaction_id"],
                "latest_transaction_id": params["latest_transaction_id"],
                "product_id": params["product_id"],
                "environment": params["environment"],
                "status": "active",
                "expires_at": params["expires_at"],
            }
        elif normalized.startswith('UPDATE "SkwshOrgSettings" SET plan'):
            self.connection.plan_updates += 1
        elif normalized.startswith("INSERT INTO subscription_entitlement_audit"):
            self.connection.audit_inserts += 1

    def fetchone(self):
        return self.current_row


class _Connection:
    def __init__(self, account, existing_transaction=None, existing_subscription=None):
        self.account = account
        self.existing_transaction = existing_transaction
        self.existing_subscription = existing_subscription
        self.executions = []
        self.transaction_inserts = 0
        self.plan_updates = 0
        self.audit_inserts = 0
        self.commits = 0

    def cursor(self):
        return _Cursor(self)

    def commit(self):
        self.commits += 1


def _purchase(token, **overrides):
    values = {
        "transaction_id": "2000000123456789",
        "original_transaction_id": "2000000123456000",
        "app_account_token": str(token),
        "product_id": "com.hitnscore.personalplus.monthly",
        "bundle_id": "rcktScore.RcktScoreMobile",
        "app_apple_id": None,
        "app_transaction_id": "app-transaction-1",
        "environment": "Sandbox",
        "product_type": "Auto-Renewable Subscription",
        "transaction_reason": "PURCHASE",
        "purchased_at": NOW - timedelta(minutes=1),
        "expires_at": NOW + timedelta(days=30),
        "revoked_at": None,
        "is_upgraded": False,
        "decoded_payload": {"environment": "Sandbox"},
    }
    values.update(overrides)
    return VerifiedApplePurchase(**values)


def _account(token, plan="personal_free"):
    return {
        "id": 50001,
        "org_type": "personal",
        "plan": plan,
        "owner_username": "owner@hitnscore.com",
        "app_account_token": token,
    }


@pytest.fixture(autouse=True)
def apple_configuration(monkeypatch):
    monkeypatch.setenv("APPLE_PURCHASES_ENABLED", "true")
    monkeypatch.setenv("APPLE_ALLOWED_ENVIRONMENTS", "Sandbox")
    monkeypatch.setenv("APPLE_BUNDLE_ID", "rcktScore.RcktScoreMobile")
    monkeypatch.setenv(
        "APPLE_PERSONAL_PLUS_MONTHLY_PRODUCT_ID",
        "com.hitnscore.personalplus.monthly",
    )
    monkeypatch.setenv(
        "APPLE_PERSONAL_PLUS_YEARLY_PRODUCT_ID",
        "com.hitnscore.personalplus.yearly",
    )


def test_verified_purchase_upgrades_and_audits_atomically():
    token = uuid4()
    connection = _Connection(_account(token))

    result = verify_and_apply_purchase(
        connection,
        50001,
        "OWNER@hitnscore.com",
        "signed-transaction",
        "signed-app-transaction",
        verifier=_Verifier(_purchase(token)),
        now=NOW,
        request_id="request-1",
    )

    assert result["current_plan"] == "personal_plus"
    assert result["idempotent"] is False
    assert connection.transaction_inserts == 1
    assert connection.plan_updates == 1
    assert connection.audit_inserts == 1
    assert connection.commits == 1


def test_duplicate_transaction_is_idempotent_and_does_not_repeat_audit():
    token = uuid4()
    existing_transaction = {
        "transaction_id": "2000000123456789",
        "organization_id": 50001,
        "app_account_token": token,
        "original_transaction_id": "2000000123456000",
        "product_id": "com.hitnscore.personalplus.monthly",
        "environment": "Sandbox",
        "expires_at": NOW + timedelta(days=30),
    }
    existing_subscription = {
        "organization_id": 50001,
        "app_account_token": token,
    }
    connection = _Connection(
        _account(token, plan="personal_plus"),
        existing_transaction=existing_transaction,
        existing_subscription=existing_subscription,
    )

    result = verify_and_apply_purchase(
        connection,
        50001,
        "owner@hitnscore.com",
        "signed-transaction",
        "signed-app-transaction",
        verifier=_Verifier(_purchase(token)),
        now=NOW,
    )

    assert result["idempotent"] is True
    assert connection.transaction_inserts == 0
    assert connection.plan_updates == 0
    assert connection.audit_inserts == 0
    assert connection.commits == 1


@pytest.mark.parametrize(
    ("override", "expected_code"),
    [
        ({"app_account_token": str(uuid4())}, "APPLE_ACCOUNT_MISMATCH"),
        ({"product_id": "invalid.product"}, "APPLE_PRODUCT_NOT_ALLOWED"),
        ({"bundle_id": "invalid.bundle"}, "APPLE_APP_MISMATCH"),
        ({"product_type": "Non-Consumable"}, "APPLE_PRODUCT_TYPE_INVALID"),
        ({"environment": "Production"}, "APPLE_ENVIRONMENT_NOT_ALLOWED"),
        ({"revoked_at": NOW - timedelta(minutes=1)}, "APPLE_TRANSACTION_REVOKED"),
        ({"expires_at": NOW - timedelta(seconds=1)}, "APPLE_SUBSCRIPTION_EXPIRED"),
        ({"is_upgraded": True}, "APPLE_TRANSACTION_SUPERSEDED"),
    ],
)
def test_invalid_or_mismatched_transactions_never_change_entitlement(override, expected_code):
    token = uuid4()
    connection = _Connection(_account(token))

    with pytest.raises(ApplePurchaseVerificationError) as raised:
        verify_and_apply_purchase(
            connection,
            50001,
            "owner@hitnscore.com",
            "signed-transaction",
            "signed-app-transaction",
            verifier=_Verifier(_purchase(token, **override)),
            now=NOW,
        )

    assert raised.value.code == expected_code
    assert connection.transaction_inserts == 0
    assert connection.plan_updates == 0
    assert connection.audit_inserts == 0
    assert connection.commits == 0


def test_disabled_purchase_gate_rejects_before_jws_processing(monkeypatch):
    monkeypatch.setenv("APPLE_PURCHASES_ENABLED", "false")
    token = uuid4()
    connection = _Connection(_account(token))

    with pytest.raises(ApplePurchaseVerificationError) as raised:
        verify_and_apply_purchase(
            connection,
            50001,
            "owner@hitnscore.com",
            "signed-transaction",
            "signed-app-transaction",
            verifier=_Verifier(_purchase(token)),
            now=NOW,
        )

    assert raised.value.code == "APPLE_PURCHASES_DISABLED"
    assert connection.executions == []


def test_official_verifier_rejects_unsigned_input():
    with pytest.raises(ApplePurchaseVerificationError) as raised:
        OfficialAppleSignedDataVerifier().verify(
            "not-a-signed-transaction",
            "not-a-signed-app-transaction",
        )

    assert raised.value.code == "APPLE_TRANSACTION_INVALID"
