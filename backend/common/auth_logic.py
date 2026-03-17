from werkzeug.security import check_password_hash


def _serialize_org_user(user_row):
    return {
        "id": user_row["id"],
        "username": user_row["clubusername"],
        "role": user_row.get("role") or "user",
        "organization_id": user_row["organization_id"],
        "organization_name": user_row.get("organization_name"),
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
                o.organization_name
            FROM "SkwshOrgUsers" AS u
            LEFT JOIN "SkwshOrgSettings" AS o
                ON o.id = u.organization_id
            WHERE u.clubusername = %(username)s
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
