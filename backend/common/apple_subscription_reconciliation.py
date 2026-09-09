import json
import os
from datetime import datetime, timedelta, timezone
from functools import lru_cache

from common.apple_purchase_verification import _configured_bundle_id
from common.apple_subscription_lifecycle import (
    AppleLifecycleError,
    apply_lifecycle_state,
    expire_elapsed_entitlements,
    verify_reconciliation_state,
)


DEFAULT_BATCH_SIZE = 25


@lru_cache(maxsize=1)
def _server_api_credentials():
    secret_arn = (os.getenv("APPLE_SERVER_API_SECRET_ARN") or "").strip()
    if not secret_arn:
        return None
    import boto3

    value = boto3.client("secretsmanager").get_secret_value(SecretId=secret_arn)
    secret = json.loads(value["SecretString"])
    required = ("private_key", "key_id", "issuer_id")
    missing = [key for key in required if not secret.get(key)]
    if missing:
        raise RuntimeError(f"Apple Server API secret is missing: {', '.join(missing)}")
    return secret


@lru_cache(maxsize=2)
def _api_client(environment_name):
    credentials = _server_api_credentials()
    if credentials is None:
        return None
    from appstoreserverlibrary.api_client import AppStoreServerAPIClient
    from appstoreserverlibrary.models.Environment import Environment

    environment = (
        Environment.PRODUCTION if environment_name == "Production" else Environment.SANDBOX
    )
    return AppStoreServerAPIClient(
        credentials["private_key"].encode("utf-8"),
        credentials["key_id"],
        credentials["issuer_id"],
        _configured_bundle_id(),
        environment,
    )


def _response_candidates(response):
    for group in getattr(response, "data", None) or []:
        for item in getattr(group, "lastTransactions", None) or []:
            yield item


def _verified_candidate(item, environment_name, expected_original_transaction_id):
    signed_transaction = getattr(item, "signedTransactionInfo", None)
    if not signed_transaction:
        return None
    purchase, renewal, status = verify_reconciliation_state(
        signed_transaction,
        getattr(item, "signedRenewalInfo", None),
        environment_name,
        getattr(item, "rawStatus", None) or getattr(item, "status", None),
    )
    if purchase.original_transaction_id != expected_original_transaction_id:
        return None
    status_priority = {1: 5, 4: 4, 3: 3, 2: 2, 5: 1}.get(status, 0)
    return (
        status_priority,
        purchase.expires_at,
        purchase,
        renewal,
        status,
        signed_transaction,
    )


def _record_reconciliation_failure(connection, subscription_id, message, now, retry_count):
    delay_hours = min(24, 2 ** min(max(retry_count, 0), 4))
    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE app_store_subscriptions
            SET reconciliation_error = %(error)s,
                reconciliation_retry_count = reconciliation_retry_count + 1,
                next_reconciliation_at = %(retry_at)s,
                updated_at = %(now)s
            WHERE id = %(subscription_id)s
            """,
            {
                "error": message[:2000],
                "retry_at": now + timedelta(hours=delay_hours),
                "now": now,
                "subscription_id": subscription_id,
            },
        )
    connection.commit()


def reconcile_subscriptions(connection, *, now=None, batch_size=DEFAULT_BATCH_SIZE):
    effective_now = now or datetime.now(timezone.utc)
    expired = expire_elapsed_entitlements(connection, now=effective_now)
    credentials = _server_api_credentials()
    if credentials is None:
        return {
            "expired": expired,
            "reconciled": 0,
            "failed": 0,
            "skipped": "APPLE_SERVER_API_SECRET_ARN is not configured",
        }

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id, original_transaction_id, environment,
                   reconciliation_retry_count
            FROM app_store_subscriptions
            WHERE next_reconciliation_at IS NULL
               OR next_reconciliation_at <= %(now)s
            ORDER BY COALESCE(next_reconciliation_at, '-infinity'::timestamptz), id
            LIMIT %(limit)s
            """,
            {"now": effective_now, "limit": int(batch_size)},
        )
        due = cursor.fetchall()

    reconciled = 0
    failed = 0
    for subscription in due:
        try:
            client = _api_client(subscription["environment"])
            response = client.get_all_subscription_statuses(
                subscription["original_transaction_id"]
            )
            candidates = []
            for item in _response_candidates(response):
                candidate = _verified_candidate(
                    item,
                    subscription["environment"],
                    subscription["original_transaction_id"],
                )
                if candidate:
                    candidates.append(candidate)
            if not candidates:
                raise AppleLifecycleError(
                    "APPLE_RECONCILIATION_EMPTY",
                    "Apple returned no matching subscription state.",
                    status_code=502,
                    retryable=True,
                )
            _, _, purchase, renewal, status, signed_transaction = max(
                candidates, key=lambda item: (item[0], item[1])
            )
            signed_at = (
                renewal.signed_at
                if renewal and renewal.signed_at
                else effective_now
            )
            apply_lifecycle_state(
                connection,
                purchase,
                renewal,
                apple_status=status,
                source="reconciliation",
                reason="apple_status_reconciliation",
                signed_transaction=signed_transaction,
                signed_at=signed_at,
                now=effective_now,
            )
            connection.commit()
            reconciled += 1
        except Exception as error:
            connection.rollback()
            _record_reconciliation_failure(
                connection,
                subscription["id"],
                str(error),
                effective_now,
                subscription.get("reconciliation_retry_count") or 0,
            )
            failed += 1

    return {"expired": expired, "reconciled": reconciled, "failed": failed}
