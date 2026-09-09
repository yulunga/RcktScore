import hashlib
import json
import os
from dataclasses import dataclass
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path
from uuid import UUID

from common.apple_subscription_logic import (
    _configured_product_ids,
    _normalize_username,
    _purchases_enabled,
)


APPLE_TRANSACTION_MAX_LENGTH = 131_072
SUPPORTED_ENVIRONMENTS = {"Sandbox", "Production"}


class ApplePurchaseVerificationError(Exception):
    def __init__(self, code, message, status_code=400, retryable=False):
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code
        self.retryable = retryable


@dataclass(frozen=True)
class VerifiedApplePurchase:
    transaction_id: str
    original_transaction_id: str
    app_account_token: str
    product_id: str
    bundle_id: str
    app_apple_id: int | None
    app_transaction_id: str
    environment: str
    product_type: str
    transaction_reason: str | None
    purchased_at: datetime
    expires_at: datetime
    revoked_at: datetime | None
    is_upgraded: bool
    decoded_payload: dict


def _string_value(value):
    if value is None:
        return None
    return str(getattr(value, "value", value))


def _milliseconds_to_datetime(value, field_name, required=False):
    if value is None:
        if required:
            raise ApplePurchaseVerificationError(
                "APPLE_TRANSACTION_INVALID",
                f"The verified Apple transaction is missing {field_name}.",
            )
        return None
    try:
        return datetime.fromtimestamp(int(value) / 1000, tz=timezone.utc)
    except (TypeError, ValueError, OSError) as error:
        raise ApplePurchaseVerificationError(
            "APPLE_TRANSACTION_INVALID",
            f"The verified Apple transaction has an invalid {field_name}.",
        ) from error


def _required_string(value, field_name):
    normalized = (_string_value(value) or "").strip()
    if not normalized:
        raise ApplePurchaseVerificationError(
            "APPLE_TRANSACTION_INVALID",
            f"The verified Apple transaction is missing {field_name}.",
        )
    return normalized


def _allowed_environments():
    configured = os.getenv("APPLE_ALLOWED_ENVIRONMENTS") or "Sandbox"
    allowed = {item.strip() for item in configured.split(",") if item.strip()}
    if not allowed or not allowed.issubset(SUPPORTED_ENVIRONMENTS):
        raise ApplePurchaseVerificationError(
            "APPLE_VERIFICATION_CONFIGURATION_ERROR",
            "APPLE_ALLOWED_ENVIRONMENTS must contain Sandbox, Production, or both.",
            status_code=503,
        )
    return allowed


def _configured_bundle_id():
    bundle_id = (os.getenv("APPLE_BUNDLE_ID") or "").strip()
    if not bundle_id:
        raise ApplePurchaseVerificationError(
            "APPLE_VERIFICATION_CONFIGURATION_ERROR",
            "APPLE_BUNDLE_ID is not configured.",
            status_code=503,
        )
    return bundle_id


def _configured_app_id(required=False):
    raw_value = (os.getenv("APPLE_APP_ID") or "0").strip()
    try:
        app_id = int(raw_value)
    except ValueError as error:
        raise ApplePurchaseVerificationError(
            "APPLE_VERIFICATION_CONFIGURATION_ERROR",
            "APPLE_APP_ID must be the numeric App Store Connect Apple ID.",
            status_code=503,
        ) from error
    if required and app_id <= 0:
        raise ApplePurchaseVerificationError(
            "APPLE_VERIFICATION_CONFIGURATION_ERROR",
            "APPLE_APP_ID must be configured before Production transactions are accepted.",
            status_code=503,
        )
    return app_id if app_id > 0 else None


def _certificate_paths():
    certificate_directory = Path(__file__).resolve().parent.parent / "certs"
    return tuple(sorted(certificate_directory.glob("Apple*Root*.cer")))


@lru_cache(maxsize=2)
def _official_verifier(environment_name):
    try:
        from appstoreserverlibrary.models.Environment import Environment
        from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier
    except ImportError as error:
        raise ApplePurchaseVerificationError(
            "APPLE_VERIFICATION_CONFIGURATION_ERROR",
            "Apple's App Store Server Library is not installed.",
            status_code=503,
        ) from error

    roots = [path.read_bytes() for path in _certificate_paths()]
    if not roots:
        raise ApplePurchaseVerificationError(
            "APPLE_VERIFICATION_CONFIGURATION_ERROR",
            "Apple root certificates are not packaged with the backend.",
            status_code=503,
        )

    environment = (
        Environment.PRODUCTION
        if environment_name == "Production"
        else Environment.SANDBOX
    )
    app_id = _configured_app_id(required=environment_name == "Production")
    return SignedDataVerifier(
        roots,
        True,
        environment,
        _configured_bundle_id(),
        app_id if environment_name == "Production" else None,
    )


