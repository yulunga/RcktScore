from werkzeug.security import check_password_hash, generate_password_hash

from common.organization_logic import USER_STATUS_APPROVED, normalize_email_address
from common.sport_config import client_sport_field, effective_enabled_sports, normalize_enabled_sports
from common.access_control import normalize_membership_role


class IdentityPasswordResetRequired(Exception):
    """Raised when membership rows for one email no longer share one password."""


class AccountDeletionPending(Exception):
    """Raised after valid credentials are supplied for a deletion-pending identity."""


def _synchronize_identity_password_hash(connection, username, password):
    password_hash = generate_password_hash(password)
    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE "SkwshOrgUsers"
            SET password_hash = %(password_hash)s
            WHERE LOWER(clubusername) = LOWER(%(username)s)
              AND password_hash IS NOT NULL
            """,
            {
                "password_hash": password_hash,
                "username": normalize_email_address(username),
            },
        )


def _serialize_org_user(user_row, client_type="web_app"):
    user_json = user_row.get("user_json") or {}
    first_name = (
        user_json.get("first_name")
        or user_json.get("firstname")
        or user_json.get("given_name")
        or user_json.get("name")
        or ""
    )
    surname = (
        user_json.get("surname")
        or user_json.get("last_name")
        or user_json.get("lastname")
        or user_json.get("family_name")
        or ""
    )
    email = (
        user_json.get("email")
        or user_json.get("user_email")
        or user_json.get("mail")
        or user_row.get("clubusername")
        or ""
    )
    full_name = " ".join(part for part in [first_name, surname] if part).strip()
    country = user_json.get("country") or ""
    telephone = user_json.get("telephone") or ""

    client_field = client_sport_field(client_type)
    organization_sports = user_row.get("enabled_sports")
    platform_client_sports = user_row.get(f"platform_{client_field}")
    membership_client_sports = user_row.get(client_field)

    return {
        "id": user_row["id"],
        "username": user_row["clubusername"],
        "role": normalize_membership_role(user_row.get("role")),
        "organization_id": user_row["organization_id"],
        "organization_name": user_row.get("organization_name"),
        "organization_type": user_row.get("org_type") or "club",
        "plan": user_row.get("plan") or "club_essentials",
        "enabled_sports": effective_enabled_sports(
            platform_client_sports if platform_client_sports is not None else organization_sports,
            organization_sports,
            membership_client_sports,
        ),
        "enabled_sports_web": normalize_enabled_sports(user_row.get("enabled_sports_web"), default=organization_sports),
        "enabled_sports_ios": normalize_enabled_sports(user_row.get("enabled_sports_ios"), default=organization_sports),
        "status": user_row.get("approval_status") or USER_STATUS_APPROVED,
        "first_name": first_name,
        "surname": surname,
        "full_name": full_name,
        "email": email,
        "country": country,
        "telephone": telephone,
        "subscription_provider": user_row.get("subscription_provider"),
        "subscription_status": user_row.get("subscription_status"),
        "subscription_expires_at": (
            user_row["subscription_expires_at"].isoformat()
            if user_row.get("subscription_expires_at")
            else None
        ),
        "subscription_auto_renew_enabled": user_row.get("subscription_auto_renew_enabled"),
        "subscription_last_renewed_at": (
            user_row["subscription_last_renewed_at"].isoformat()
            if user_row.get("subscription_last_renewed_at")
            else None
        ),
    }


def _serialize_root_admin(user_row):
    return {
        "id": user_row["id"],
        "username": user_row["rtusername"],
        "role": "root_admin",
    }


def get_org_users(connection, username, for_update=True):
    lock_clause = "FOR UPDATE OF u" if for_update else ""
    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            SELECT
                u.id,
                u.clubusername,
                u.password_hash,
                u.organization_id,
                u.role,
                u.approval_status,
                o.org_type,
                o.plan,
                o.deletion_requested_at,
                o.deletion_purge_after,
                o.enabled_sports,
                u.enabled_sports_web,
                u.enabled_sports_ios,
                platform.enabled_sports_web AS platform_enabled_sports_web,
                platform.enabled_sports_ios AS platform_enabled_sports_ios,
                o.organization_name,
                subscription.provider AS subscription_provider,
                subscription.status AS subscription_status,
                subscription.current_period_end AS subscription_expires_at,
                subscription.auto_renew_enabled AS subscription_auto_renew_enabled,
                subscription.last_renewed_at AS subscription_last_renewed_at,
                to_jsonb(u) AS user_json
            FROM "SkwshOrgUsers" AS u
            LEFT JOIN "SkwshOrgSettings" AS o
                ON o.id = u.organization_id
            LEFT JOIN platform_settings AS platform
                ON platform.id = 'default'
            LEFT JOIN LATERAL (
                SELECT
                    source.provider,
                    source.status,
                    source.current_period_end,
                    source.auto_renew_enabled,
                    source.last_renewed_at
                FROM subscription_sources AS source
                WHERE source.organization_id = o.id
                ORDER BY
                    CASE source.status
                        WHEN 'active' THEN 0
                        WHEN 'grace_period' THEN 1
                        WHEN 'billing_retry' THEN 2
                        ELSE 3
                    END,
                    source.last_verified_at DESC,
                    source.id DESC
                LIMIT 1
            ) AS subscription ON TRUE
            WHERE LOWER(u.clubusername) = LOWER(%(username)s)
            ORDER BY o.organization_name ASC, u.organization_id ASC, u.id ASC
            {lock_clause}
            """,
            {"username": normalize_email_address(username)},
        )
        return cursor.fetchall()


def get_root_admin(connection, username):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id, rtusername, password_hash
            FROM "SkRootAdmin"
            WHERE rtusername = %(username)s
            LIMIT 1
            FOR UPDATE
            """,
            {"username": username},
        )
        return cursor.fetchone()


def authenticate_org_user_memberships(connection, username, password, client_type="web_app"):
    user_rows = get_org_users(connection, username)
    if not user_rows:
        return {
            "approved_memberships": [],
            "pending_memberships": [],
        }

    password_rows = [user_row for user_row in user_rows if user_row.get("password_hash")]
    password_matches = [
        check_password_hash(user_row["password_hash"], password)
        for user_row in password_rows
    ]
    if not password_matches or not any(password_matches):
        return {
            "approved_memberships": [],
            "pending_memberships": [],
        }
    if not all(password_matches):
        raise IdentityPasswordResetRequired()

    if any(
        (row.get("org_type") or "club") == "personal" and row.get("deletion_requested_at")
        for row in user_rows
    ):
        raise AccountDeletionPending()

    # Old membership-scoped password writes produced different hashes for the
    # same identity. Once every hash verifies the supplied password, replace
    # them with one freshly generated hash in the login transaction.
    if len({user_row["password_hash"] for user_row in password_rows}) > 1:
        _synchronize_identity_password_hash(connection, username, password)

    approved_memberships = []
    pending_memberships = []
    for user_row in user_rows:
        serialized_user = _serialize_org_user(user_row, client_type=client_type)
        if serialized_user["status"] == USER_STATUS_APPROVED:
            approved_memberships.append(serialized_user)
        else:
            pending_memberships.append(serialized_user)

    return {
        "approved_memberships": approved_memberships,
        "pending_memberships": pending_memberships,
    }


def authenticate_root_admin(connection, username, password):
    user_row = get_root_admin(connection, username)
    if not user_row:
        return None

    if not user_row.get("password_hash"):
        return None

    if not check_password_hash(user_row["password_hash"], password):
        return None

    return _serialize_root_admin(user_row)
