import re
import secrets
from datetime import datetime, timezone

from werkzeug.security import check_password_hash, generate_password_hash

from common.mailer import send_email_message
from common.notification_templates import render_notification_template

VALID_ROLES = {"admin", "user"}
USER_STATUS_PENDING = "pending"
USER_STATUS_APPROVED = "approved"
VALID_USER_STATUSES = {USER_STATUS_PENDING, USER_STATUS_APPROVED}
EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
APP_DISPLAY_NAME = "Hit n Score"
ORGANIZATION_FIELDS = [
    "organization_name",
    "org_address",
    "org_postcode",
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
        "org_postcode": row.get("org_postcode") or "",
        "org_contact": row.get("org_contact") or "",
        "org_telephone": row.get("org_telephone") or "",
        "org_email": row.get("org_email") or "",
        "org_webaddress": row.get("org_webaddress") or "",
        "org_type": row.get("org_type") or "club",
        "plan": row.get("plan") or "club_essentials",
        "is_hidden": bool(row.get("is_hidden")),
        "social_profiles": {
            "facebook": "",
            "instagram": "",
            "x": "",
            "youtube": "",
        },
    }


def _serialize_user(row):
    created_at = row.get("created_at")
    approved_at = row.get("approved_at")
    invitation_sent_at = row.get("invitation_sent_at")
    return {
        "id": row["id"],
        "username": row["clubusername"],
        "role": row.get("role") or "user",
        "status": row.get("approval_status") or USER_STATUS_APPROVED,
        "first_name": row.get("first_name") or "",
        "surname": row.get("surname") or "",
        "country": row.get("country") or "",
        "city_location": row.get("city_location") or "",
        "created_at": created_at.isoformat() if created_at else None,
        "approved_at": approved_at.isoformat() if approved_at else None,
        "invitation_sent_at": invitation_sent_at.isoformat() if invitation_sent_at else None,
    }


def normalize_email_address(value):
    return (value or "").strip().lower()


def is_valid_email_address(value):
    return bool(EMAIL_PATTERN.match(normalize_email_address(value)))


def _build_approval_url(base_url, token):
    if not base_url:
        raise ValueError("USER_APPROVAL_BASE_URL must be configured")

    return f"{base_url.rstrip('/')}/organization_users/approve?token={token}"


def _get_organization_name(connection, organization_id):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT organization_name
            FROM "SkwshOrgSettings"
            WHERE id = %(organization_id)s
            LIMIT 1
            """,
            {"organization_id": int(organization_id)},
        )
        row = cursor.fetchone()

    return (row or {}).get("organization_name") or f"Organisation {organization_id}"


def _send_organization_user_invitation_email(
    *,
    username,
    organization_name,
    approval_url,
    source_email,
    existing_account,
):
    template_context = {
        "app_name": APP_DISPLAY_NAME,
        "approval_url": approval_url,
        "organization_name": organization_name,
        "username": username,
    }
    template_prefix = "org_user_invitation_existing" if existing_account else "org_user_invitation_new"
    subject = render_notification_template(f"{template_prefix}_subject.txt", template_context).strip()
    body_text = render_notification_template(f"{template_prefix}_body.txt", template_context).strip()

    send_email_message(
        destination_email=username,
        source_email=source_email,
        subject=subject,
        text_body=body_text,
    )


def get_existing_org_users_by_username(connection, username):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id, organization_id, password_hash, approval_status
            FROM "SkwshOrgUsers"
            WHERE LOWER(clubusername) = LOWER(%(username)s)
            ORDER BY organization_id ASC, id ASC
            """,
            {"username": normalize_email_address(username)},
        )
        return cursor.fetchall()


def _serialize_court(row):
    created_at = row.get("created_at")
    return {
        "id": row["id"],
        "court_name": row.get("court_name") or "",
        "court_alias": row.get("court_alias") or "",
        "created_at": created_at.isoformat() if created_at else None,
    }


def _ensure_personal_default_court(connection, organization_id, organization_row):
    if (organization_row or {}).get("org_type") != "personal":
        return

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id
            FROM "SkwshCourts"
            WHERE organization_name = %(organization_id)s
            LIMIT 1
            """,
            {"organization_id": organization_id},
        )
        if cursor.fetchone():
            return

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
                'Personal Match',
                'Personal Match',
                %(organization_id)s
            )
            """,
            {
                "created_at": _utcnow(),
                "organization_id": organization_id,
            },
        )

    connection.commit()