class OfficialAppleSignedDataVerifier:
    """Verify device JWS values with Apple's maintained server library."""

    def verify(self, signed_transaction, signed_app_transaction):
        if not signed_transaction or len(signed_transaction) > APPLE_TRANSACTION_MAX_LENGTH:
            raise ApplePurchaseVerificationError(
                "APPLE_TRANSACTION_INVALID",
                "A valid signed Apple transaction is required.",
            )
        if not signed_app_transaction or len(signed_app_transaction) > APPLE_TRANSACTION_MAX_LENGTH:
            raise ApplePurchaseVerificationError(
                "APPLE_APP_TRANSACTION_INVALID",
                "A valid signed Apple app transaction is required.",
            )

        try:
            from appstoreserverlibrary.signed_data_verifier import (
                VerificationException,
                VerificationStatus,
            )
        except ImportError as error:
            raise ApplePurchaseVerificationError(
                "APPLE_VERIFICATION_CONFIGURATION_ERROR",
                "Apple's App Store Server Library is not installed.",
                status_code=503,
            ) from error

        verification_errors = []
        for environment_name in ("Sandbox", "Production"):
            if environment_name not in _allowed_environments():
                continue
            try:
                verifier = _official_verifier(environment_name)
                transaction = verifier.verify_and_decode_signed_transaction(signed_transaction)
                app_transaction = verifier.verify_and_decode_app_transaction(signed_app_transaction)
                return self._normalize(transaction, app_transaction, environment_name)
            except ApplePurchaseVerificationError:
                raise
            except VerificationException as error:
                verification_errors.append(error)
                if error.status == VerificationStatus.RETRYABLE_VERIFICATION_FAILURE:
                    raise ApplePurchaseVerificationError(
                        "APPLE_VERIFICATION_TEMPORARILY_UNAVAILABLE",
                        "Apple transaction verification is temporarily unavailable. Please retry.",
                        status_code=503,
                        retryable=True,
                    ) from error

        raise ApplePurchaseVerificationError(
            "APPLE_TRANSACTION_INVALID",
            "The transaction signature, application identity, or environment is invalid.",
        ) from (verification_errors[-1] if verification_errors else None)

    def _normalize(self, transaction, app_transaction, environment_name):
        configured_app_id = _configured_app_id(required=environment_name == "Production")
        decoded_app_id = getattr(app_transaction, "appAppleId", None)
        if environment_name == "Production" and decoded_app_id != configured_app_id:
            raise ApplePurchaseVerificationError(
                "APPLE_APP_MISMATCH",
                "The Apple app ID does not match this application.",
                status_code=403,
            )
        transaction_app_id = _required_string(
            getattr(transaction, "appTransactionId", None),
            "appTransactionId",
        )
        signed_app_transaction_id = _required_string(
            getattr(app_transaction, "appTransactionId", None),
            "appTransactionId",
        )
        if transaction_app_id != signed_app_transaction_id:
            raise ApplePurchaseVerificationError(
                "APPLE_APP_TRANSACTION_MISMATCH",
                "The transaction and app transaction belong to different App Store accounts.",
                status_code=403,
            )

        decoded_payload = {
            "transactionId": _string_value(getattr(transaction, "transactionId", None)),
            "originalTransactionId": _string_value(getattr(transaction, "originalTransactionId", None)),
            "appAccountToken": _string_value(getattr(transaction, "appAccountToken", None)),
            "productId": _string_value(getattr(transaction, "productId", None)),
            "bundleId": _string_value(getattr(transaction, "bundleId", None)),
            "environment": environment_name,
            "type": _string_value(getattr(transaction, "type", None)),
            "transactionReason": _string_value(getattr(transaction, "transactionReason", None)),
            "purchaseDate": getattr(transaction, "purchaseDate", None),
            "expiresDate": getattr(transaction, "expiresDate", None),
            "revocationDate": getattr(transaction, "revocationDate", None),
            "isUpgraded": bool(getattr(transaction, "isUpgraded", False)),
            "appTransactionId": _string_value(getattr(transaction, "appTransactionId", None)),
        }

        return VerifiedApplePurchase(
            transaction_id=_required_string(getattr(transaction, "transactionId", None), "transactionId"),
            original_transaction_id=_required_string(
                getattr(transaction, "originalTransactionId", None),
                "originalTransactionId",
            ),
            app_account_token=_required_string(
                getattr(transaction, "appAccountToken", None),
                "appAccountToken",
            ),
            product_id=_required_string(getattr(transaction, "productId", None), "productId"),
            bundle_id=_required_string(getattr(transaction, "bundleId", None), "bundleId"),
            app_apple_id=decoded_app_id,
            app_transaction_id=transaction_app_id,
            environment=environment_name,
            product_type=_required_string(getattr(transaction, "type", None), "type"),
            transaction_reason=_string_value(getattr(transaction, "transactionReason", None)),
            purchased_at=_milliseconds_to_datetime(
                getattr(transaction, "purchaseDate", None),
                "purchaseDate",
                required=True,
            ),
            expires_at=_milliseconds_to_datetime(
                getattr(transaction, "expiresDate", None),
                "expiresDate",
                required=True,
            ),
            revoked_at=_milliseconds_to_datetime(
                getattr(transaction, "revocationDate", None),
                "revocationDate",
            ),
            is_upgraded=bool(getattr(transaction, "isUpgraded", False)),
            decoded_payload=decoded_payload,
        )


