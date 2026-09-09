import hashlib
import json
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from uuid import UUID

from common.apple_purchase_verification import (
    ApplePurchaseVerificationError,
    VerifiedApplePurchase,
    _allowed_environments,
    _configured_app_id,
    _configured_bundle_id,
    _milliseconds_to_datetime,
    _official_verifier,
    _string_value,
    normalize_verified_transaction,
)
from common.apple_subscription_logic import _configured_product_ids, _normalize_username


APPLE_NOTIFICATION_MAX_LENGTH = 262_144
RECONCILIATION_SUCCESS_INTERVAL = timedelta(hours=6)
STATUS_BY_APPLE_VALUE = {
    1: "active",
    2: "expired",
    3: "billing_retry",
    4: "grace_period",
    5: "revoked",
}


class AppleLifecycleError(Exception):
    def __init__(self, code, message, status_code=400, retryable=False):
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code
        self.retryable = retryable


@dataclass(frozen=True)
class VerifiedRenewalInfo:
    original_transaction_id: str | None
    product_id: str | None
    auto_renew_product_id: str | None
    auto_renew_enabled: bool | None
    is_in_billing_retry: bool
    grace_period_expires_at: datetime | None
    expiration_intent: int | None
    renewal_at: datetime | None
    signed_at: datetime | None
    app_account_token: str | None
    app_transaction_id: str | None
    decoded_payload: dict


@dataclass(frozen=True)
class VerifiedLifecycleNotification:
    notification_uuid: str
    notification_type: str
    subtype: str | None
    environment: str
    signed_at: datetime
    apple_status: int | None
    purchase: VerifiedApplePurchase | None
    renewal: VerifiedRenewalInfo | None
    signed_transaction: str | None
    decoded_payload: dict


def _required_text(value, field_name):
    normalized = (_string_value(value) or "").strip()
    if not normalized:
        raise AppleLifecycleError(
            "APPLE_NOTIFICATION_INVALID",
            f"The verified Apple notification is missing {field_name}.",
        )
    return normalized


def _raw_integer(value):
    if value is None:
        return None
    try:
        return int(getattr(value, "value", value))
    except (TypeError, ValueError):
        return None


def normalize_renewal_info(renewal):
    if renewal is None:
        return None
    raw_auto_renew = getattr(renewal, "rawAutoRenewStatus", None)
    if raw_auto_renew is None:
        raw_auto_renew = _raw_integer(getattr(renewal, "autoRenewStatus", None))
    raw_expiration_intent = getattr(renewal, "rawExpirationIntent", None)
    if raw_expiration_intent is None:
        raw_expiration_intent = _raw_integer(getattr(renewal, "expirationIntent", None))
    decoded = {
        "originalTransactionId": _string_value(getattr(renewal, "originalTransactionId", None)),
        "productId": _string_value(getattr(renewal, "productId", None)),
        "autoRenewProductId": _string_value(getattr(renewal, "autoRenewProductId", None)),
        "autoRenewStatus": raw_auto_renew,
        "isInBillingRetryPeriod": bool(getattr(renewal, "isInBillingRetryPeriod", False)),
        "gracePeriodExpiresDate": getattr(renewal, "gracePeriodExpiresDate", None),
        "expirationIntent": raw_expiration_intent,
        "renewalDate": getattr(renewal, "renewalDate", None),
        "signedDate": getattr(renewal, "signedDate", None),
        "appAccountToken": _string_value(getattr(renewal, "appAccountToken", None)),
        "appTransactionId": _string_value(getattr(renewal, "appTransactionId", None)),
    }
    return VerifiedRenewalInfo(
        original_transaction_id=decoded["originalTransactionId"],
        product_id=decoded["productId"],
        auto_renew_product_id=decoded["autoRenewProductId"],
        auto_renew_enabled=None if raw_auto_renew is None else raw_auto_renew == 1,
        is_in_billing_retry=decoded["isInBillingRetryPeriod"],
        grace_period_expires_at=_milliseconds_to_datetime(
            decoded["gracePeriodExpiresDate"],
            "gracePeriodExpiresDate",
        ),
        expiration_intent=raw_expiration_intent,
        renewal_at=_milliseconds_to_datetime(decoded["renewalDate"], "renewalDate"),
        signed_at=_milliseconds_to_datetime(decoded["signedDate"], "signedDate"),
        app_account_token=decoded["appAccountToken"],
        app_transaction_id=decoded["appTransactionId"],
        decoded_payload=decoded,
    )


