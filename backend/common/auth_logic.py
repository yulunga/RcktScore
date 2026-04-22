from werkzeug.security import check_password_hash

from common.organization_logic import USER_STATUS_APPROVED, normalize_email_address


def _serialize_org_user(user_row):
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

    return {
        "id": user_row["id"],
        "username": user_row["clubusername"],
        "role": user_row.get("role") or "user",
        "organization_id": user_row["organization_id"],
        "organization_name": user_row.get("organization_name"),
        "organization_type": user_row.get("org_type") or "club",
        "plan": user_row.get("plan") or "club_essentials",
        "status": user_row.get("approval_status") or USER_STATUS_APPROVED,
        "first_name": first_name,
        "surname": surname,
        "full_name": full_name,
        "email": email,
    }


def _serialize_root_admin(user_row):
    return {
        "id": user_row["id"],
        "username": user_row["rtusername"],
        "role": "root_admin",
    }


def get_org_users(connection, username):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                u.id,
                u.clubusername,
                u.password_hash,
                u.organization_id,
                u.role,
                u.approval_status,
                o.org_type,
                o.plan,
                o.organization_name,
                to_jsonb(u) AS user_json
            FROM "SkwshOrgUsers" AS u
            LEFT JOIN "SkwshOrgSettings" AS o
                ON o.id = u.organization_id
            WHERE LOWER(u.clubusername) = LOWER(%(username)s)
            ORDER BY o.organization_name ASC, u.organization_id ASC, u.id ASC
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
            """,
            {"username": username},
        )
        return cursor.fetchone()


def authenticate_org_user_memberships(connection, username, password):
    user_rows = get_org_users(connection, username)
    if not user_rows:
        return {
            "approved_memberships": [],
            "pending_memberships": [],
        }

    approved_memberships = []
    pending_memberships = []
    for user_row in user_rows:
        if not user_row.get("password_hash"):
            continue

        if check_password_hash(user_row["password_hash"], password):
            serialized_user = _serialize_org_user(user_row)
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
