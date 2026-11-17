"""Google Play Personal Plus subscriptions (yearly base plan only).

The Android client never grants access. It submits the Play purchase token; the
backend re-reads that token from the Google Play Developer API, validates the
package, product, base plan and the obfuscated account ID (the account's
app_account_token, shared with Apple), and records the verified state in the
provider-neutral subscription_sources ledger. Real-time developer notifications
and the hourly reconciler only trigger the same server-side re-read, so a forged
notification cannot change entitlement.
"""

import base64
import hashlib
import json
import os
import re
import time
from datetime import datetime, timezone
from urllib.parse import quote
from uuid import UUID

from common.apple_subscription_logic import _normalize_username
from common.subscription_entitlement import other_source_entitled


PROVIDER = "google_play"
API_ROOT = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
TOKEN_URL = "https://oauth2.googleapis.com/token"
API_SCOPE = "https://www.googleapis.com/auth/androidpublisher"
PURCHASE_TOKEN_PATTERN = re.compile(r"^[A-Za-z0-9._:-]{10,4096}$")
RECONCILE_BATCH_SIZE = 100
# Play subscription notification types that end access immediately (refund/revocation).
REVOKING_NOTIFICATION_TYPES = {12}

STATUS_BY_PLAY_STATE = {
    "SUBSCRIPTION_STATE_ACTIVE": "active",
    "SUBSCRIPTION_STATE_CANCELED": "cancelled",  # auto-renew off, paid until expiry
    "SUBSCRIPTION_STATE_IN_GRACE_PERIOD": "grace_period",
    "SUBSCRIPTION_STATE_ON_HOLD": "billing_retry",
    "SUBSCRIPTION_STATE_PAUSED": "expired",
    "SUBSCRIPTION_STATE_EXPIRED": "expired",
    "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED": "expired",
}
ENTITLED_STATUSES = {"active", "cancelled", "grace_period"}


class GooglePlayError(Exception):
    def __init__(self, code, message, status_code=400, retryable=False):
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code
        self.retryable = retryable


def _flag(name, default):
    return (os.getenv(name) or default).strip().lower() in {"1", "true", "yes", "on"}


def purchases_enabled():
    return _flag("GOOGLE_PLAY_PURCHASES_ENABLED", "false")


def configured_package_name():
    return (os.getenv("GOOGLE_PLAY_PACKAGE_NAME") or "com.hitnscore.mobile").strip()


def configured_product_id():
    return (os.getenv("GOOGLE_PLAY_PERSONAL_PLUS_PRODUCT_ID") or "personal_plus").strip()


def configured_base_plan_id():
    return (os.getenv("GOOGLE_PLAY_PERSONAL_PLUS_BASE_PLAN_ID") or "yearly").strip()


def _token_hash(purchase_token):
    return hashlib.sha256(purchase_token.encode("utf-8")).hexdigest()


def _parse_time(value):
    if not value:
        return None
    # Play returns RFC 3339 with up to nanosecond precision, e.g. 2027-01-01T00:00:00.123456789Z.
    text = str(value).replace("Z", "+00:00")
    text = re.sub(r"\.(\d{6})\d+", r".\1", text)
    return datetime.fromisoformat(text).astimezone(timezone.utc)


def validate_purchase_token(value):
    token = (value or "").strip() if isinstance(value, str) else ""
    if not PURCHASE_TOKEN_PATTERN.match(token):
        raise GooglePlayError("GOOGLE_PLAY_TOKEN_INVALID", "The purchase token is not valid.")
    return token