def _verify_nested_state(verifier, data, environment_name):
    signed_transaction = getattr(data, "signedTransactionInfo", None)
    signed_renewal = getattr(data, "signedRenewalInfo", None)
    purchase = None
    renewal = None
    if signed_transaction:
        transaction = verifier.verify_and_decode_signed_transaction(signed_transaction)
        purchase = normalize_verified_transaction(
            transaction,
            environment_name,
            app_apple_id=getattr(data, "appAppleId", None),
        )
    if signed_renewal:
        renewal = normalize_renewal_info(
            verifier.verify_and_decode_renewal_info(signed_renewal)
        )
    if purchase and renewal:
        if renewal.original_transaction_id and (
            renewal.original_transaction_id != purchase.original_transaction_id
        ):
            raise AppleLifecycleError(
                "APPLE_NOTIFICATION_MISMATCH",
                "The signed transaction and renewal information do not match.",
                status_code=403,
            )
        if renewal.app_account_token and (
            UUID(renewal.app_account_token) != UUID(purchase.app_account_token)
        ):
            raise AppleLifecycleError(
                "APPLE_NOTIFICATION_MISMATCH",
                "The signed renewal belongs to a different application account.",
                status_code=403,
            )
        if renewal.app_transaction_id and (
            renewal.app_transaction_id != purchase.app_transaction_id
        ):
            raise AppleLifecycleError(
                "APPLE_NOTIFICATION_MISMATCH",
                "The signed renewal belongs to a different App Store account.",
                status_code=403,
            )
    return purchase, renewal, signed_transaction


def verify_notification(signed_payload):
    if not signed_payload or len(signed_payload) > APPLE_NOTIFICATION_MAX_LENGTH:
        raise AppleLifecycleError(
            "APPLE_NOTIFICATION_INVALID",
            "A valid signedPayload is required.",
        )
    try:
        from appstoreserverlibrary.signed_data_verifier import (
            VerificationException,
            VerificationStatus,
        )
    except ImportError as error:
        raise AppleLifecycleError(
            "APPLE_VERIFICATION_CONFIGURATION_ERROR",
            "Apple's App Store Server Library is not installed.",
            status_code=503,
        ) from error

    failures = []
    for environment_name in ("Sandbox", "Production"):
        if environment_name not in _allowed_environments():
            continue
        try:
            verifier = _official_verifier(environment_name)
            notification = verifier.verify_and_decode_notification(signed_payload)
            data = getattr(notification, "data", None)
            notification_type = _required_text(
                getattr(notification, "notificationType", None)
                or getattr(notification, "rawNotificationType", None),
                "notificationType",
            )
            notification_uuid = _required_text(
                getattr(notification, "notificationUUID", None),
                "notificationUUID",
            )
            signed_at = _milliseconds_to_datetime(
                getattr(notification, "signedDate", None),
                "signedDate",
                required=True,
            )
            subtype = _string_value(
                getattr(notification, "subtype", None)
                or getattr(notification, "rawSubtype", None)
            )
            purchase = None
            renewal = None
            signed_transaction = None
            apple_status = None
            if data is not None:
                purchase, renewal, signed_transaction = _verify_nested_state(
                    verifier,
                    data,
                    environment_name,
                )
                apple_status = getattr(data, "rawStatus", None)
                if apple_status is None:
                    apple_status = _raw_integer(getattr(data, "status", None))
            decoded = {
                "notificationUUID": notification_uuid,
                "notificationType": notification_type,
                "subtype": subtype,
                "environment": environment_name,
                "signedDate": getattr(notification, "signedDate", None),
                "status": apple_status,
                "bundleId": _string_value(getattr(data, "bundleId", None)) if data else None,
                "appAppleId": getattr(data, "appAppleId", None) if data else None,
            }
            return VerifiedLifecycleNotification(
                notification_uuid=notification_uuid,
                notification_type=notification_type,
                subtype=subtype,
                environment=environment_name,
                signed_at=signed_at,
                apple_status=apple_status,
                purchase=purchase,
                renewal=renewal,
                signed_transaction=signed_transaction,
                decoded_payload=decoded,
            )
        except AppleLifecycleError:
            raise
        except ApplePurchaseVerificationError as error:
            raise AppleLifecycleError(
                error.code,
                error.message,
                error.status_code,
                error.retryable,
            ) from error
        except VerificationException as error:
            failures.append(error)
            if error.status == VerificationStatus.RETRYABLE_VERIFICATION_FAILURE:
                raise AppleLifecycleError(
                    "APPLE_VERIFICATION_TEMPORARILY_UNAVAILABLE",
                    "Apple notification verification is temporarily unavailable.",
                    status_code=503,
                    retryable=True,
                ) from error
        except (TypeError, ValueError) as error:
            raise AppleLifecycleError(
                "APPLE_NOTIFICATION_INVALID",
                "The verified Apple notification contains invalid account identifiers.",
                status_code=403,
            ) from error
    raise AppleLifecycleError(
        "APPLE_NOTIFICATION_INVALID",
        "The notification signature, application identity, or environment is invalid.",
    ) from (failures[-1] if failures else None)


