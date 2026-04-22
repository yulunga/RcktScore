import secrets

from common.mailer import send_email_message
from common.notification_templates import render_notification_template
from psycopg.errors import UndefinedTable

from common.organization_logic import (
    APP_DISPLAY_NAME,
    ORGANIZATION_FIELDS,
    _serialize_organization,
    _utcnow,
    create_organization_user,
    update_organization_user_role,
)
from common.password_reset_logic import RESET_TOKEN_TTL_HOURS


INTEREST_STATUSES = {"pending", "approved", "denied"}
PERSONAL_PLANS = {"personal_free", "personal_plus"}
PERSONAL_ACCOUNT_STATUS_PENDING_EMAIL = "pending_email_validation"
PERSONAL_ACCOUNT_STATUS_LIVE = "live"
PERSONAL_ORG_ID_SEQUENCE = "hitnscore_personal_org_id_seq"


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
            WHERE COALESCE(o.org_type, 'club') <> 'personal'
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
            WHERE COALESCE(o.org_type, 'club') <> 'personal'
            ORDER BY o.organization_name ASC, u.clubusername ASC, u.id ASC
            """
        )
        user_rows = cursor.fetchall()

        interest_count = 0
        pending_interest_count = 0
        personal_account_count = 0
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

        try:
            cursor.execute(
                """
                SELECT COUNT(*) AS personal_account_count
                FROM "SkwshOrgSettings"
                WHERE org_type = 'personal'
                """
            )
            personal_summary = cursor.fetchone() or {}
            personal_account_count = personal_summary.get("personal_account_count") or 0
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
            "personal_account_count": personal_account_count,
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
        "personal_plan": row.get("personal_plan") or "personal_free",
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


def _serialize_personal_account(row):
    created_at = row.get("created_at")
    updated_at = row.get("updated_at")
    email_validated_at = row.get("email_validated_at")
    approved_at = row.get("approved_at")
    approval_email_sent_at = row.get("approval_email_sent_at")
    first_name = row.get("first_name") or ""
    surname = row.get("surname") or ""

    return {
        "id": row["organization_id"],
        "organization_id": row["organization_id"],
        "user_id": row.get("user_id"),
        "interest_request_id": row.get("interest_request_id"),
        "first_name": first_name,
        "surname": surname,
        "full_name": f"{first_name} {surname}".strip(),
        "email": row.get("username") or "",
        "username": row.get("username") or "",
        "organization_name": row.get("organization_name") or "",
        "use_type": "personal",
        "personal_plan": row.get("personal_plan") or "personal_free",
        "account_status": row.get("account_status") or PERSONAL_ACCOUNT_STATUS_PENDING_EMAIL,
        "approval_status": row.get("account_status") or PERSONAL_ACCOUNT_STATUS_PENDING_EMAIL,
        "email_validated": bool(row.get("email_validated")),
        "email_validated_at": email_validated_at.isoformat() if email_validated_at else None,
        "approved_at": approved_at.isoformat() if approved_at else None,
        "approved_by": row.get("approved_by") or "",
        "approval_email_sent_at": approval_email_sent_at.isoformat() if approval_email_sent_at else None,
        "created_at": created_at.isoformat() if created_at else None,
        "updated_at": updated_at.isoformat() if updated_at else None,
    }


def _build_set_password_url(base_url, token):
    if not base_url:
        raise ValueError("PASSWORD_RESET_BASE_URL must be configured")

    return f"{base_url.rstrip('/')}/help?mode=reset&token={token}"


def _send_personal_account_approved_email(*, account, set_password_url, source_email):
    context = {
        "app_name": APP_DISPLAY_NAME,
        "expires_hours": RESET_TOKEN_TTL_HOURS,
        "first_name": account.get("first_name") or "there",
        "set_password_url": set_password_url,
        "username": account.get("username") or account.get("email") or "",
    }
    subject = render_notification_template("personal_account_approved_subject.txt", context).strip()
    body_text = render_notification_template("personal_account_approved_body.txt", context).strip()

    send_email_message(
        destination_email=account["username"],
        source_email=source_email,
        subject=subject,
        text_body=body_text,
    )


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
                personal_plan,
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


def get_root_admin_personal_accounts(connection, plan=None):
    requested_plan = (plan or "").strip().lower()
    params = {}
    plan_clause = ""
    if requested_plan in PERSONAL_PLANS:
        plan_clause = "AND COALESCE(o.plan, 'personal_free') = %(plan)s"
        params["plan"] = requested_plan

    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            SELECT
                o.id AS organization_id,
                o.organization_name,
                o.created_at,
                COALESCE(i.updated_at, o.created_at) AS updated_at,
                o.interest_request_id,
                i.first_name,
                i.surname,
                o.owner_username AS username,
                o.plan AS personal_plan,
                u.id AS user_id,
                CASE
                    WHEN u.approval_status = 'approved' THEN 'live'
                    ELSE 'pending_email_validation'
                END AS account_status,
                COALESCE(i.email_validated, false) AS email_validated,
                i.email_validated_at,
                COALESCE(i.approved_at, u.approved_at) AS approved_at,
                i.approved_by,
                u.invitation_sent_at AS approval_email_sent_at
            FROM "SkwshOrgSettings" AS o
            LEFT JOIN "HitnScoreInterestRequests" AS i
                ON i.id = o.interest_request_id
            LEFT JOIN "SkwshOrgUsers" AS u
                ON u.organization_id = o.id
                AND LOWER(u.clubusername) = LOWER(o.owner_username)
            WHERE o.org_type = 'personal'
                {plan_clause}
            ORDER BY
                COALESCE(i.approved_at, u.approved_at, i.updated_at, o.created_at) DESC,
                i.surname ASC,
                i.first_name ASC,
                o.id DESC
            """,
            params,
        )
        rows = cursor.fetchall()

    return [_serialize_personal_account(row) for row in rows]


