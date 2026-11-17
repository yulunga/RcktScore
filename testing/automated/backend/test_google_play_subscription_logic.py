import base64
import json
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest

from common.google_play_subscription_logic import (
    GooglePlayError,
    apply_subscription_state,
    decode_push_message,
    normalize_subscription,
    process_notification,
    verify_purchase,
)


NOW = datetime(2026, 11, 17, 12, 0, tzinfo=timezone.utc)
TOKEN = "play-purchase-token.abcdefghijklmnop"
ACCOUNT_TOKEN = str(uuid4())


@pytest.fixture(autouse=True)
def play_configuration(monkeypatch):
    monkeypatch.setenv("GOOGLE_PLAY_PURCHASES_ENABLED", "true")
    monkeypatch.setenv("GOOGLE_PLAY_PACKAGE_NAME", "com.hitnscore.mobile")
    monkeypatch.setenv("GOOGLE_PLAY_PERSONAL_PLUS_PRODUCT_ID", "personal_plus")
    monkeypatch.setenv("GOOGLE_PLAY_PERSONAL_PLUS_BASE_PLAN_ID", "yearly")


def _play(state="SUBSCRIPTION_STATE_ACTIVE", expires=NOW + timedelta(days=365), **overrides):
    data = {
        "subscriptionState": state,
        "startTime": "2026-11-17T11:59:00.123456789Z",
        "latestOrderId": "GPA.1234-5678-9012-34567",
        "acknowledgementState": "ACKNOWLEDGEMENT_STATE_PENDING",
        "externalAccountIdentifiers": {"obfuscatedExternalAccountId": ACCOUNT_TOKEN},
        "lineItems": [
            {
                "productId": "personal_plus",
                "expiryTime": expires.isoformat().replace("+00:00", "Z"),
                "autoRenewingPlan": {"autoRenewEnabled": state == "SUBSCRIPTION_STATE_ACTIVE"},
                "offerDetails": {"basePlanId": "yearly"},
            }
        ],
    }
    data.update(overrides)
    return data


class FakeClient:
    def __init__(self, data):
        self.data = data
        self.acknowledged = []
        self.fetches = 0

    def get_subscription(self, token):
        self.fetches += 1
        return self.data

    def acknowledge(self, product_id, token):
        self.acknowledged.append((product_id, token))


class FakeCursor:
    def __init__(self, connection):
        self.connection = connection
        self.result = None

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def execute(self, query, params=None):
        sql = " ".join(query.split())
        self.connection.executions.append((sql, params))
        self.result = None
        if sql.startswith("SELECT id, organization_id, metadata FROM subscription_sources"):
            self.result = self.connection.source
        elif 'FROM "SkwshOrgSettings"' in sql:
            self.result = self.connection.account
        elif sql.startswith("SELECT 1 FROM subscription_sources"):
            self.result = {"?column?": 1} if self.connection.other_entitled else None
        elif sql.startswith("INSERT INTO google_play_notifications"):
            if params["message_id"] in self.connection.seen_messages:
                self.result = None
            else:
                self.connection.seen_messages.add(params["message_id"])
                self.result = {"message_id": params["message_id"]}

    def fetchone(self):
        return self.result


class FakeConnection:
    def __init__(self, plan="personal_free", other_entitled=False, source=None):
        self.account = {
            "id": 501,
            "org_type": "personal",
            "plan": plan,
            "owner_username": "owner@hitnscore.com",
            "app_account_token": ACCOUNT_TOKEN,
        }
        self.source = source
        self.other_entitled = other_entitled
        self.executions = []
        self.seen_messages = set()
        self.commits = 0

    def cursor(self):
        return FakeCursor(self)

    def commit(self):
        self.commits += 1

    def rollback(self):
        pass

    def statements(self, prefix):
        return [params for sql, params in self.executions if sql.startswith(prefix)]


def test_normalize_parses_nanosecond_times_and_original_order():
    subscription = normalize_subscription(_play(latestOrderId="GPA.1234-5678-9012-34567..3"))
    assert subscription["started_at"] == datetime(2026, 11, 17, 11, 59, 0, 123456, tzinfo=timezone.utc)
    assert subscription["original_order_id"] == "GPA.1234-5678-9012-34567"
    assert subscription["base_plan_id"] == "yearly"
    assert subscription["account_token"] == ACCOUNT_TOKEN


def test_verified_purchase_upgrades_audits_and_acknowledges():
    connection = FakeConnection()
    client = FakeClient(_play())

    result = verify_purchase(connection, 501, "Owner@HitnScore.com", TOKEN, client=client, now=NOW)

    assert result["current_plan"] == "personal_plus"
    assert result["status"] == "active"
    source = connection.statements("INSERT INTO subscription_sources")[0]
    assert source["purchase_token"] == TOKEN and source["status"] == "active"
    assert connection.statements('UPDATE "SkwshOrgSettings"')[0]["target_plan"] == "personal_plus"
    audit = connection.statements("INSERT INTO subscription_entitlement_audit")[0]
    assert audit["source"] == "purchase" and audit["actor_type"] == "user"
    assert '"provider": "google_play"' in audit["metadata"]
    assert client.acknowledged == [("personal_plus", TOKEN)]