class GooglePlayClient:
    """Minimal Play Developer API client using a service account from Secrets Manager."""

    _credentials = None
    _access_token = None
    _access_token_expires = 0.0

    def _service_account(self):
        if GooglePlayClient._credentials is None:
            secret_arn = (os.getenv("GOOGLE_PLAY_SERVICE_ACCOUNT_SECRET_ARN") or "").strip()
            if not secret_arn:
                raise GooglePlayError(
                    "GOOGLE_PLAY_NOT_CONFIGURED",
                    "Google Play verification is not configured.",
                    status_code=503,
                    retryable=True,
                )
            import boto3

            value = boto3.client("secretsmanager").get_secret_value(SecretId=secret_arn)
            GooglePlayClient._credentials = json.loads(value["SecretString"])
        return GooglePlayClient._credentials

    def _bearer(self):
        if GooglePlayClient._access_token and time.time() < GooglePlayClient._access_token_expires - 60:
            return GooglePlayClient._access_token
        import jwt  # PyJWT ships with app-store-server-library.
        import requests

        account = self._service_account()
        issued = int(time.time())
        assertion = jwt.encode(
            {
                "iss": account["client_email"],
                "scope": API_SCOPE,
                "aud": account.get("token_uri") or TOKEN_URL,
                "iat": issued,
                "exp": issued + 3600,
            },
            account["private_key"],
            algorithm="RS256",
        )
        response = requests.post(
            account.get("token_uri") or TOKEN_URL,
            data={"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion},
            timeout=10,
        )
        if response.status_code != 200:
            raise GooglePlayError(
                "GOOGLE_PLAY_AUTH_FAILED",
                "Google Play could not be reached. Please try again.",
                status_code=503,
                retryable=True,
            )
        body = response.json()
        GooglePlayClient._access_token = body["access_token"]
        GooglePlayClient._access_token_expires = time.time() + int(body.get("expires_in", 3600))
        return GooglePlayClient._access_token

    def _request(self, method, url, **kwargs):
        import requests

        response = requests.request(
            method,
            url,
            headers={"Authorization": f"Bearer {self._bearer()}"},
            timeout=10,
            **kwargs,
        )
        if response.status_code in {400, 404, 410}:
            raise GooglePlayError(
                "GOOGLE_PLAY_PURCHASE_NOT_FOUND",
                "Google Play does not recognise this purchase.",
                status_code=422,
            )
        if response.status_code >= 300:
            raise GooglePlayError(
                "GOOGLE_PLAY_UNAVAILABLE",
                "Google Play could not verify the purchase. Please try again.",
                status_code=503,
                retryable=True,
            )
        return response.json() if response.content else {}

    def get_subscription(self, purchase_token):
        package = quote(configured_package_name(), safe="")
        return self._request(
            "GET",
            f"{API_ROOT}/{package}/purchases/subscriptionsv2/tokens/{quote(purchase_token, safe='')}",
        )

    def acknowledge(self, product_id, purchase_token):
        package = quote(configured_package_name(), safe="")
        self._request(
            "POST",
            f"{API_ROOT}/{package}/purchases/subscriptions/{quote(product_id, safe='')}"
            f"/tokens/{quote(purchase_token, safe='')}:acknowledge",
            json={},
        )


def normalize_subscription(data):
    """Reduce a SubscriptionPurchaseV2 response to the fields HitnScore relies on."""
    line_items = data.get("lineItems") or []
    item = line_items[0] if line_items else {}
    account_ids = data.get("externalAccountIdentifiers") or {}
    latest_order_id = data.get("latestOrderId") or item.get("latestSuccessfulOrderId")
    return {
        "state": data.get("subscriptionState") or "SUBSCRIPTION_STATE_UNSPECIFIED",
        "product_id": item.get("productId"),
        "base_plan_id": (item.get("offerDetails") or {}).get("basePlanId"),
        "expires_at": _parse_time(item.get("expiryTime")),
        "started_at": _parse_time(data.get("startTime")),
        "auto_renew_enabled": (item.get("autoRenewingPlan") or {}).get("autoRenewEnabled"),
        "account_token": account_ids.get("obfuscatedExternalAccountId"),
        "latest_order_id": latest_order_id,
        # Order IDs are GPA.x-y for the first charge and GPA.x-y..N for renewal N.
        "original_order_id": latest_order_id.split("..")[0] if latest_order_id else None,
        "linked_purchase_token": data.get("linkedPurchaseToken"),
        "test_purchase": "testPurchase" in data,
        "acknowledged": data.get("acknowledgementState") == "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
    }


def _validate_product(subscription):
    if subscription["product_id"] != configured_product_id() or (
        subscription["base_plan_id"] and subscription["base_plan_id"] != configured_base_plan_id()
    ):
        raise GooglePlayError(
            "GOOGLE_PLAY_PRODUCT_NOT_ALLOWED",
            "This purchase is not for the yearly Personal Plus subscription.",
            status_code=403,
        )
    if subscription["test_purchase"] and not _flag("GOOGLE_PLAY_ALLOW_TEST_PURCHASES", "true"):
        raise GooglePlayError(
            "GOOGLE_PLAY_TEST_PURCHASE_NOT_ALLOWED",
            "Test purchases are not accepted by this deployment.",
            status_code=403,
        )


def _status_and_entitlement(subscription, now, revoked):
    if revoked:
        return "revoked", False
    status = STATUS_BY_PLAY_STATE.get(subscription["state"])
    if status is None:
        return None, False
    expires_at = subscription["expires_at"]
    entitled = status in ENTITLED_STATUSES and expires_at is not None and expires_at > now
    if status in ENTITLED_STATUSES and not entitled:
        status = "expired"
    return status, entitled


def apply_subscription_state(
    connection,
    purchase_token,
    subscription,
    *,
    source,
    reason,
    now,
    expected_organization_id=None,
    actor_username=None,
    request_id=None,
    revoked=False,
):
    """Record one verified Play state and move the account plan atomically.

    Returns None when the token cannot be tied to a HitnScore personal account
    (for example a notification for a purchase the app never reported).
    """
    status, entitled = _status_and_entitlement(subscription, now, revoked)
    if status is None:
        return None
    token_hash = _token_hash(purchase_token)

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id, organization_id, metadata
            FROM subscription_sources
            WHERE provider = 'google_play'
              AND provider_subscription_id = %(purchase_token)s
            FOR UPDATE
            """,
            {"purchase_token": purchase_token},
        )
        existing = cursor.fetchone()

        account_token = subscription["account_token"]
        if account_token:
            try:
                account_token = str(UUID(account_token))
            except (TypeError, ValueError):
                account_token = None
        if account_token:
            cursor.execute(
                """
                SELECT id, org_type, plan, owner_username, app_account_token
                FROM "SkwshOrgSettings"
                WHERE app_account_token = %(app_account_token)s
                FOR UPDATE
                """,
                {"app_account_token": account_token},
            )
        else:
            # Purchases made outside the app (e.g. Play promo redemption) carry no
            # obfuscated ID; bind them to the record or the signed-in verifier.
            organization_id = (existing or {}).get("organization_id") or expected_organization_id
            if organization_id is None:
                return None
            cursor.execute(
                """
                SELECT id, org_type, plan, owner_username, app_account_token
                FROM "SkwshOrgSettings"
                WHERE id = %(organization_id)s
                FOR UPDATE
                """,
                {"organization_id": int(organization_id)},
            )
        account = cursor.fetchone()
        if not account or account.get("org_type") != "personal":
            if expected_organization_id is None:
                return None
            raise GooglePlayError(
                "GOOGLE_PLAY_ACCOUNT_MISMATCH",
                "This Google Play purchase belongs to a different HitnScore account.",
                status_code=403,
            )
        account_id = int(account["id"])
        if expected_organization_id is not None and account_id != int(expected_organization_id):
            raise GooglePlayError(
                "GOOGLE_PLAY_ACCOUNT_MISMATCH",
                "This Google Play purchase belongs to a different HitnScore account.",
                status_code=403,
            )
        if existing and int(existing["organization_id"]) != account_id:
            raise GooglePlayError(
                "GOOGLE_PLAY_OWNERSHIP_MISMATCH",
                "This Google Play subscription is already linked to another account.",
                status_code=409,
            )

        previous_metadata = (existing or {}).get("metadata") or {}
        renewed = bool(
            existing
            and subscription["latest_order_id"]
            and previous_metadata.get("latest_order_id") not in {None, subscription["latest_order_id"]}
        )
        metadata = {
            "package_name": configured_package_name(),
            "base_plan_id": subscription["base_plan_id"],
            "play_state": subscription["state"],
            "latest_order_id": subscription["latest_order_id"],
            "original_order_id": subscription["original_order_id"],
            "linked_purchase_token_sha256": (
                _token_hash(subscription["linked_purchase_token"])
                if subscription["linked_purchase_token"]
                else None
            ),
            "test_purchase": subscription["test_purchase"],
            "acknowledged": subscription["acknowledged"],
        }
        cursor.execute(
            """
            INSERT INTO subscription_sources (
                organization_id, provider, provider_subscription_id, plan,
                product_id, status, purchased_at, last_renewed_at,
                current_period_end, auto_renew_enabled, last_verified_at,
                metadata, updated_at
            ) VALUES (
                %(organization_id)s, 'google_play', %(purchase_token)s,
                'personal_plus', %(product_id)s, %(status)s, %(purchased_at)s,
                %(last_renewed_at)s, %(expires_at)s, %(auto_renew_enabled)s,
                %(now)s, %(metadata)s::jsonb, %(now)s
            )
            ON CONFLICT (provider, provider_subscription_id) DO UPDATE SET
                product_id = EXCLUDED.product_id,
                status = EXCLUDED.status,
                purchased_at = COALESCE(subscription_sources.purchased_at, EXCLUDED.purchased_at),
                last_renewed_at = COALESCE(EXCLUDED.last_renewed_at, subscription_sources.last_renewed_at),
                current_period_end = EXCLUDED.current_period_end,
                auto_renew_enabled = EXCLUDED.auto_renew_enabled,
                last_verified_at = EXCLUDED.last_verified_at,
                metadata = EXCLUDED.metadata,
                updated_at = EXCLUDED.updated_at
            """,
            {
                "organization_id": account_id,
                "purchase_token": purchase_token,
                "product_id": subscription["product_id"],
                "status": status,
                "purchased_at": subscription["started_at"],
                "last_renewed_at": now if renewed else None,
                "expires_at": subscription["expires_at"],
                "auto_renew_enabled": subscription["auto_renew_enabled"],
                "now": now,
                "metadata": json.dumps(metadata),
            },
        )

        if subscription["linked_purchase_token"]:
            # Resubscribe/upgrade: Play issues a new token and the old one stops renewing.
            cursor.execute(
                """
                UPDATE subscription_sources
                SET status = 'expired',
                    metadata = metadata || jsonb_build_object('superseded_by_sha256', %(token_hash)s::text),
                    updated_at = %(now)s
                WHERE provider = 'google_play'
                  AND provider_subscription_id = %(linked_token)s
                  AND organization_id = %(organization_id)s
                """,
                {
                    "token_hash": token_hash,
                    "linked_token": subscription["linked_purchase_token"],
                    "organization_id": account_id,
                    "now": now,
                },
            )

        previous_plan = account.get("plan")
        if previous_plan not in {"personal_free", "personal_plus"}:
            previous_plan = "personal_free"
        target_plan = "personal_plus" if entitled else "personal_free"
        if target_plan == "personal_free" and previous_plan == "personal_plus" and other_source_entitled(
            cursor,
            account_id,
            now,
            exclude_provider=PROVIDER,
            exclude_subscription_id=purchase_token,
        ):
            target_plan = "personal_plus"

        if target_plan != previous_plan:
            cursor.execute(
                """
                UPDATE "SkwshOrgSettings"
                SET plan = %(target_plan)s
                WHERE id = %(organization_id)s
                """,
                {"target_plan": target_plan, "organization_id": account_id},
            )
            cursor.execute(
                """
                INSERT INTO subscription_entitlement_audit (
                    organization_id, account_username, previous_plan, new_plan,
                    source, reason, effective_at, app_account_token,
                    original_transaction_id, transaction_id, actor_type,
                    actor_identifier, request_id, metadata
                ) VALUES (
                    %(organization_id)s, %(account_username)s, %(previous_plan)s,
                    %(target_plan)s, %(source)s, %(reason)s, %(now)s,
                    %(app_account_token)s, %(original_transaction_id)s,
                    %(transaction_id)s, %(actor_type)s, %(actor_identifier)s,
                    %(request_id)s, %(metadata)s::jsonb
                )
                """,
                {
                    "organization_id": account_id,
                    "account_username": _normalize_username(account.get("owner_username")),
                    "previous_plan": previous_plan,
                    "target_plan": target_plan,
                    "source": source,
                    "reason": reason,
                    "now": now,
                    "app_account_token": account.get("app_account_token"),
                    "original_transaction_id": subscription["original_order_id"],
                    "transaction_id": subscription["latest_order_id"],
                    "actor_type": "user" if actor_username else "system",
                    "actor_identifier": actor_username or "google_play_subscription_lifecycle",
                    "request_id": request_id,
                    "metadata": json.dumps(
                        {
                            "provider": PROVIDER,
                            "purchase_token_sha256": token_hash,
                            "subscription_status": status,
                            "product_id": subscription["product_id"],
                            "base_plan_id": subscription["base_plan_id"],
                            "expires_at": (
                                subscription["expires_at"].isoformat()
                                if subscription["expires_at"]
                                else None
                            ),
                            "test_purchase": subscription["test_purchase"],
                        }
                    ),
                },
            )

    connection.commit()
    return {
        "organization_id": account_id,
        "provider": PROVIDER,
        "status": status,
        "entitled": entitled,
        "plan_before": previous_plan,
        "current_plan": target_plan,
        "product_id": subscription["product_id"],
        "base_plan_id": subscription["base_plan_id"],
        "expires_at": subscription["expires_at"].isoformat() if subscription["expires_at"] else None,
        "auto_renew_enabled": subscription["auto_renew_enabled"],
    }


def _acknowledge_if_needed(client, subscription, purchase_token, logger=None):
    # Play refunds purchases left unacknowledged for three days; reconciliation retries this.
    if subscription["acknowledged"]:
        return True
    try:
        client.acknowledge(subscription["product_id"], purchase_token)
        return True
    except GooglePlayError as error:
        if logger:
            logger.warning("Google Play acknowledgement failed code=%s", error.code)
        return False


def get_purchase_context(connection, organization_id, username):
    """Account token for BillingFlowParams.setObfuscatedAccountId plus product config."""
    from common.apple_subscription_logic import AppleSubscriptionError, get_or_create_purchase_context

    try:
        context = get_or_create_purchase_context(connection, organization_id, username)
    except AppleSubscriptionError as error:
        raise GooglePlayError("GOOGLE_PLAY_PURCHASE_NOT_ALLOWED", str(error).replace("Apple ", ""), status_code=403) from error
    return {
        "organization_id": context["organization_id"],
        "obfuscated_account_id": context["app_account_token"],
        "current_plan": context["current_plan"],
        "purchases_enabled": purchases_enabled(),
        "package_name": configured_package_name(),
        "product_id": configured_product_id(),
        "base_plan_id": configured_base_plan_id(),
    }


def verify_purchase(
    connection,
    organization_id,
    username,
    purchase_token,
    *,
    client=None,
    now=None,
    request_id=None,
    logger=None,
):
    if not purchases_enabled():
        raise GooglePlayError(
            "GOOGLE_PLAY_PURCHASES_DISABLED",
            "Google Play purchases are not enabled for this deployment.",
            status_code=503,
        )
    purchase_token = validate_purchase_token(purchase_token)
    normalized_username = _normalize_username(username)

    with connection.cursor() as cursor:
        cursor.execute(
            'SELECT org_type, owner_username FROM "SkwshOrgSettings" WHERE id = %(organization_id)s',
            {"organization_id": int(organization_id)},
        )
        account = cursor.fetchone()
    if (
        not account
        or account.get("org_type") != "personal"
        or _normalize_username(account.get("owner_username")) != normalized_username
    ):
        raise GooglePlayError(
            "GOOGLE_PLAY_PURCHASE_NOT_ALLOWED",
            "Only the personal account owner can verify a Personal Plus purchase.",
            status_code=403,
        )

    client = client or GooglePlayClient()
    subscription = normalize_subscription(client.get_subscription(purchase_token))
    _validate_product(subscription)
    if subscription["state"] == "SUBSCRIPTION_STATE_PENDING":
        raise GooglePlayError(
            "GOOGLE_PLAY_PURCHASE_PENDING",
            "Google Play is still processing this payment. Personal Plus will unlock once it completes.",
            status_code=409,
            retryable=True,
        )
    effective_now = now or datetime.now(timezone.utc)
    result = apply_subscription_state(
        connection,
        purchase_token,
        subscription,
        source="purchase",
        reason="verified_google_play_subscription",
        now=effective_now,
        expected_organization_id=int(organization_id),
        actor_username=normalized_username,
        request_id=request_id,
    )
    if not result["entitled"]:
        raise GooglePlayError(
            "GOOGLE_PLAY_SUBSCRIPTION_INACTIVE",
            "This Google Play subscription is no longer active.",
            status_code=422,
        )
    result["acknowledged"] = _acknowledge_if_needed(client, subscription, purchase_token, logger)
    return result


def decode_push_message(body):
    """Return (message_id, developer_notification) from a Pub/Sub push body."""
    try:
        payload = body if isinstance(body, dict) else json.loads(body or "{}")
        message = payload["message"]
        message_id = str(message.get("messageId") or message.get("message_id"))
        notification = json.loads(base64.b64decode(message["data"]).decode("utf-8"))
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        raise GooglePlayError("GOOGLE_PLAY_NOTIFICATION_INVALID", "The notification body is not valid.") from error
    if not message_id or message_id == "None":
        raise GooglePlayError("GOOGLE_PLAY_NOTIFICATION_INVALID", "The notification has no message ID.")
    return message_id, notification


def process_notification(connection, message_id, notification, *, client=None, now=None):
    """Handle one RTDN. The notification is only a trigger; state is re-read from Google."""
    if notification.get("packageName") != configured_package_name():
        return {"message_id": message_id, "ignored": "package_mismatch"}

    subscription_event = notification.get("subscriptionNotification") or {}
    voided = notification.get("voidedPurchaseNotification") or {}
    purchase_token = subscription_event.get("purchaseToken") or voided.get("purchaseToken")
    notification_type = subscription_event.get("notificationType")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO google_play_notifications (
                message_id, notification_type, voided, purchase_token_sha256, payload
            ) VALUES (
                %(message_id)s, %(notification_type)s, %(voided)s,
                %(token_hash)s, %(payload)s::jsonb
            )
            ON CONFLICT (message_id) DO NOTHING
            RETURNING message_id
            """,
            {
                "message_id": message_id,
                "notification_type": notification_type,
                "voided": bool(voided),
                "token_hash": _token_hash(purchase_token) if purchase_token else None,
                # The raw token is stored in subscription_sources only.
                "payload": json.dumps(
                    {
                        key: value
                        for key, value in notification.items()
                        if key not in {"subscriptionNotification", "voidedPurchaseNotification"}
                    }
                ),
            },
        )
        inserted = cursor.fetchone()
    connection.commit()
    if inserted is None:
        return {"message_id": message_id, "duplicate": True}
    if not purchase_token or (voided and voided.get("productType") not in {None, 1}):
        # Test notifications and one-time product voids carry nothing to apply.
        return {"message_id": message_id, "ignored": "no_subscription"}

    client = client or GooglePlayClient()
    try:
        subscription = normalize_subscription(client.get_subscription(validate_purchase_token(purchase_token)))
    except GooglePlayError:
        _mark_notification(connection, message_id, "unverifiable")
        raise
    if subscription["product_id"] != configured_product_id():
        _mark_notification(connection, message_id, "product_mismatch")
        return {"message_id": message_id, "ignored": "product_mismatch"}

    result = apply_subscription_state(
        connection,
        purchase_token,
        subscription,
        source="notification",
        reason=f"google_play_notification_{'voided' if voided else notification_type}",
        now=now or datetime.now(timezone.utc),
        revoked=bool(voided) or notification_type in REVOKING_NOTIFICATION_TYPES,
    )
    _mark_notification(connection, message_id, "applied" if result else "unmatched_account")
    if result and result["entitled"]:
        _acknowledge_if_needed(client, subscription, purchase_token)
    return {"message_id": message_id, "result": result}