def _validate_purchase(purchase, account, now):
    configured_products = set(_configured_product_ids().values())
    if purchase.product_id not in configured_products:
        raise ApplePurchaseVerificationError(
            "APPLE_PRODUCT_NOT_ALLOWED",
            "The verified transaction is not for a supported Personal Plus product.",
            status_code=403,
        )
    if purchase.product_type != "Auto-Renewable Subscription":
        raise ApplePurchaseVerificationError(
            "APPLE_PRODUCT_TYPE_INVALID",
            "The verified product is not an auto-renewable subscription.",
            status_code=403,
        )
    if purchase.bundle_id != _configured_bundle_id():
        raise ApplePurchaseVerificationError(
            "APPLE_APP_MISMATCH",
            "The transaction bundle ID does not match this application.",
            status_code=403,
        )
    if purchase.environment not in _allowed_environments():
        raise ApplePurchaseVerificationError(
            "APPLE_ENVIRONMENT_NOT_ALLOWED",
            "This Apple transaction environment is not enabled.",
            status_code=403,
        )

    try:
        transaction_token = UUID(purchase.app_account_token)
        account_token = UUID(str(account["app_account_token"]))
    except (TypeError, ValueError, AttributeError) as error:
        raise ApplePurchaseVerificationError(
            "APPLE_ACCOUNT_MISMATCH",
            "The transaction account token is invalid.",
            status_code=403,
        ) from error
    if transaction_token != account_token:
        raise ApplePurchaseVerificationError(
            "APPLE_ACCOUNT_MISMATCH",
            "The transaction belongs to a different Hit n Score account.",
            status_code=403,
        )
    if purchase.revoked_at is not None:
        raise ApplePurchaseVerificationError(
            "APPLE_TRANSACTION_REVOKED",
            "Apple has refunded or revoked this transaction.",
            status_code=422,
        )
    if purchase.is_upgraded:
        raise ApplePurchaseVerificationError(
            "APPLE_TRANSACTION_SUPERSEDED",
            "This transaction has been superseded by another subscription product.",
            status_code=422,
        )
    if purchase.expires_at <= now:
        raise ApplePurchaseVerificationError(
            "APPLE_SUBSCRIPTION_EXPIRED",
            "This Apple subscription period has expired.",
            status_code=422,
        )