def _create_or_refresh_personal_account_for_interest(connection, interest_row, *, updated_by, reset_base_url, source_email):
    now = _utcnow()
    reset_token = secrets.token_urlsafe(32)
    username = (interest_row.get("email") or "").strip().lower()
    full_name = " ".join(
        part for part in [interest_row.get("first_name"), interest_row.get("surname")] if part
    ).strip()
    organization_name = f"{full_name or username} Personal"

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id
            FROM "SkwshOrgSettings"
            WHERE org_type = 'personal'
                AND LOWER(owner_username) = LOWER(%(username)s)
            LIMIT 1
            """,
            {"username": username},
        )
        organization_row = cursor.fetchone()

        if organization_row:
            personal_org_id = organization_row["id"]
            cursor.execute(
                """
                UPDATE "SkwshOrgSettings"
                SET organization_name = %(organization_name)s,
                    org_email = %(username)s,
                    org_contact = %(contact_name)s,
                    plan = CASE
                        WHEN plan IN ('personal_free', 'personal_plus') THEN plan
                        ELSE %(personal_plan)s
                    END,
                    interest_request_id = %(interest_request_id)s,
                    is_hidden = true
                WHERE id = %(organization_id)s
                """,
                {
                    "organization_id": personal_org_id,
                    "organization_name": organization_name,
                    "username": username,
                    "contact_name": full_name or username,
                    "personal_plan": interest_row.get("personal_plan") or "personal_free",
                    "interest_request_id": interest_row["id"],
                },
            )
        else:
            cursor.execute(
                f"SELECT nextval('{PERSONAL_ORG_ID_SEQUENCE}') AS organization_id"
            )
            personal_org_id = cursor.fetchone()["organization_id"]
            cursor.execute(
                """
                INSERT INTO "SkwshOrgSettings" (
                    id,
                    created_at,
                    organization_name,
                    org_contact,
                    org_email,
                    org_type,
                    plan,
                    owner_username,
                    interest_request_id,
                    is_hidden
                )
                VALUES (
                    %(organization_id)s,
                    %(created_at)s,
                    %(organization_name)s,
                    %(org_contact)s,
                    %(org_email)s,
                    'personal',
                    %(plan)s,
                    %(owner_username)s,
                    %(interest_request_id)s,
                    true
                )
                """,
                {
                    "organization_id": personal_org_id,
                    "created_at": now,
                    "organization_name": organization_name,
                    "org_contact": full_name or username,
                    "org_email": username,
                    "plan": interest_row.get("personal_plan") or "personal_free",
                    "owner_username": username,
                    "interest_request_id": interest_row["id"],
                },
            )

        cursor.execute(
            """
            SELECT id
            FROM "SkwshOrgUsers"
            WHERE organization_id = %(organization_id)s
                AND LOWER(clubusername) = LOWER(%(username)s)
            LIMIT 1
            """,
            {"organization_id": personal_org_id, "username": username},
        )
        user_row = cursor.fetchone()

        if user_row:
            cursor.execute(
                """
                UPDATE "SkwshOrgUsers"
                SET role = 'admin',
                    first_name = COALESCE(NULLIF(%(first_name)s, ''), first_name),
                    surname = COALESCE(NULLIF(%(surname)s, ''), surname),
                    approval_status = CASE
                        WHEN approval_status = 'approved' THEN approval_status
                        ELSE 'pending'
                    END,
                    approval_token = NULL,
                    invitation_sent_at = %(invitation_sent_at)s,
                    password_reset_token = %(password_reset_token)s,
                    password_reset_requested_at = %(password_reset_requested_at)s
                WHERE id = %(user_id)s
                RETURNING
                    id AS user_id,
                    organization_id,
                    clubusername AS username,
                    role,
                    approval_status,
                    invitation_sent_at,
                    approved_at
                """,
                {
                    "user_id": user_row["id"],
                    "invitation_sent_at": now,
                    "password_reset_token": reset_token,
                    "password_reset_requested_at": now,
                    "first_name": interest_row.get("first_name") or "",
                    "surname": interest_row.get("surname") or "",
                },
            )
        else:
            cursor.execute(
                """
                INSERT INTO "SkwshOrgUsers" (
                created_at,
                clubusername,
                password_hash,
                organization_id,
                first_name,
                surname,
                role,
                approval_status,
                approval_token,
                invitation_sent_at,
                password_reset_token,
                password_reset_requested_at
            )
            VALUES (
                %(created_at)s,
                %(username)s,
                NULL,
                %(organization_id)s,
                %(first_name)s,
                %(surname)s,
                'admin',
                'pending',
                NULL,
                %(invitation_sent_at)s,
                %(password_reset_token)s,
                %(password_reset_requested_at)s
            )
            RETURNING
                id AS user_id,
                organization_id,
                clubusername AS username,
                role,
                approval_status,
                invitation_sent_at,
                approved_at,
                password_reset_requested_at
            """,
                {
                    "created_at": now,
                    "username": username,
                    "organization_id": personal_org_id,
                    "first_name": interest_row.get("first_name") or "",
                    "surname": interest_row.get("surname") or "",
                    "invitation_sent_at": now,
                    "password_reset_token": reset_token,
                    "password_reset_requested_at": now,
                },
            )
        account_user_row = cursor.fetchone()

        cursor.execute(
            """
            SELECT id
            FROM "SkwshCourts"
            WHERE organization_name = %(organization_id)s
            ORDER BY id ASC
            LIMIT 1
            """,
            {"organization_id": personal_org_id},
        )
        court_row = cursor.fetchone()
        if not court_row:
            cursor.execute(
                """
                INSERT INTO "SkwshCourts" (
                    created_at,
                    court_name,
                    court_alias,
                    organization_name
                )
                VALUES (
                    %(created_at)s,
                    'Personal Court',
                    'Personal Court',
                    %(organization_id)s
                )
                """,
                {"created_at": now, "organization_id": personal_org_id},
            )

    set_password_url = _build_set_password_url(reset_base_url, reset_token)
    account = {
        "username": username,
        "first_name": interest_row.get("first_name") or "",
    }
    _send_personal_account_approved_email(
        account=account,
        set_password_url=set_password_url,
        source_email=source_email,
    )
    return {
        "organization_id": personal_org_id,
        "user_id": account_user_row.get("user_id"),
        "interest_request_id": interest_row["id"],
        "username": username,
        "organization_name": organization_name,
        "first_name": interest_row.get("first_name") or "",
        "surname": interest_row.get("surname") or "",
        "personal_plan": interest_row.get("personal_plan") or "personal_free",
        "account_status": (
            PERSONAL_ACCOUNT_STATUS_LIVE
            if account_user_row.get("approval_status") == "approved"
            else PERSONAL_ACCOUNT_STATUS_PENDING_EMAIL
        ),
        "email_validated": bool(interest_row.get("email_validated")),
        "approved_at": interest_row.get("approved_at"),
        "approved_by": (updated_by or "").strip() or "",
        "approval_email_sent_at": now,
        "created_at": now,
        "updated_at": now,
    }


def update_root_admin_interest_request_status(
    connection,
    request_id,
    status,
    updated_by=None,
    *,
    source_email=None,
    reset_base_url=None,
):
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
                personal_plan,
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

    personal_account = None
    if requested_status == "approved" and (row.get("use_type") or "personal") == "personal":
        if not source_email:
            raise ValueError("INTEREST_FROM_EMAIL must be configured")
        personal_account = _create_or_refresh_personal_account_for_interest(
            connection,
            row,
            updated_by=updated_by,
            reset_base_url=reset_base_url,
            source_email=source_email,
        )

    connection.commit()
    result = _serialize_interest_request(row)
    if personal_account:
        result["personal_account"] = _serialize_personal_account(personal_account)
    return result


def update_root_admin_personal_account_plan(connection, request_id, personal_plan, updated_by=None):
    requested_plan = (personal_plan or "").strip().lower()
    if requested_plan not in PERSONAL_PLANS:
        raise ValueError("personal_plan must be personal_free or personal_plus")

    now = _utcnow()
    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE "SkwshOrgSettings"
            SET plan = %(personal_plan)s
            WHERE id = %(id)s
                AND org_type = 'personal'
            RETURNING
                id AS organization_id,
                organization_name,
                created_at,
                interest_request_id,
                owner_username AS username,
                plan AS personal_plan
            """,
            {
                "id": request_id,
                "personal_plan": requested_plan,
            },
        )
        organization_row = cursor.fetchone()

        if not organization_row:
            row = None
        else:
            cursor.execute(
                """
                SELECT
                    o.id AS organization_id,
                    o.organization_name,
                    o.created_at,
                    %(updated_at)s AS updated_at,
                    o.interest_request_id,
                    i.first_name,
                    i.surname,
                    o.owner_username AS username,
                    o.plan AS personal_plan,
                    u.id AS user_id,
                    CASE
                        WHEN u.approval_status = 'approved' THEN 'live'
                        ELSE 'pending_email_validation'
                    END AS account_status,
                    COALESCE(i.email_validated, false) AS email_validated,
                    i.email_validated_at,
                    COALESCE(i.approved_at, u.approved_at) AS approved_at,
                    i.approved_by,
                    u.invitation_sent_at AS approval_email_sent_at
                FROM "SkwshOrgSettings" AS o
                LEFT JOIN "HitnScoreInterestRequests" AS i
                    ON i.id = o.interest_request_id
                LEFT JOIN "SkwshOrgUsers" AS u
                    ON u.organization_id = o.id
                    AND LOWER(u.clubusername) = LOWER(o.owner_username)
                WHERE o.id = %(organization_id)s
                """,
                {"organization_id": organization_row["organization_id"], "updated_at": now},
            )
            row = cursor.fetchone()

    if not row:
        raise LookupError("Approved personal account not found")

    connection.commit()
    return _serialize_personal_account(row)


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
                AND COALESCE(org_type, 'club') <> 'personal'
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
