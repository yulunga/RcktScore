from werkzeug.security import check_password_hash


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
        or ""
    )
    full_name = " ".join(part for part in [first_name, surname] if part).strip()

    return {
        "id": user_row["id"],
        "username": user_row["clubusername"],
        "role": user_row.get("role") or "user",
        "organization_id": user_row["organization_id"],
        "organization_name": user_row.get("organization_name"),
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


def get_org_user(connection, username):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                u.id,
                u.clubusername,
                u.password_hash,
                u.organization_id,
                u.role,
                o.organization_name,
                to_jsonb(u) AS user_json
            FROM "SkwshOrgUsers" AS u
            LEFT JOIN "SkwshOrgSettings" AS o
                ON o.id = u.organization_id
            WHERE u.clubusername = %(username)s
            LIMIT 1
            """,
            {"username": username},
        )
        return cursor.fetchone()


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


def authenticate_org_user(connection, username, password):
    user_row = get_org_user(connection, username)
    if not user_row:
        return None

    if not user_row.get("password_hash"):
        return None

    if not check_password_hash(user_row["password_hash"], password):
        return None

    return _serialize_org_user(user_row)


def authenticate_root_admin(connection, username, password):
    user_row = get_root_admin(connection, username)
    if not user_row:
        return None

    if not user_row.get("password_hash"):
        return None

    if not check_password_hash(user_row["password_hash"], password):
        return None

    return _serialize_root_admin(user_row)