def verify_reconciliation_state(signed_transaction, signed_renewal, environment, status):
    if environment not in _allowed_environments():
        raise AppleLifecycleError(
            "APPLE_ENVIRONMENT_NOT_ALLOWED",
            "The reconciliation response uses a disabled environment.",
            status_code=403,
        )
    try:
        verifier = _official_verifier(environment)
        transaction = verifier.verify_and_decode_signed_transaction(signed_transaction)
        purchase = normalize_verified_transaction(transaction, environment)
        renewal = None
        if signed_renewal:
            renewal = normalize_renewal_info(
                verifier.verify_and_decode_renewal_info(signed_renewal)
            )
        return purchase, renewal, _raw_integer(status)
    except ApplePurchaseVerificationError as error:
        raise AppleLifecycleError(
            error.code,
            error.message,
            error.status_code,
            error.retryable,
        ) from error


def _validate_identity(purchase):
    if purchase.product_id not in set(_configured_product_ids().values()):
        raise AppleLifecycleError(
            "APPLE_PRODUCT_NOT_ALLOWED",
            "The lifecycle event is not for a supported Personal Plus product.",
            status_code=403,
        )
    if purchase.product_type != "Auto-Renewable Subscription":
        raise AppleLifecycleError(
            "APPLE_PRODUCT_TYPE_INVALID",
            "The lifecycle event is not for an auto-renewable subscription.",
            status_code=403,
        )
    if purchase.bundle_id != _configured_bundle_id():
        raise AppleLifecycleError(
            "APPLE_APP_MISMATCH",
            "The lifecycle event bundle ID does not match this application.",
            status_code=403,
        )
    if purchase.environment == "Production":
        configured_app_id = _configured_app_id(required=True)
        if purchase.app_apple_id not in (None, configured_app_id):
            raise AppleLifecycleError(
                "APPLE_APP_MISMATCH",
                "The lifecycle event Apple app ID does not match this application.",
                status_code=403,
            )


def _derive_status(notification_type, subtype, apple_status, purchase, renewal, now):
    if apple_status in STATUS_BY_APPLE_VALUE:
        return STATUS_BY_APPLE_VALUE[apple_status]
    if notification_type in {"REFUND", "REVOKE"} or purchase.revoked_at:
        return "revoked"
    if notification_type in {"EXPIRED", "GRACE_PERIOD_EXPIRED"}:
        return "expired"
    if notification_type == "DID_FAIL_TO_RENEW":
        if renewal and renewal.grace_period_expires_at and renewal.grace_period_expires_at > now:
            return "grace_period"
        return "billing_retry"
    if purchase.expires_at <= now:
        return "expired"
    return "active"


