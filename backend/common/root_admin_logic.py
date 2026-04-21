from psycopg.errors import UndefinedTable

from common.organization_logic import (
    ORGANIZATION_FIELDS,
    _serialize_organization,
    _utcnow,
    create_organization_user,
    update_organization_user_role,
)


INTEREST_STATUSES = {"pending", "approved", "denied"}


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
                o.org_postcode,
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
                o.org_postcode,
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

        interest_count = 0
        pending_interest_count = 0
        try:
            cursor.execute(
                """
                SELECT
                    COUNT(*) AS interest_count,
                    COUNT(*) FILTER (WHERE approval_status = 'pending') AS pending_interest_count
                FROM "HitnScoreInterestRequests"
                """
            )
            interest_summary = cursor.fetchone() or {}
            interest_count = interest_summary.get("interest_count") or 0
            pending_interest_count = interest_summary.get("pending_interest_count") or 0
        except UndefinedTable:
            connection.rollback()

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
            "interest_count": interest_count,
            "pending_interest_count": pending_interest_count,
        },
        "organizations": organizations,
    }


def _serialize_interest_request(row):
    created_at = row.get("created_at")
    updated_at = row.get("updated_at")
    email_validated_at = row.get("email_validated_at")
    approved_at = row.get("approved_at")
    first_name = row.get("first_name") or ""
    surname = row.get("surname") or ""

    return {
        "id": row["id"],
        "first_name": first_name,
        "surname": surname,
        "full_name": f"{first_name} {surname}".strip(),
        "email": row.get("email") or "",
        "use_type": row.get("use_type") or "personal",
        "club_name": row.get("club_name") or "",
        "approval_status": row.get("approval_status") or "pending",
        "email_validated": bool(row.get("email_validated")),
        "email_validated_at": email_validated_at.isoformat() if email_validated_at else None,
        "approved_at": approved_at.isoformat() if approved_at else None,
        "approved_by": row.get("approved_by") or "",
        "page_url": row.get("page_url") or "",
        "user_agent": row.get("user_agent") or "",
        "created_at": created_at.isoformat() if created_at else None,
        "updated_at": updated_at.isoformat() if updated_at else None,
    }


def get_root_admin_interest_requests(connection, status=None):
    requested_status = (status or "").strip().lower()
    params = {}
    where_clause = ""
    if requested_status in INTEREST_STATUSES:
        where_clause = "WHERE approval_status = %(status)s"
        params["status"] = requested_status

    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            SELECT
                id,
                created_at,
                updated_at,
                first_name,
                surname,
                email,
                use_type,
                club_name,
                approval_status,
                email_validated,
                email_validated_at,
                approved_at,
                approved_by,
                page_url,
                user_agent
            FROM "HitnScoreInterestRequests"
            {where_clause}
            ORDER BY
                CASE approval_status
                    WHEN 'pending' THEN 1
                    WHEN 'approved' THEN 2
                    WHEN 'denied' THEN 3
                    ELSE 4
                END,
                created_at DESC,
                id DESC
            """,
            params,
        )
        rows = cursor.fetchall()

    return [_serialize_interest_request(row) for row in rows]


def update_root_admin_interest_request_status(connection, request_id, status, updated_by=None):
    requested_status = (status or "").strip().lower()
    if requested_status not in INTEREST_STATUSES:
        raise ValueError("approval_status must be pending, approved, or denied")

    now = _utcnow()
    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE "HitnScoreInterestRequests"
            SET updated_at = %(updated_at)s,
                approval_status = %(approval_status)s,
                approved_at = CASE
                    WHEN %(approval_status)s = 'approved' THEN %(updated_at)s
                    ELSE NULL
                END,
                approved_by = %(updated_by)s
            WHERE id = %(id)s
            RETURNING
                id,
                created_at,
                updated_at,
                first_name,
                surname,
                email,
                use_type,
                club_name,
                approval_status,
                email_validated,
                email_validated_at,
                approved_at,
                approved_by,
                page_url,
                user_agent
            """,
            {
                "id": request_id,
                "updated_at": now,
                "approval_status": requested_status,
                "updated_by": (updated_by or "").strip() or None,
            },
        )
        row = cursor.fetchone()

    if not row:
        raise LookupError("Interest request not found")

    connection.commit()
    return _serialize_interest_request(row)


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
                org_postcode,
                org_contact,
                org_telephone,
                org_email,
                org_webaddress
            )
            VALUES (
                %(created_at)s,
                %(organization_name)s,
                %(org_address)s,
                %(org_postcode)s,
                %(org_contact)s,
                %(org_telephone)s,
                %(org_email)s,
                %(org_webaddress)s
            )
            RETURNING
                id,
                organization_name,
                org_address,
                org_postcode,
                org_contact,
                org_telephone,
                org_email,
                org_webaddress
            """,
            {
                "created_at": _utcnow(),
                "organization_name": updates.get("organization_name", "").strip(),
                "org_address": updates.get("org_address") or None,
                "org_postcode": updates.get("org_postcode") or None,
                "org_contact": updates.get("org_contact") or None,
                "org_telephone": updates.get("org_telephone") or None,
                "org_email": updates.get("org_email") or None,
                "org_webaddress": updates.get("org_webaddress") or None,
            },
        )
        organization_row = cursor.fetchone()

    connection.commit()
    return _serialize_organization(organization_row)


def create_root_admin_org_user(
    connection,
    organization_id,
    username,
    password,
    role,
    *,
    invitation_source_email=None,
    approval_base_url=None,
):
    return create_organization_user(
        connection,
        organization_id,
        username,
        password,
        role,
        allow_existing_password_reuse=True,
        invitation_source_email=invitation_source_email,
        approval_base_url=approval_base_url,
    )


def update_root_admin_org_user_role(connection, organization_id, user_id, role):
    return update_organization_user_role(connection, organization_id, user_id, role)