def get_organization_settings(connection, organization_id):
    org_id = int(organization_id)

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                id,
                organization_name,
                org_address,
                org_postcode,
                org_contact,
                org_telephone,
                org_email,
                org_webaddress,
                org_type,
                plan,
                is_hidden
            FROM "SkwshOrgSettings"
            WHERE id = %(organization_id)s
            LIMIT 1
            """,
            {"organization_id": org_id},
        )
        organization_row = cursor.fetchone()

        if not organization_row:
            return None

    _ensure_personal_default_court(connection, org_id, organization_row)

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                id,
                clubusername,
                role,
                approval_status,
                first_name,
                surname,
                country,
                city_location,
                created_at,
                invitation_sent_at,
                approved_at
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


def update_personal_profile(connection, organization_id, username, payload):
    org_id = int(organization_id)
    normalized_username = normalize_email_address(username)
    if not normalized_username:
        raise ValueError("username is required")

    updates = {
        field: payload[field].strip() if isinstance(payload.get(field), str) else payload.get(field)
        for field in ["first_name", "surname", "country", "city_location"]
        if field in payload
    }

    if not updates:
        return get_organization_settings(connection, org_id)

    set_clause = ", ".join(f"{field} = %({field})s" for field in updates)
    params = {
        **updates,
        "organization_id": org_id,
        "username": normalized_username,
    }
    with connection.cursor() as cursor:
        cursor.execute(
            f'''
            UPDATE "SkwshOrgUsers"
            SET {set_clause}
            WHERE organization_id = %(organization_id)s
                AND LOWER(clubusername) = LOWER(%(username)s)
            ''',
            params,
        )

    connection.commit()
    return get_organization_settings(connection, org_id)


def create_organization_user(
    connection,
    organization_id,
    username,
    password,
    role,
    *,
    allow_existing_password_reuse=False,
    invitation_source_email=None,
    approval_base_url=None,
):
    org_id = int(organization_id)
    normalized_role = (role or "user").strip().lower()
    if normalized_role not in VALID_ROLES:
        raise ValueError("role must be admin or user")

    trimmed_username = normalize_email_address(username)
    if not trimmed_username:
        raise ValueError("username is required")
    if not is_valid_email_address(trimmed_username):
        raise ValueError("Username must be a valid email address")

    existing_users = get_existing_org_users_by_username(connection, trimmed_username)
    existing_hash = None
    existing_account = bool(existing_users)
    for existing_user in existing_users:
        if int(existing_user["organization_id"]) == org_id:
            raise ValueError("Username already exists in this organisation")
        if existing_user.get("password_hash") and existing_hash is None:
            existing_hash = existing_user["password_hash"]

    if existing_hash:
        if not allow_existing_password_reuse:
            if not password:
                raise ValueError("Password is required when adding an existing username")
            if not check_password_hash(existing_hash, password):
                raise ValueError("Username already exists with a different password")
    elif not password:
        raise ValueError("Password is required for a new user")

    approval_token = secrets.token_urlsafe(32)
    approval_status = USER_STATUS_PENDING
    created_at = _utcnow()
    organization_name = _get_organization_name(connection, org_id)
    source_email = (invitation_source_email or "").strip() or None
    approval_url = _build_approval_url(approval_base_url, approval_token)

    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO "SkwshOrgUsers" (
                created_at,
                clubusername,
                password_hash,
                organization_id,
                role,
                approval_status,
                approval_token,
                invitation_sent_at
            )
            VALUES (
                %(created_at)s,
                %(username)s,
                %(password_hash)s,
                %(organization_id)s,
                %(role)s,
                %(approval_status)s,
                %(approval_token)s,
                %(invitation_sent_at)s
            )
            RETURNING id, clubusername, role, approval_status, created_at, invitation_sent_at, approved_at
            """,
            {
                "created_at": created_at,
                "username": trimmed_username,
                "password_hash": existing_hash or generate_password_hash(password),
                "organization_id": org_id,
                "role": normalized_role,
                "approval_status": approval_status,
                "approval_token": approval_token,
                "invitation_sent_at": created_at,
            },
        )
        user_row = cursor.fetchone()

    if source_email:
        _send_organization_user_invitation_email(
            username=trimmed_username,
            organization_name=organization_name,
            approval_url=approval_url,
            source_email=source_email,
            existing_account=existing_account,
        )

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
            RETURNING id, clubusername, role, approval_status, created_at, invitation_sent_at, approved_at
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


def approve_organization_user_membership(connection, token):
    trimmed_token = (token or "").strip()
    if not trimmed_token:
        return None

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                u.id,
                u.clubusername,
                u.role,
                u.approval_status,
                u.created_at,
                u.invitation_sent_at,
                u.approved_at,
                o.organization_name
            FROM "SkwshOrgUsers" AS u
            LEFT JOIN "SkwshOrgSettings" AS o
                ON o.id = u.organization_id
            WHERE u.approval_token = %(token)s
            LIMIT 1
            """,
            {"token": trimmed_token},
        )
        user_row = cursor.fetchone()

        if not user_row:
            return None

        if (user_row.get("approval_status") or USER_STATUS_APPROVED) != USER_STATUS_PENDING:
            return {
                "result": "already_approved",
                "organization_name": user_row.get("organization_name") or "",
                "username": user_row.get("clubusername") or "",
            }

        cursor.execute(
            """
            UPDATE "SkwshOrgUsers"
            SET approval_status = %(approval_status)s,
                approved_at = %(approved_at)s
            WHERE id = %(user_id)s
            RETURNING clubusername
            """,
            {
                "approval_status": USER_STATUS_APPROVED,
                "approved_at": _utcnow(),
                "user_id": user_row["id"],
            },
        )
        cursor.fetchone()

    connection.commit()
    return {
        "result": "approved",
        "organization_name": user_row.get("organization_name") or "",
        "username": user_row.get("clubusername") or "",
    }


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