def _mark_notification(connection, message_id, outcome):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE google_play_notifications
            SET outcome = %(outcome)s, processed_at = now()
            WHERE message_id = %(message_id)s
            """,
            {"message_id": message_id, "outcome": outcome},
        )
    connection.commit()


def reconcile_subscriptions(connection, *, client=None, now=None, logger=None):
    """Re-read Play state for live tokens near or past expiry, or not checked for a day."""
    effective_now = now or datetime.now(timezone.utc)
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT provider_subscription_id
            FROM subscription_sources
            WHERE provider = 'google_play'
              AND status IN ('active', 'grace_period', 'billing_retry', 'cancelled')
              AND (
                    current_period_end <= %(now)s + interval '1 day'
                    OR last_verified_at <= %(now)s - interval '1 day'
                    OR COALESCE((metadata->>'acknowledged')::boolean, false) = false
                  )
            ORDER BY last_verified_at ASC
            LIMIT %(limit)s
            """,
            {"now": effective_now, "limit": RECONCILE_BATCH_SIZE},
        )
        tokens = [row["provider_subscription_id"] for row in cursor.fetchall()]

    client = client or GooglePlayClient()
    summary = {"checked": 0, "failed": 0}
    for token in tokens:
        try:
            subscription = normalize_subscription(client.get_subscription(token))
            result = apply_subscription_state(
                connection,
                token,
                subscription,
                source="reconciliation",
                reason="google_play_reconciliation",
                now=effective_now,
            )
            if result and result["entitled"]:
                _acknowledge_if_needed(client, subscription, token, logger)
            summary["checked"] += 1
        except Exception as error:  # one bad token must not stop the batch
            connection.rollback()
            summary["failed"] += 1
            if logger:
                logger.warning(
                    "Google Play reconciliation failed token_sha256=%s error=%s",
                    _token_hash(token)[:12],
                    getattr(error, "code", type(error).__name__),
                )
    return summary


