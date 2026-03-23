from common.organization_logic import (
    ORGANIZATION_FIELDS,
    _serialize_organization,
    _utcnow,
    create_organization_user,
    update_organization_user_role,
)


def _serialize_root_admin_user(row):
    created_at = row.get("created_at")
    return {
        "id": row["id"],
        "username": row.get("clubusername") or "",
        "role": row.get("role") or "user",
        "organization_id": row["organization_id"],
        "organization_name": row.get("organization_name") or "",
        "created_at": created_at.isoformat() if created_at else None,
    }


def get_root_admin_dashboard(connection):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                o.id,
                o.organization_name,
                o.org_address,
                o.org_contact,
                o.org_telephone,
                o.org_email,
                o.org_webaddress,
                COUNT(DISTINCT u.id) AS user_count,
                COUNT(DISTINCT c.id) AS court_count,
                COUNT(DISTINCT CASE WHEN u.role = 'admin' THEN u.id END) AS admin_count
            FROM "SkwshOrgSettings" AS o
            LEFT JOIN "SkwshOrgUsers" AS u
                ON u.organization_id = o.id
            LEFT JOIN "SkwshCourts" AS c
                ON c.organization_name = o.id
            GROUP BY
                o.id,
                o.organization_name,
                o.org_address,
                o.org_contact,
                o.org_telephone,
                o.org_email,
                o.org_webaddress
            ORDER BY o.organization_name ASC, o.id ASC
            """
        )
        organization_rows = cursor.fetchall()

        cursor.execute(
            """
            SELECT
                u.id,
                u.clubusername,
                u.role,
                u.organization_id,
                u.created_at,
                o.organization_name
            FROM "SkwshOrgUsers" AS u
            LEFT JOIN "SkwshOrgSettings" AS o
                ON o.id = u.organization_id
            ORDER BY o.organization_name ASC, u.clubusername ASC, u.id ASC
            """
        )
        user_rows = cursor.fetchall()

    organizations = []
    organizations_by_id = {}
    for row in organization_rows:
        serialized = _serialize_organization(row)
        serialized["user_count"] = row.get("user_count") or 0
        serialized["court_count"] = row.get("court_count") or 0
        serialized["admin_count"] = row.get("admin_count") or 0
        serialized["users"] = []
        organizations.append(serialized)
        organizations_by_id[serialized["id"]] = serialized

    users = []
    for row in user_rows:
        serialized_user = _serialize_root_admin_user(row)
        users.append(serialized_user)
        organization = organizations_by_id.get(serialized_user["organization_id"])
        if organization:
            organization["users"].append(serialized_user)

    total_admins = sum(1 for user in users if user["role"] == "admin")

    return {
        "summary": {
            "organization_count": len(organizations),
            "user_count": len(users),
            "admin_count": total_admins,
        },
        "organizations": organizations,
    }


def search_root_admin_organizations(connection, query):
    search_text = (query or "").strip()
    if not search_text:
        return []

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id, organization_name, org_email, org_contact
            FROM "SkwshOrgSettings"
            WHERE organization_name ILIKE %(query)s
            ORDER BY organization_name ASC, id ASC
            LIMIT 10
            """,
            {"query": f"%{search_text}%"},
        )
        rows = cursor.fetchall()

    return [
        {
            "id": row["id"],
            "organization_name": row.get("organization_name") or "",
            "org_email": row.get("org_email") or "",
            "org_contact": row.get("org_contact") or "",
        }
        for row in rows
    ]


def create_root_admin_organization(connection, payload):
    updates = {
        field: payload[field].strip() if isinstance(payload.get(field), str) else payload.get(field)
        for field in ORGANIZATION_FIELDS
        if field in payload
    }

    if not (updates.get("organization_name") or "").strip():
        raise ValueError("organization_name is required")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO "SkwshOrgSettings" (
                created_at,
                organization_name,
                org_address,
                org_contact,
                org_telephone,
                org_email,
                org_webaddress
            )
            VALUES (
                %(created_at)s,
                %(organization_name)s,
                %(org_address)s,
                %(org_contact)s,
                %(org_telephone)s,
                %(org_email)s,
                %(org_webaddress)s
            )
            RETURNING
                id,
                organization_name,
                org_address,
                org_contact,
                org_telephone,
                org_email,
                org_webaddress
            """,
            {
                "created_at": _utcnow(),
                "organization_name": updates.get("organization_name", "").strip(),
                "org_address": updates.get("org_address") or None,
                "org_contact": updates.get("org_contact") or None,
                "org_telephone": updates.get("org_telephone") or None,
                "org_email": updates.get("org_email") or None,
                "org_webaddress": updates.get("org_webaddress") or None,
            },
        )
        organization_row = cursor.fetchone()

    connection.commit()
    return _serialize_organization(organization_row)


def create_root_admin_org_user(connection, organization_id, username, password, role):
    return create_organization_user(connection, organization_id, username, password, role)


def update_root_admin_org_user_role(connection, organization_id, user_id, role):
    return update_organization_user_role(connection, organization_id, user_id, role)