def test_monthly_base_plan_is_rejected():
    data = _play()
    data["lineItems"][0]["offerDetails"]["basePlanId"] = "monthly"
    with pytest.raises(GooglePlayError) as error:
        verify_purchase(FakeConnection(), 501, "owner@hitnscore.com", TOKEN, client=FakeClient(data), now=NOW)
    assert error.value.code == "GOOGLE_PLAY_PRODUCT_NOT_ALLOWED"


def test_purchase_for_another_account_is_rejected():
    connection = FakeConnection()
    connection.account = dict(connection.account, id=999)
    with pytest.raises(GooglePlayError) as error:
        verify_purchase(connection, 501, "owner@hitnscore.com", TOKEN, client=FakeClient(_play()), now=NOW)
    assert error.value.code in {"GOOGLE_PLAY_ACCOUNT_MISMATCH", "GOOGLE_PLAY_PURCHASE_NOT_ALLOWED"}
    assert not connection.statements('UPDATE "SkwshOrgSettings"')


def test_pending_payment_does_not_grant_access():
    connection = FakeConnection()
    with pytest.raises(GooglePlayError) as error:
        verify_purchase(
            connection, 501, "owner@hitnscore.com", TOKEN,
            client=FakeClient(_play(state="SUBSCRIPTION_STATE_PENDING")), now=NOW,
        )
    assert error.value.code == "GOOGLE_PLAY_PURCHASE_PENDING"
    assert not connection.statements("INSERT INTO subscription_sources")


def test_cancelled_auto_renew_keeps_access_until_expiry():
    connection = FakeConnection(plan="personal_plus")
    result = apply_subscription_state(
        connection, TOKEN, normalize_subscription(_play(state="SUBSCRIPTION_STATE_CANCELED")),
        source="notification", reason="google_play_notification_3", now=NOW,
    )
    assert result["status"] == "cancelled" and result["entitled"] is True
    assert result["current_plan"] == "personal_plus"
    assert not connection.statements('UPDATE "SkwshOrgSettings"')


def test_expiry_downgrades_unless_another_provider_still_pays():
    expired = normalize_subscription(
        _play(state="SUBSCRIPTION_STATE_EXPIRED", expires=NOW - timedelta(minutes=1))
    )

    alone = FakeConnection(plan="personal_plus")
    assert apply_subscription_state(
        alone, TOKEN, expired, source="reconciliation", reason="r", now=NOW
    )["current_plan"] == "personal_free"

    covered = FakeConnection(plan="personal_plus", other_entitled=True)
    assert apply_subscription_state(
        covered, TOKEN, expired, source="reconciliation", reason="r", now=NOW
    )["current_plan"] == "personal_plus"
    assert not covered.statements('UPDATE "SkwshOrgSettings"')


def test_revocation_removes_access_even_before_expiry():
    connection = FakeConnection(plan="personal_plus")
    result = apply_subscription_state(
        connection, TOKEN, normalize_subscription(_play()),
        source="notification", reason="google_play_notification_12", now=NOW, revoked=True,
    )
    assert result["status"] == "revoked" and result["current_plan"] == "personal_free"


def test_token_already_linked_to_another_account_is_rejected():
    connection = FakeConnection(source={"id": 1, "organization_id": 777, "metadata": {}})
    with pytest.raises(GooglePlayError) as error:
        apply_subscription_state(
            connection, TOKEN, normalize_subscription(_play()), source="notification", reason="r", now=NOW
        )
    assert error.value.code == "GOOGLE_PLAY_OWNERSHIP_MISMATCH"


def test_duplicate_notification_is_not_reprocessed():
    notification = {
        "packageName": "com.hitnscore.mobile",
        "subscriptionNotification": {"notificationType": 2, "purchaseToken": TOKEN, "subscriptionId": "personal_plus"},
    }
    body = {"message": {"messageId": "m-1", "data": base64.b64encode(json.dumps(notification).encode()).decode()}}
    message_id, decoded = decode_push_message(json.dumps(body))
    connection = FakeConnection()
    client = FakeClient(_play())

    process_notification(connection, message_id, decoded, client=client, now=NOW)
    second = process_notification(connection, message_id, decoded, client=client, now=NOW)

    assert second == {"message_id": "m-1", "duplicate": True}
    assert client.fetches == 1
    stored = connection.statements("INSERT INTO google_play_notifications")[0]
    assert TOKEN not in stored["payload"]