def _entitled(status, purchase, renewal, now):
    if status == "revoked" or purchase.revoked_at:
        return False
    if status == "grace_period":
        return bool(
            renewal
            and renewal.grace_period_expires_at
            and renewal.grace_period_expires_at > now
        )
    if status == "active":
        return purchase.expires_at > now
    return False


def apply_lifecycle_state(
    connection,
    purchase,
    renewal,
    *,
    apple_status,
    source,
    reason,
    signed_transaction,
    signed_at,
    notification_uuid=None,
    now=None,
):
    """Apply one verified Apple state and entitlement change atomically.

    The temporary _organization_id/_username attributes are not accepted on the
    immutable purchase dataclass, so transaction insertion is performed inline
    after resolving the Hit n Score account.
    """
    effective_now = now or datetime.now(timezone.utc)
    _validate_identity(purchase)
    try:
        account_token = UUID(purchase.app_account_token)
    except (TypeError, ValueError) as error:
        raise AppleLifecycleError(
            "APPLE_ACCOUNT_MISMATCH",
            "The lifecycle event has no valid app account token.",
            status_code=403,
        ) from error

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id, organization_id, username, app_account_token,
                   original_transaction_id, latest_transaction_id, status,
                   expires_at, last_apple_signed_at
            FROM app_store_subscriptions
            WHERE original_transaction_id = %(original_transaction_id)s
               OR app_account_token = %(app_account_token)s
            ORDER BY (original_transaction_id = %(original_transaction_id)s) DESC
            LIMIT 1
            FOR UPDATE
            """,
            {
                "original_transaction_id": purchase.original_transaction_id,
                "app_account_token": str(account_token),
            },
        )
        subscription = cursor.fetchone()
        if subscription and UUID(str(subscription["app_account_token"])) != account_token:
            raise AppleLifecycleError(
                "APPLE_SUBSCRIPTION_OWNERSHIP_MISMATCH",
                "This Apple subscription is linked to another account.",
                status_code=409,
            )

        cursor.execute(
            """
            SELECT id, org_type, plan, owner_username, app_account_token
            FROM "SkwshOrgSettings"
            WHERE app_account_token = %(app_account_token)s
            FOR UPDATE
            """,
            {"app_account_token": str(account_token)},
        )
        account = cursor.fetchone()
        if not account or account.get("org_type") != "personal":
            raise AppleLifecycleError(
                "APPLE_ACCOUNT_NOT_FOUND",
                "No personal account matches the verified Apple account token.",
                status_code=404,
            )
        if subscription and int(subscription["organization_id"]) != int(account["id"]):
            raise AppleLifecycleError(
                "APPLE_SUBSCRIPTION_OWNERSHIP_MISMATCH",
                "This Apple subscription is linked to another account.",
                status_code=409,
            )

        previous_status = subscription.get("status") if subscription else None
        previous_plan = account.get("plan")
        if previous_plan not in {"personal_free", "personal_plus"}:
            previous_plan = "personal_free"
        if (
            subscription
            and source == "notification"
            and subscription.get("last_apple_signed_at")
            and signed_at < subscription["last_apple_signed_at"]
        ):
            return {
                "organization_id": int(account["id"]),
                "status_before": previous_status,
                "status_after": previous_status,
                "plan_before": previous_plan,
                "plan_after": previous_plan,
                "transaction_id": purchase.transaction_id,
                "original_transaction_id": purchase.original_transaction_id,
                "expires_at": purchase.expires_at,
                "stale": True,
            }

        status = _derive_status(
            reason,
            None,
            apple_status,
            purchase,
            renewal,
            effective_now,
        )
        target_plan = "personal_plus" if _entitled(status, purchase, renewal, effective_now) else "personal_free"
        username = _normalize_username(account.get("owner_username"))

        cursor.execute(
            """
            INSERT INTO app_store_transactions (
                transaction_id, original_transaction_id, organization_id,
                account_username, app_account_token, product_id, bundle_id,
                app_apple_id, app_transaction_id, environment, product_type,
                transaction_reason, purchased_at, expires_at, revoked_at,
                signed_transaction_sha256, signed_transaction, decoded_payload,
                verified_at, source, notification_uuid
            ) VALUES (
                %(transaction_id)s, %(original_transaction_id)s, %(organization_id)s,
                %(username)s, %(app_account_token)s, %(product_id)s, %(bundle_id)s,
                %(app_apple_id)s, %(app_transaction_id)s, %(environment)s,
                %(product_type)s, %(transaction_reason)s, %(purchased_at)s,
                %(expires_at)s, %(revoked_at)s, %(signed_hash)s,
                %(signed_transaction)s, %(decoded_payload)s::jsonb,
                %(verified_at)s, %(source)s, %(notification_uuid)s
            )
            ON CONFLICT (transaction_id) DO NOTHING
            """,
            {
                "transaction_id": purchase.transaction_id,
                "original_transaction_id": purchase.original_transaction_id,
                "organization_id": int(account["id"]),
                "username": username,
                "app_account_token": str(account_token),
                "product_id": purchase.product_id,
                "bundle_id": purchase.bundle_id,
                "app_apple_id": purchase.app_apple_id,
                "app_transaction_id": purchase.app_transaction_id,
                "environment": purchase.environment,
                "product_type": purchase.product_type,
                "transaction_reason": purchase.transaction_reason,
                "purchased_at": purchase.purchased_at,
                "expires_at": purchase.expires_at,
                "revoked_at": purchase.revoked_at,
                "signed_hash": hashlib.sha256(signed_transaction.encode("utf-8")).hexdigest(),
                "signed_transaction": signed_transaction,
                "decoded_payload": json.dumps(purchase.decoded_payload),
                "verified_at": effective_now,
                "source": source,
                "notification_uuid": notification_uuid,
            },
        )

        renewal_payload = renewal.decoded_payload if renewal else {}
        values = {
            "organization_id": int(account["id"]),
            "username": username,
            "app_account_token": str(account_token),
            "original_transaction_id": purchase.original_transaction_id,
            "latest_transaction_id": purchase.transaction_id,
            "product_id": purchase.product_id,
            "bundle_id": purchase.bundle_id,
            "app_apple_id": purchase.app_apple_id,
            "app_transaction_id": purchase.app_transaction_id,
            "environment": purchase.environment,
            "status": status,
            "purchased_at": purchase.purchased_at,
            "expires_at": purchase.expires_at,
            "revoked_at": purchase.revoked_at,
            "auto_renew_enabled": renewal.auto_renew_enabled if renewal else None,
            "auto_renew_product_id": renewal.auto_renew_product_id if renewal else None,
            "grace_period_expires_at": renewal.grace_period_expires_at if renewal else None,
            "billing_retry_started_at": effective_now if status == "billing_retry" else None,
            "expiration_intent": renewal.expiration_intent if renewal else None,
            "latest_renewal_info": json.dumps(renewal_payload),
            "last_status_source": source,
            "last_apple_signed_at": signed_at,
            "last_notification_uuid": notification_uuid,
            "last_notification_at": effective_now if notification_uuid else None,
            "last_verified_at": effective_now,
            "next_reconciliation_at": effective_now + RECONCILIATION_SUCCESS_INTERVAL,
            "signed_hash": hashlib.sha256(signed_transaction.encode("utf-8")).hexdigest(),
        }
        if subscription:
            cursor.execute(
                """
                UPDATE app_store_subscriptions
                SET username = %(username)s,
                    original_transaction_id = %(original_transaction_id)s,
                    latest_transaction_id = %(latest_transaction_id)s,
                    product_id = %(product_id)s,
                    bundle_id = %(bundle_id)s,
                    app_apple_id = %(app_apple_id)s,
                    app_transaction_id = %(app_transaction_id)s,
                    environment = %(environment)s,
                    status = %(status)s,
                    purchased_at = %(purchased_at)s,
                    expires_at = %(expires_at)s,
                    revoked_at = %(revoked_at)s,
                    auto_renew_enabled = COALESCE(%(auto_renew_enabled)s, auto_renew_enabled),
                    auto_renew_product_id = COALESCE(%(auto_renew_product_id)s, auto_renew_product_id),
                    grace_period_expires_at = %(grace_period_expires_at)s,
                    billing_retry_started_at = CASE
                        WHEN %(status)s = 'billing_retry' THEN COALESCE(billing_retry_started_at, %(billing_retry_started_at)s)
                        ELSE NULL
                    END,
                    expiration_intent = %(expiration_intent)s,
                    latest_renewal_info = %(latest_renewal_info)s::jsonb,
                    last_status_source = %(last_status_source)s,
                    last_apple_signed_at = %(last_apple_signed_at)s,
                    last_notification_uuid = COALESCE(%(last_notification_uuid)s, last_notification_uuid),
                    last_notification_at = COALESCE(%(last_notification_at)s, last_notification_at),
                    last_signed_transaction_sha256 = %(signed_hash)s,
                    last_verified_at = %(last_verified_at)s,
                    last_reconciled_at = CASE WHEN %(last_status_source)s = 'reconciliation' THEN %(last_verified_at)s ELSE last_reconciled_at END,
                    reconciliation_error = NULL,
                    reconciliation_retry_count = 0,
                    next_reconciliation_at = %(next_reconciliation_at)s,
                    updated_at = %(last_verified_at)s
                WHERE id = %(subscription_id)s
                """,
                {**values, "subscription_id": subscription["id"]},
            )
        else:
            cursor.execute(
                """
                INSERT INTO app_store_subscriptions (
                    organization_id, username, app_account_token,
                    original_transaction_id, latest_transaction_id, product_id,
                    bundle_id, app_apple_id, app_transaction_id, environment,
                    status, purchased_at, expires_at, revoked_at,
                    auto_renew_enabled, auto_renew_product_id,
                    grace_period_expires_at, billing_retry_started_at,
                    expiration_intent, latest_renewal_info, last_status_source,
                    last_apple_signed_at, last_notification_uuid,
                    last_notification_at, last_signed_transaction_sha256,
                    last_verified_at, last_reconciled_at,
                    next_reconciliation_at, updated_at
                ) VALUES (
                    %(organization_id)s, %(username)s, %(app_account_token)s,
                    %(original_transaction_id)s, %(latest_transaction_id)s,
                    %(product_id)s, %(bundle_id)s, %(app_apple_id)s,
                    %(app_transaction_id)s, %(environment)s, %(status)s,
                    %(purchased_at)s, %(expires_at)s, %(revoked_at)s,
                    %(auto_renew_enabled)s, %(auto_renew_product_id)s,
                    %(grace_period_expires_at)s, %(billing_retry_started_at)s,
                    %(expiration_intent)s, %(latest_renewal_info)s::jsonb,
                    %(last_status_source)s, %(last_apple_signed_at)s,
                    %(last_notification_uuid)s, %(last_notification_at)s,
                    %(signed_hash)s, %(last_verified_at)s,
                    CASE WHEN %(last_status_source)s = 'reconciliation' THEN %(last_verified_at)s ELSE NULL END,
                    %(next_reconciliation_at)s, %(last_verified_at)s
                )
                """,
                values,
            )

        if previous_plan != target_plan:
            cursor.execute(
                """
                UPDATE "SkwshOrgSettings"
                SET plan = %(target_plan)s
                WHERE id = %(organization_id)s
                """,
                {"target_plan": target_plan, "organization_id": int(account["id"])},
            )
            cursor.execute(
                """
                INSERT INTO subscription_entitlement_audit (
                    organization_id, account_username, previous_plan, new_plan,
                    source, reason, effective_at, app_account_token,
                    original_transaction_id, transaction_id,
                    notification_uuid, actor_type, actor_identifier, metadata
                ) VALUES (
                    %(organization_id)s, %(username)s, %(previous_plan)s,
                    %(target_plan)s, %(source)s, %(reason)s, %(effective_at)s,
                    %(app_account_token)s, %(original_transaction_id)s,
                    %(transaction_id)s, %(notification_uuid)s, 'system',
                    'apple_subscription_lifecycle', %(metadata)s::jsonb
                )
                """,
                {
                    "organization_id": int(account["id"]),
                    "username": username,
                    "previous_plan": previous_plan,
                    "target_plan": target_plan,
                    "source": source,
                    "reason": reason.lower(),
                    "effective_at": effective_now,
                    "app_account_token": str(account_token),
                    "original_transaction_id": purchase.original_transaction_id,
                    "transaction_id": purchase.transaction_id,
                    "notification_uuid": notification_uuid,
                    "metadata": json.dumps(
                        {
                            "subscription_status": status,
                            "product_id": purchase.product_id,
                            "environment": purchase.environment,
                            "expires_at": purchase.expires_at.isoformat(),
                            "grace_period_expires_at": (
                                renewal.grace_period_expires_at.isoformat()
                                if renewal and renewal.grace_period_expires_at
                                else None
                            ),
                        }
                    ),
                },
            )

    return {
        "organization_id": int(account["id"]),
        "status_before": previous_status,
        "status_after": status,
        "plan_before": previous_plan,
        "plan_after": target_plan,
        "transaction_id": purchase.transaction_id,
        "original_transaction_id": purchase.original_transaction_id,
        "expires_at": purchase.expires_at,
        "stale": False,
    }


def process_notification(connection, signed_payload, *, now=None):
    effective_now = now or datetime.now(timezone.utc)
    notification = verify_notification(signed_payload)
    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO app_store_subscription_events (
                notification_uuid, original_transaction_id,
                notification_type, subtype, environment, signed_payload,
                verified_at, decoded_payload, processing_attempt_count
            ) VALUES (
                %(notification_uuid)s, %(original_transaction_id)s,
                %(notification_type)s, %(subtype)s, %(environment)s,
                %(signed_payload)s, %(verified_at)s,
                %(decoded_payload)s::jsonb, 1
            )
            ON CONFLICT (notification_uuid) DO UPDATE
            SET processing_attempt_count = app_store_subscription_events.processing_attempt_count + 1,
                next_processing_at = %(verified_at)s
            WHERE app_store_subscription_events.processed_at IS NULL
            RETURNING id
            """,
            {
                "notification_uuid": notification.notification_uuid,
                "original_transaction_id": (
                    notification.purchase.original_transaction_id
                    if notification.purchase
                    else None
                ),
                "notification_type": notification.notification_type,
                "subtype": notification.subtype,
                "environment": notification.environment,
                "signed_payload": signed_payload,
                "verified_at": effective_now,
                "decoded_payload": json.dumps(notification.decoded_payload),
            },
        )
        event = cursor.fetchone()
    if not event:
        connection.commit()
        return {"notification_uuid": notification.notification_uuid, "duplicate": True}

    if notification.notification_type == "TEST":
        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE app_store_subscription_events
                SET processed_at = %(processed_at)s,
                    processing_error = NULL
                WHERE id = %(event_id)s
                """,
                {"processed_at": effective_now, "event_id": event["id"]},
            )
        connection.commit()
        return {"notification_uuid": notification.notification_uuid, "test": True}

    if not notification.purchase or not notification.signed_transaction:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE app_store_subscription_events
                SET processed_at = %(processed_at)s,
                    processing_error = 'No subscription transaction data; acknowledged without an entitlement change.'
                WHERE id = %(event_id)s
                """,
                {"processed_at": effective_now, "event_id": event["id"]},
            )
        connection.commit()
        return {
            "notification_uuid": notification.notification_uuid,
            "ignored": True,
            "duplicate": False,
        }

    try:
        result = apply_lifecycle_state(
            connection,
            notification.purchase,
            notification.renewal,
            apple_status=notification.apple_status,
            source="notification",
            reason=notification.notification_type,
            signed_transaction=notification.signed_transaction,
            signed_at=notification.signed_at,
            notification_uuid=notification.notification_uuid,
            now=effective_now,
        )
    except AppleLifecycleError as error:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE app_store_subscription_events
                SET processing_error = %(processing_error)s,
                    next_processing_at = %(next_processing_at)s
                WHERE id = %(event_id)s
                """,
                {
                    "processing_error": f"{error.code}: {error.message}"[:2000],
                    "next_processing_at": effective_now + timedelta(minutes=5),
                    "event_id": event["id"],
                },
            )
        connection.commit()
        raise
    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE app_store_subscription_events
            SET organization_id = %(organization_id)s,
                app_account_token = %(app_account_token)s,
                transaction_id = %(transaction_id)s,
                subscription_status_before = %(status_before)s,
                subscription_status_after = %(status_after)s,
                plan_before = %(plan_before)s,
                plan_after = %(plan_after)s,
                processed_at = %(processed_at)s,
                processing_error = NULL,
                next_processing_at = NULL
            WHERE id = %(event_id)s
            """,
            {
                **result,
                "app_account_token": notification.purchase.app_account_token,
                "processed_at": effective_now,
                "event_id": event["id"],
            },
        )
    connection.commit()
    return {**result, "notification_uuid": notification.notification_uuid, "duplicate": False}


