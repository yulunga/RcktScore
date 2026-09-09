import os
from uuid import uuid4

DEFAULT_MONTHLY_PRODUCT_ID = "com.hitnscore.personalplus.monthly"
DEFAULT_YEARLY_PRODUCT_ID = "com.hitnscore.personalplus.yearly"
PERSONAL_PLANS = {"personal_free", "personal_plus"}


class AppleSubscriptionError(Exception):
    pass


def _normalize_username(value):
    return (value or "").strip().lower()


def _configured_product_ids():
    return {
        "monthly": (
            os.getenv("APPLE_PERSONAL_PLUS_MONTHLY_PRODUCT_ID")
            or DEFAULT_MONTHLY_PRODUCT_ID
        ).strip(),
        "yearly": (
            os.getenv("APPLE_PERSONAL_PLUS_YEARLY_PRODUCT_ID")
            or DEFAULT_YEARLY_PRODUCT_ID
        ).strip(),
    }


def _purchases_enabled():
    return (os.getenv("APPLE_PURCHASES_ENABLED") or "false").strip().lower() in {
        "1",
        "true",
        "yes",
        "on",
    }


def get_or_create_purchase_context(connection, organization_id, username):
    """Return the permanent StoreKit account identity for a personal account.

    The row lock makes first-time token creation safe if two devices request the
    context simultaneously. The UUID correlates transactions; it is not a login
    credential and cannot replace normal session authorization.
    """

    normalized_username = _normalize_username(username)
    if not normalized_username:
        raise AppleSubscriptionError("A signed-in account is required")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                id,
                org_type,
                plan,
                owner_username,
                app_account_token
            FROM "SkwshOrgSettings"
            WHERE id = %(organization_id)s
            FOR UPDATE
            """,
            {"organization_id": int(organization_id)},
        )
        account = cursor.fetchone()

        if not account:
            raise AppleSubscriptionError("Personal account not found")
        if account.get("org_type") != "personal":
            raise AppleSubscriptionError("Apple Personal Plus purchases require a personal account")
        if _normalize_username(account.get("owner_username")) != normalized_username:
            raise AppleSubscriptionError("Only the personal account owner can start a purchase")

        token = account.get("app_account_token")
        if token is None:
            token = uuid4()
            cursor.execute(
                """
                UPDATE "SkwshOrgSettings"
                SET app_account_token = %(app_account_token)s
                WHERE id = %(organization_id)s
                  AND app_account_token IS NULL
                RETURNING app_account_token
                """,
                {
                    "organization_id": int(organization_id),
                    "app_account_token": token,
                },
            )
            updated = cursor.fetchone()
            if updated:
                token = updated["app_account_token"]

    connection.commit()
    plan = account.get("plan")
    if plan not in PERSONAL_PLANS:
        plan = "personal_free"

    return {
        "organization_id": int(account["id"]),
        "app_account_token": str(token),
        "current_plan": plan,
        "purchases_enabled": _purchases_enabled(),
        "product_ids": _configured_product_ids(),
    }