def verify_push_authorization(authorization_header):
    """Verify the Pub/Sub push OIDC token. Fails closed when not configured."""
    audience = (os.getenv("GOOGLE_PLAY_PUSH_AUDIENCE") or "").strip()
    service_account = (os.getenv("GOOGLE_PLAY_PUSH_SERVICE_ACCOUNT") or "").strip().lower()
    if not audience or not service_account:
        raise GooglePlayError(
            "GOOGLE_PLAY_NOTIFICATIONS_NOT_CONFIGURED",
            "Google Play notifications are not configured.",
            status_code=503,
        )
    header = authorization_header or ""
    if not header.lower().startswith("bearer "):
        raise GooglePlayError("GOOGLE_PLAY_NOTIFICATION_UNAUTHORIZED", "Missing push token.", status_code=401)
    import jwt

    token = header[7:].strip()
    try:
        signing_key = jwt.PyJWKClient("https://www.googleapis.com/oauth2/v3/certs").get_signing_key_from_jwt(token)
        claims = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience=audience,
            issuer=["https://accounts.google.com", "accounts.google.com"],
        )
    except jwt.PyJWTError as error:
        raise GooglePlayError("GOOGLE_PLAY_NOTIFICATION_UNAUTHORIZED", "Invalid push token.", status_code=401) from error
    if str(claims.get("email", "")).lower() != service_account or not claims.get("email_verified"):
        raise GooglePlayError("GOOGLE_PLAY_NOTIFICATION_UNAUTHORIZED", "Unexpected push sender.", status_code=401)