def verify_and_apply_purchase(
    connection,
    organization_id,
    username,
    signed_transaction,
    signed_app_transaction,
    *,
    verifier=None,
    now=None,
    request_id=None,
):
    if not _purchases_enabled():
        raise ApplePurchaseVerificationError(
            "APPLE_PURCHASES_DISABLED",
            "Apple purchases are not enabled for this deployment.",
            status_code=503,
        )

    normalized_username = _normalize_username(username)
    verified = (verifier or OfficialAppleSignedDataVerifier()).verify(
        signed_transaction,
        signed_app_transaction,
    )
    effective_now = now or datetime.now(timezone.utc)

    with connection.cursor() as cursor:
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
            raise ApplePurchaseVerificationError(
                "APPLE_PURCHASE_NOT_ALLOWED",
                "Apple Personal Plus purchases require a personal account.",
                status_code=403,
            )
        if _normalize_username(account.get("owner_username")) != normalized_username:
            raise ApplePurchaseVerificationError(
                "APPLE_PURCHASE_NOT_ALLOWED",
                "Only the personal account owner can verify a purchase.",
                status_code=403,
            )

        _validate_purchase(verified, account, effective_now)
        signed_hash = hashlib.sha256(signed_transaction.encode("utf-8")).hexdigest()

        cursor.execute(
            """
            SELECT transaction_id, original_transaction_id, organization_id,
                   app_account_token, product_id, environment, expires_at
            FROM app_store_transactions
            WHERE transaction_id = %(transaction_id)s
            FOR UPDATE
            """,
            {"transaction_id": verified.transaction_id},
        )
        existing_transaction = cursor.fetchone()
        if existing_transaction and (
            int(existing_transaction["organization_id"]) != int(organization_id)
            or UUID(str(existing_transaction["app_account_token"]))
            != UUID(verified.app_account_token)
            or existing_transaction["original_transaction_id"]
            != verified.original_transaction_id
            or existing_transaction["product_id"] != verified.product_id
            or existing_transaction["environment"] != verified.environment
            or existing_transaction["expires_at"] != verified.expires_at
        ):
            raise ApplePurchaseVerificationError(
                "APPLE_TRANSACTION_REPLAY_MISMATCH",
                "This Apple transaction has already been recorded for different data.",
                status_code=409,
            )

        cursor.execute(
            """
            SELECT organization_id, app_account_token
            FROM app_store_subscriptions
            WHERE original_transaction_id = %(original_transaction_id)s
            FOR UPDATE
            """,
            {"original_transaction_id": verified.original_transaction_id},
        )
        existing_subscription = cursor.fetchone()
        if existing_subscription and (
            int(existing_subscription["organization_id"]) != int(organization_id)
            or UUID(str(existing_subscription["app_account_token"]))
            != UUID(verified.app_account_token)
        ):
            raise ApplePurchaseVerificationError(
                "APPLE_SUBSCRIPTION_OWNERSHIP_MISMATCH",
                "This Apple subscription is already linked to another account.",
                status_code=409,
            )

        if not existing_transaction:
            cursor.execute(
                """
                INSERT INTO app_store_transactions (
                    transaction_id, original_transaction_id, organization_id,
                    account_username, app_account_token, product_id, bundle_id,
                    app_apple_id, app_transaction_id, environment, product_type,
                    transaction_reason, purchased_at,
                    expires_at, revoked_at, signed_transaction_sha256,
                    signed_transaction, decoded_payload, verified_at
                ) VALUES (
                    %(transaction_id)s, %(original_transaction_id)s,
                    %(organization_id)s, %(account_username)s,
                    %(app_account_token)s, %(product_id)s, %(bundle_id)s,
                    %(app_apple_id)s, %(app_transaction_id)s, %(environment)s,
                    %(product_type)s, %(transaction_reason)s,
                    %(purchased_at)s, %(expires_at)s, %(revoked_at)s,
                    %(signed_transaction_sha256)s, %(signed_transaction)s,
                    %(decoded_payload)s::jsonb, %(verified_at)s
                )
                """,
                {
                    "transaction_id": verified.transaction_id,
                    "original_transaction_id": verified.original_transaction_id,
                    "organization_id": int(organization_id),
                    "account_username": normalized_username,
                    "app_account_token": verified.app_account_token,
                    "product_id": verified.product_id,
                    "bundle_id": verified.bundle_id,
                    "app_apple_id": verified.app_apple_id,
                    "app_transaction_id": verified.app_transaction_id,
                    "environment": verified.environment,
                    "product_type": verified.product_type,
                    "transaction_reason": verified.transaction_reason,
                    "purchased_at": verified.purchased_at,
                    "expires_at": verified.expires_at,
                    "revoked_at": verified.revoked_at,
                    "signed_transaction_sha256": signed_hash,
                    "signed_transaction": signed_transaction,
                    "decoded_payload": json.dumps(verified.decoded_payload),
                    "verified_at": effective_now,
                },
            )

        cursor.execute(
            """
            INSERT INTO app_store_subscriptions (
                organization_id, username, app_account_token,
                original_transaction_id, latest_transaction_id, product_id,
                bundle_id, app_apple_id, app_transaction_id, environment,
                status, purchased_at,
                expires_at, revoked_at, last_signed_transaction_sha256,
                last_verified_at, updated_at
            ) VALUES (
                %(organization_id)s, %(username)s, %(app_account_token)s,
                %(original_transaction_id)s, %(latest_transaction_id)s,
                %(product_id)s, %(bundle_id)s, %(app_apple_id)s,
                %(app_transaction_id)s, %(environment)s, 'active',
                %(purchased_at)s, %(expires_at)s,
                NULL, %(signed_transaction_sha256)s, %(verified_at)s,
                %(verified_at)s
            )
            ON CONFLICT (app_account_token) DO UPDATE SET
                original_transaction_id = EXCLUDED.original_transaction_id,
                latest_transaction_id = EXCLUDED.latest_transaction_id,
                product_id = EXCLUDED.product_id,
                bundle_id = EXCLUDED.bundle_id,
                app_apple_id = EXCLUDED.app_apple_id,
                app_transaction_id = EXCLUDED.app_transaction_id,
                environment = EXCLUDED.environment,
                status = 'active',
                purchased_at = EXCLUDED.purchased_at,
                expires_at = EXCLUDED.expires_at,
                revoked_at = NULL,
                last_signed_transaction_sha256 = EXCLUDED.last_signed_transaction_sha256,
                last_verified_at = EXCLUDED.last_verified_at,
                reconciliation_error = NULL,
                updated_at = EXCLUDED.updated_at
            WHERE app_store_subscriptions.expires_at IS NULL
               OR EXCLUDED.expires_at >= app_store_subscriptions.expires_at
            RETURNING original_transaction_id, latest_transaction_id,
                      product_id, environment, status, expires_at
            """,
            {
                "organization_id": int(organization_id),
                "username": normalized_username,
                "app_account_token": verified.app_account_token,
                "original_transaction_id": verified.original_transaction_id,
                "latest_transaction_id": verified.transaction_id,
                "product_id": verified.product_id,
                "bundle_id": verified.bundle_id,
                "app_apple_id": verified.app_apple_id,
                "app_transaction_id": verified.app_transaction_id,
                "environment": verified.environment,
                "purchased_at": verified.purchased_at,
                "expires_at": verified.expires_at,
                "signed_transaction_sha256": signed_hash,
                "verified_at": effective_now,
            },
        )
        subscription = cursor.fetchone()
        if subscription is None:
            cursor.execute(
                """
                SELECT original_transaction_id, latest_transaction_id,
                       product_id, environment, status, expires_at
                FROM app_store_subscriptions
                WHERE original_transaction_id = %(original_transaction_id)s
                """,
                {"original_transaction_id": verified.original_transaction_id},
            )
            subscription = cursor.fetchone()

        previous_plan = account.get("plan")
        if previous_plan not in {"personal_free", "personal_plus"}:
            previous_plan = "personal_free"
        if previous_plan != "personal_plus":
            cursor.execute(
                """
                UPDATE "SkwshOrgSettings"
                SET plan = 'personal_plus'
                WHERE id = %(organization_id)s
                """,
                {"organization_id": int(organization_id)},
            )
            cursor.execute(
                """
                INSERT INTO subscription_entitlement_audit (
                    organization_id, account_username, previous_plan, new_plan,
                    source, reason, effective_at, app_account_token,
                    original_transaction_id, transaction_id, actor_type,
                    actor_identifier, request_id, metadata
                ) VALUES (
                    %(organization_id)s, %(account_username)s,
                    %(previous_plan)s, 'personal_plus', 'purchase',
                    'verified_active_apple_subscription', %(effective_at)s,
                    %(app_account_token)s, %(original_transaction_id)s,
                    %(transaction_id)s, 'user', %(actor_identifier)s,
                    %(request_id)s, %(metadata)s::jsonb
                )
                """,
                {
                    "organization_id": int(organization_id),
                    "account_username": normalized_username,
                    "previous_plan": previous_plan,
                    "effective_at": effective_now,
                    "app_account_token": verified.app_account_token,
                    "original_transaction_id": verified.original_transaction_id,
                    "transaction_id": verified.transaction_id,
                    "actor_identifier": normalized_username,
                    "request_id": request_id,
                    "metadata": json.dumps(
                        {
                            "product_id": verified.product_id,
                            "environment": verified.environment,
                            "expires_at": verified.expires_at.isoformat(),
                        }
                    ),
                },
            )

    connection.commit()
    return {
        "organization_id": int(organization_id),
        "current_plan": "personal_plus",
        "transaction_id": verified.transaction_id,
        "original_transaction_id": verified.original_transaction_id,
        "product_id": subscription["product_id"],
        "environment": subscription["environment"],
        "status": subscription["status"],
        "expires_at": subscription["expires_at"].isoformat(),
        "idempotent": existing_transaction is not None,
    }