def expire_elapsed_entitlements(connection, *, now=None):
    effective_now = now or datetime.now(timezone.utc)
    expired_count = 0
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT s.id, s.organization_id, s.username, s.app_account_token,
                   s.original_transaction_id, s.latest_transaction_id,
                   s.status, s.expires_at, s.grace_period_expires_at,
                   o.plan
            FROM app_store_subscriptions AS s
            JOIN "SkwshOrgSettings" AS o ON o.id = s.organization_id
            WHERE (
                    s.status = 'active'
                    AND s.expires_at <= %(now)s
                  )
               OR (
                    s.status IN ('grace_period', 'billing_retry')
                    AND COALESCE(s.grace_period_expires_at, s.expires_at) <= %(now)s
                  )
            FOR UPDATE OF s, o
            """,
            {"now": effective_now},
        )
        rows = cursor.fetchall()
        for row in rows:
            cursor.execute(
                """
                UPDATE app_store_subscriptions
                SET status = 'expired',
                    last_status_source = 'reconciliation',
                    last_reconciled_at = %(now)s,
                    next_reconciliation_at = %(next_reconciliation_at)s,
                    updated_at = %(now)s
                WHERE id = %(subscription_id)s
                """,
                {
                    "subscription_id": row["id"],
                    "now": effective_now,
                    "next_reconciliation_at": effective_now + timedelta(hours=1),
                },
            )
            if row.get("plan") == "personal_plus":
                cursor.execute(
                    'UPDATE "SkwshOrgSettings" SET plan = \'personal_free\' WHERE id = %(organization_id)s',
                    {"organization_id": row["organization_id"]},
                )
                cursor.execute(
                    """
                    INSERT INTO subscription_entitlement_audit (
                        organization_id, account_username, previous_plan,
                        new_plan, source, reason, effective_at,
                        app_account_token, original_transaction_id,
                        transaction_id, actor_type, actor_identifier, metadata
                    ) VALUES (
                        %(organization_id)s, %(username)s, 'personal_plus',
                        'personal_free', 'reconciliation',
                        'verified_expiry_deadline_elapsed', %(now)s,
                        %(app_account_token)s, %(original_transaction_id)s,
                        %(transaction_id)s, 'system',
                        'subscription_expiry_worker', %(metadata)s::jsonb
                    )
                    """,
                    {
                        "organization_id": row["organization_id"],
                        "username": row["username"],
                        "now": effective_now,
                        "app_account_token": row["app_account_token"],
                        "original_transaction_id": row["original_transaction_id"],
                        "transaction_id": row["latest_transaction_id"],
                        "metadata": json.dumps(
                            {
                                "previous_status": row["status"],
                                "expires_at": row["expires_at"].isoformat(),
                                "grace_period_expires_at": (
                                    row["grace_period_expires_at"].isoformat()
                                    if row.get("grace_period_expires_at")
                                    else None
                                ),
                            }
                        ),
                    },
                )
            expired_count += 1
    connection.commit()
    return expired_count
