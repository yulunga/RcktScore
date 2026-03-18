from datetime import datetime, timezone

from werkzeug.security import generate_password_hash


VALID_ROLES = {"admin", "user"}
ORGANIZATION_FIELDS = [
    "organization_name",
    "org_address",
    "org_contact",
    "org_telephone",
    "org_email",
    "org_webaddress",
]


def _utcnow():
    return datetime.now(timezone.utc)


def _serialize_organization(row):
    return {
        "id": row["id"],
        "organization_name": row.get("organization_name") or "",
        "org_address": row.get("org_address") or "",
        "org_contact": row.get("org_contact") or "",
        "org_telephone": row.get("org_telephone") or "",
        "org_email": row.get("org_email") or "",
        "org_webaddress": row.get("org_webaddress") or "",
        "social_profiles": {
            "facebook": "",
            "instagram": "",
            "x": "",
            "youtube": "",
        },
    }


def _serialize_user(row):
    created_at = row.get("created_at")
    return {
        "id": row["id"],
        "username": row["clubusername"],
        "role": row.get("role") or "user",
        "created_at": created_at.isoformat() if created_at else None,
    }


def _serialize_court(row):
    created_at = row.get("created_at")
    return {
        "id": row["id"],
        "court_name": row.get("court_name") or "",
        "court_alias": row.get("court_alias") or "",
        "created_at": created_at.isoformat() if created_at else None,
    }


def get_organization_settings(connection, organization_id):
    org_id = int(organization_id)

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id, organization_name, org_address, org_contact, org_telephone, org_email, org_webaddress
            FROM "SkwshOrgSettings"
            WHERE id = %(organization_id)s
            LIMIT 1
            """,
            {"organization_id": org_id},
        )
        organization_row = cursor.fetchone()

        if not organization_row:
            return None

        cursor.execute(
            """
            SELECT id, clubusername, role, created_at
            FROM "SkwshOrgUsers"
            WHERE organization_id = %(organization_id)s
            ORDER BY clubusername ASC
            """,
            {"organization_id": org_id},
        )
        user_rows = cursor.fetchall()

        cursor.execute(
            """
            SELECT id, court_name, court_alias, created_at
            FROM "SkwshCourts"
            WHERE organization_name = %(organization_id)s
            ORDER BY court_name ASC, id ASC
            """,
            {"organization_id": org_id},
        )
        court_rows = cursor.fetchall()

    return {
        "organization": _serialize_organization(organization_row),
        "users": [_serialize_user(row) for row in user_rows],
        "courts": [_serialize_court(row) for row in court_rows],
    }


def update_organization_details(connection, organization_id, payload):
    org_id = int(organization_id)
    updates = {
        field: payload[field].strip() if isinstance(payload.get(field), str) else payload.get(field)
        for field in ORGANIZATION_FIELDS
        if field in payload
    }

    if updates:
        set_clause = ", ".join(f'{field} = %({field})s' for field in updates)
        params = {**updates, "organization_id": org_id}
        with connection.cursor() as cursor:
            cursor.execute(
                f'''
                UPDATE "SkwshOrgSettings"
                SET {set_clause}
                WHERE id = %(organization_id)s
                ''' ,
                params,
            )
        connection.commit()

    return get_organization_settings(connection, org_id)


def create_organization_user(connection, organization_id, username, password, role):
    org_id = int(organization_id)
    normalized_role = (role or "user").strip().lower()
    if normalized_role not in VALID_ROLES:
        raise ValueError("role must be admin or user")

    trimmed_username = username.strip()
    if not trimmed_username:
        raise ValueError("username is required")
    if not password:
        raise ValueError("password is required")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id
            FROM "SkwshOrgUsers"
            WHERE clubusername = %(username)s
            LIMIT 1
            """,
            {"username": trimmed_username},
        )
        existing_user = cursor.fetchone()
        if existing_user:
            raise ValueError("Username already exists")

        cursor.execute(
            """
            INSERT INTO "SkwshOrgUsers" (created_at, clubusername, password_hash, organization_id, role)
            VALUES (%(created_at)s, %(username)s, %(password_hash)s, %(organization_id)s, %(role)s)
            RETURNING id, clubusername, role, created_at
            """,
            {
                "created_at": _utcnow(),
                "username": trimmed_username,
                "password_hash": generate_password_hash(password),
                "organization_id": org_id,
                "role": normalized_role,
            },
        )
        user_row = cursor.fetchone()

    connection.commit()
    return _serialize_user(user_row)


def update_organization_user_role(connection, organization_id, user_id, role):
    org_id = int(organization_id)
    normalized_role = (role or "user").strip().lower()
    if normalized_role not in VALID_ROLES:
        raise ValueError("role must be admin or user")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE "SkwshOrgUsers"
            SET role = %(role)s
            WHERE id = %(user_id)s
              AND organization_id = %(organization_id)s
            RETURNING id, clubusername, role, created_at
            """,
            {
                "role": normalized_role,
                "user_id": int(user_id),
                "organization_id": org_id,
            },
        )
        user_row = cursor.fetchone()

    connection.commit()
    return _serialize_user(user_row) if user_row else None


def create_court(connection, organization_id, court_name, court_alias=None):
    org_id = int(organization_id)
    trimmed_name = court_name.strip()
    if not trimmed_name:
        raise ValueError("court_name is required")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO "SkwshCourts" (created_at, court_name, court_alias, organization_name)
            VALUES (%(created_at)s, %(court_name)s, %(court_alias)s, %(organization_id)s)
            RETURNING id, court_name, court_alias, created_at
            """,
            {
                "created_at": _utcnow(),
                "court_name": trimmed_name,
                "court_alias": (court_alias or "").strip() or None,
                "organization_id": org_id,
            },
        )
        court_row = cursor.fetchone()

    connection.commit()
    return _serialize_court(court_row)


def update_court(connection, organization_id, court_id, court_name, court_alias=None):
    org_id = int(organization_id)
    trimmed_name = court_name.strip()
    if not trimmed_name:
        raise ValueError("court_name is required")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE "SkwshCourts"
            SET court_name = %(court_name)s,
                court_alias = %(court_alias)s
            WHERE id = %(court_id)s
              AND organization_name = %(organization_id)s
            RETURNING id, court_name, court_alias, created_at
            """,
            {
                "court_id": int(court_id),
                "organization_id": org_id,
                "court_name": trimmed_name,
                "court_alias": (court_alias or "").strip() or None,
            },
        )
        court_row = cursor.fetchone()

    connection.commit()
    return _serialize_court(court_row) if court_row else None


def delete_court(connection, organization_id, court_id):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            DELETE FROM "SkwshCourts"
            WHERE id = %(court_id)s
              AND organization_name = %(organization_id)s
            RETURNING id
            """,
            {
                "court_id": int(court_id),
                "organization_id": int(organization_id),
            },
        )
        deleted_row = cursor.fetchone()

    connection.commit()
    return bool(deleted_row)
