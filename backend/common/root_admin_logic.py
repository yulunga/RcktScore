import secrets

from common.mailer import send_email_message
from common.notification_templates import render_notification_template
from common.sport_config import SPORT_LABELS
from common.sport_config import constrain_enabled_sports, fetch_platform_enabled_sports, normalize_enabled_sports
from psycopg.types.json import Jsonb
from psycopg.errors import UndefinedTable
from werkzeug.security import generate_password_hash

from common.organization_logic import (
    APP_DISPLAY_NAME,
    ORGANIZATION_FIELDS,
    _serialize_organization,
    _utcnow,
    approve_organization_user_by_id,
    create_organization_user,
    delete_organization_user,
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


def _serialize_root_admin_match(row):
    created_at = row.get("created_at")
    updated_at = row.get("updated_at")
    completed_at = row.get("completed_at")
    archived_at = row.get("archived_at")
    sport = row.get("sport") or "squash"
    player1_name = " ".join(
        value for value in [row.get("player1_name") or "", row.get("player1_surname") or ""] if value
    ).strip()
    player2_name = " ".join(
        value for value in [row.get("player2_name") or "", row.get("player2_surname") or ""] if value
    ).strip()

    return {
        "id": str(row["id"]),
        "tenant_id": row["tenant_id"],
        "organization_id": row["tenant_id"],
        "organization_name": row.get("organization_name") or f"Organisation {row['tenant_id']}",
        "court_id": row.get("court_id"),
        "court_name": row.get("court_name") or "",
        "court_alias": row.get("court_alias") or "",
        "sport": sport,
        "sport_label": SPORT_LABELS.get(sport, sport.replace("_", " ").title()),
        "player1_name": row.get("player1_name") or "",
        "player1_surname": row.get("player1_surname") or "",
        "player1_display_name": player1_name or (row.get("player1_name") or ""),
        "player2_name": row.get("player2_name") or "",
        "player2_surname": row.get("player2_surname") or "",
        "player2_display_name": player2_name or (row.get("player2_name") or ""),
        "score_type": row.get("score_type"),
        "best_of": row.get("best_of"),
        "current_game_number": row.get("current_game_number") or 1,
        "player1_games_won": row.get("player1_games_won") or 0,
        "player2_games_won": row.get("player2_games_won") or 0,
        "player1_final_score": row.get("player1_final_score"),
        "player2_final_score": row.get("player2_final_score"),
        "winner_name": row.get("winner_name") or "",
        "winner_side": row.get("winner_side") or "",
        "ended_early": bool(row.get("ended_early")),
        "end_reason": row.get("end_reason") or "",
        "status": row.get("status") or "active",
        "is_archived": bool(row.get("is_archived")),
        "created_at": created_at.isoformat() if created_at else None,
        "updated_at": updated_at.isoformat() if updated_at else None,
        "completed_at": completed_at.isoformat() if completed_at else None,
        "archived_at": archived_at.isoformat() if archived_at else None,
    }


def get_root_admin_dashboard(connection):
    platform_enabled_sports = fetch_platform_enabled_sports(connection)
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
                WHERE use_type = 'club'
                """
            )
            interest_summary = cursor.fetchone() or {}
            interest_count = interest_summary.get("interest_count") or 0
            pending_interest_count = interest_summary.get("pending_interest_count") or 0
        except UndefinedTable:
            connection.rollback()

        cursor.execute(
            """
            SELECT COUNT(DISTINCT LOWER(clubusername)) AS total_user_count
            FROM "SkwshOrgUsers"
            """
        )
        total_user_count = (cursor.fetchone() or {}).get("total_user_count") or 0

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

        match_count = 0
        completed_match_count = 0
        try:
            cursor.execute(
                """
                SELECT
                    COUNT(*) AS match_count,
                    COUNT(*) FILTER (WHERE status = 'completed') AS completed_match_count
                FROM matches
                WHERE COALESCE(is_archived, false) = false
                """
            )
            match_summary = cursor.fetchone() or {}
            match_count = match_summary.get("match_count") or 0
            completed_match_count = match_summary.get("completed_match_count") or 0
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
            "total_user_count": total_user_count,
            "match_count": match_count,
            "completed_match_count": completed_match_count,
        },
        "platform_enabled_sports": platform_enabled_sports,
        "organizations": organizations,
    }


def get_root_admin_platform_sports(connection):
    enabled_sports = fetch_platform_enabled_sports(connection)
    return {
        "enabled_sports": enabled_sports,
        "sports": [
            {
                "value": sport_id,
                "label": label,
            }
            for sport_id, label in SPORT_LABELS.items()
        ],
    }


def update_root_admin_platform_sports(connection, enabled_sports, updated_by=None):
    normalized_enabled_sports = normalize_enabled_sports(enabled_sports)
    now = _utcnow()

    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO platform_settings (id, enabled_sports, updated_at)
            VALUES ('default', %(enabled_sports)s, %(updated_at)s)
            ON CONFLICT (id) DO UPDATE
            SET enabled_sports = EXCLUDED.enabled_sports,
                updated_at = EXCLUDED.updated_at
            """,
            {
                "enabled_sports": Jsonb(normalized_enabled_sports),
                "updated_at": now,
            },
        )
        cursor.execute(
            """
            UPDATE "SkwshOrgSettings"
            SET enabled_sports = %(enabled_sports)s
            """,
            {"enabled_sports": Jsonb(normalized_enabled_sports)},
        )
        affected_organization_count = cursor.rowcount

    connection.commit()
    result = get_root_admin_platform_sports(connection)
    result["updated_by"] = (updated_by or "").strip() or ""
    result["updated_at"] = now.isoformat()
    result["affected_organization_count"] = affected_organization_count
    return result


def get_root_admin_matches(connection, sport=None, organization_id=None):
    requested_sport = (sport or "").strip().lower()
    requested_organization_id = None
    if organization_id not in (None, ""):
        requested_organization_id = int(organization_id)

    filters = ["COALESCE(matches.is_archived, false) = false"]
    params = {}

    if requested_sport in SPORT_LABELS:
        filters.append("matches.sport = %(sport)s")
        params["sport"] = requested_sport

    if requested_organization_id is not None:
        filters.append("matches.tenant_id = %(organization_id)s")
        params["organization_id"] = requested_organization_id

    where_clause = " AND ".join(filters)

    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            SELECT
                matches.*,
                org.organization_name
            FROM matches
            LEFT JOIN "SkwshOrgSettings" AS org
                ON org.id = matches.tenant_id
            WHERE {where_clause}
            ORDER BY
                COALESCE(matches.completed_at, matches.updated_at, matches.created_at) DESC,
                matches.updated_at DESC,
                matches.id DESC
            """,
            params,
        )
        match_rows = cursor.fetchall()

        cursor.execute(
            """
            SELECT DISTINCT
                org.id,
                org.organization_name
            FROM "SkwshOrgSettings" AS org
            INNER JOIN matches
                ON matches.tenant_id = org.id
            WHERE COALESCE(matches.is_archived, false) = false
            ORDER BY org.organization_name ASC, org.id ASC
            """
        )
        organization_rows = cursor.fetchall()

    serialized_matches = [_serialize_root_admin_match(row) for row in match_rows]
    summary = {
        "match_count": len(serialized_matches),
        "active_count": sum(1 for match in serialized_matches if match["status"] == "active"),
        "scheduled_count": sum(1 for match in serialized_matches if match["status"] == "scheduled"),
        "completed_count": sum(1 for match in serialized_matches if match["status"] == "completed"),
    }

    return {
        "summary": summary,
        "matches": serialized_matches,
        "filters": {
            "sport": requested_sport if requested_sport in SPORT_LABELS else "",
            "organization_id": requested_organization_id,
        },
        "organizations": [
            {
                "id": row["id"],
                "organization_name": row.get("organization_name") or f"Organisation {row['id']}",
            }
            for row in organization_rows
        ],
        "sports": [
            {
                "value": sport_id,
                "label": label,
            }
            for sport_id, label in SPORT_LABELS.items()
        ],
    }


def _get_root_admin_match_row(connection, match_id, *, include_archived=False):
    archive_clause = "" if include_archived else "AND COALESCE(matches.is_archived, false) = false"
    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            SELECT
                matches.*,
                org.organization_name
            FROM matches
            LEFT JOIN "SkwshOrgSettings" AS org
                ON org.id = matches.tenant_id
            WHERE matches.id = %(match_id)s
              {archive_clause}
            LIMIT 1
            """,
            {"match_id": match_id},
        )
        return cursor.fetchone()


def archive_root_admin_match(connection, match_id):
    match_row = _get_root_admin_match_row(connection, match_id, include_archived=True)
    if not match_row:
        raise LookupError("Match not found")

    if not bool(match_row.get("is_archived")):
        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE matches
                SET is_archived = true,
                    archived_at = %(archived_at)s,
                    updated_at = %(updated_at)s
                WHERE id = %(match_id)s
                """,
                {
                    "match_id": match_id,
                    "archived_at": _utcnow(),
                    "updated_at": _utcnow(),
                },
            )
        connection.commit()
        match_row = _get_root_admin_match_row(connection, match_id, include_archived=True)

    return _serialize_root_admin_match(match_row)


def delete_root_admin_match(connection, match_id):
    match_row = _get_root_admin_match_row(connection, match_id, include_archived=True)
    if not match_row:
        raise LookupError("Match not found")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            DELETE FROM matches
            WHERE id = %(match_id)s
            """,
            {"match_id": match_id},
        )

    connection.commit()
    return {
        "id": str(match_row["id"]),
        "organization_id": match_row["tenant_id"],
        "organization_name": match_row.get("organization_name") or f"Organisation {match_row['tenant_id']}",
        "status": match_row.get("status") or "active",
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
        "requested_plan": row.get("requested_plan") or "",
        "club_address": row.get("club_address") or "",
        "club_postcode": row.get("club_postcode") or "",
        "club_email": row.get("club_email") or "",
        "club_website": row.get("club_website") or "",
        "club_telephone": row.get("club_telephone") or "",
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
        "enabled_sports": normalize_enabled_sports(row.get("enabled_sports")),
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
    where_clauses = ["use_type = 'club'"]
    if requested_status in INTEREST_STATUSES:
        where_clauses.append("approval_status = %(status)s")
        params["status"] = requested_status
    where_clause = f"WHERE {' AND '.join(where_clauses)}"

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
                requested_plan,
                club_address,
                club_postcode,
                club_email,
                club_website,
                club_telephone,
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


def create_self_service_personal_account(
    connection,
    request_id,
    *,
    source_email,
    reset_base_url,
):
    with connection.cursor() as cursor:
        cursor.execute(
            """
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
            WHERE id = %(request_id)s
              AND use_type = 'personal'
            LIMIT 1
            """,
            {"request_id": int(request_id)},
        )
        interest_row = cursor.fetchone()

    if not interest_row:
        raise LookupError("Personal registration was not found")
    if not source_email:
        raise ValueError("INTEREST_FROM_EMAIL must be configured")

    personal_account = _create_or_refresh_personal_account_for_interest(
        connection,
        interest_row,
        updated_by="self-service signup",
        reset_base_url=reset_base_url,
    )
    # Persist the pending account and verification token before attempting
    # delivery. If SES is temporarily unavailable, a retry can refresh and
    # resend the link without losing the registration record.
    connection.commit()

    _send_personal_account_approved_email(
        account=personal_account,
        set_password_url=personal_account.pop("_set_password_url"),
        source_email=source_email,
    )
    email_sent_at = _utcnow()
    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE "SkwshOrgUsers"
            SET invitation_sent_at = %(email_sent_at)s
            WHERE id = %(user_id)s
            """,
            {
                "email_sent_at": email_sent_at,
                "user_id": personal_account["user_id"],
            },
        )
    connection.commit()
    personal_account["approval_email_sent_at"] = email_sent_at
    return _serialize_personal_account(personal_account)


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
                o.enabled_sports,
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


def _create_or_refresh_personal_account_for_interest(connection, interest_row, *, updated_by, reset_base_url):
    now = _utcnow()
    reset_token = secrets.token_urlsafe(32)
    username = (interest_row.get("email") or "").strip().lower()
    full_name = " ".join(
        part for part in [interest_row.get("first_name"), interest_row.get("surname")] if part
    ).strip()
    organization_name = f"{full_name or username} Personal"
    platform_enabled_sports = fetch_platform_enabled_sports(connection)

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
                    enabled_sports = %(enabled_sports)s,
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
                    "enabled_sports": Jsonb(platform_enabled_sports),
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
                    is_hidden,
                    enabled_sports
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
                    true,
                    %(enabled_sports)s
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
                    "enabled_sports": Jsonb(platform_enabled_sports),
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
                    invitation_sent_at = NULL,
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
                NULL,
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
    return {
        "organization_id": personal_org_id,
        "user_id": account_user_row.get("user_id"),
        "interest_request_id": interest_row["id"],
        "username": username,
        "organization_name": organization_name,
        "first_name": interest_row.get("first_name") or "",
        "surname": interest_row.get("surname") or "",
        "personal_plan": interest_row.get("personal_plan") or "personal_free",
        "enabled_sports": platform_enabled_sports,
        "account_status": (
            PERSONAL_ACCOUNT_STATUS_LIVE
            if account_user_row.get("approval_status") == "approved"
            else PERSONAL_ACCOUNT_STATUS_PENDING_EMAIL
        ),
        "email_validated": bool(interest_row.get("email_validated")),
        "approved_at": interest_row.get("approved_at"),
        "approved_by": (updated_by or "").strip() or "",
        "approval_email_sent_at": None,
        "_set_password_url": set_password_url,
        "created_at": now,
        "updated_at": now,
    }


def update_root_admin_interest_request_status(
    connection,
    request_id,
    status,
    updated_by=None,
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
              AND use_type = 'club'
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

    connection.commit()
    return _serialize_interest_request(row)


def update_root_admin_personal_account_settings(
    connection,
    request_id,
    personal_plan=None,
    enabled_sports=None,
    updated_by=None,
):
    updates = {}
    if personal_plan is not None:
        requested_plan = (personal_plan or "").strip().lower()
        if requested_plan not in PERSONAL_PLANS:
            raise ValueError("personal_plan must be personal_free or personal_plus")
        updates["plan"] = requested_plan
    if enabled_sports is not None:
        updates["enabled_sports"] = constrain_enabled_sports(connection, enabled_sports)
    if not updates:
        raise ValueError("At least one personal account setting must be provided")

    now = _utcnow()
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT plan, owner_username, app_account_token
            FROM "SkwshOrgSettings"
            WHERE id = %(id)s AND org_type = 'personal'
            FOR UPDATE
            """,
            {"id": request_id},
        )
        previous_account = cursor.fetchone()
        if not previous_account:
            raise LookupError("Personal account not found")

        set_parts = []
        params = {"id": request_id}
        if "plan" in updates:
            set_parts.append("plan = %(personal_plan)s")
            params["personal_plan"] = updates["plan"]
        if "enabled_sports" in updates:
            set_parts.append("enabled_sports = %(enabled_sports)s")
            params["enabled_sports"] = Jsonb(updates["enabled_sports"])
        cursor.execute(
            f"""
            UPDATE "SkwshOrgSettings"
            SET {", ".join(set_parts)}
            WHERE id = %(id)s
                AND org_type = 'personal'
            RETURNING
                id AS organization_id,
                organization_name,
                created_at,
                interest_request_id,
                owner_username AS username,
                plan AS personal_plan,
                enabled_sports
            """,
            params,
        )
        organization_row = cursor.fetchone()

        if (
            organization_row
            and "plan" in updates
            and previous_account.get("plan") in PERSONAL_PLANS
            and previous_account.get("plan") != updates["plan"]
        ):
            cursor.execute(
                """
                INSERT INTO subscription_entitlement_audit (
                    organization_id, account_username, previous_plan, new_plan,
                    source, reason, effective_at, app_account_token,
                    actor_type, actor_identifier, metadata
                ) VALUES (
                    %(organization_id)s, %(username)s, %(previous_plan)s,
                    %(new_plan)s, 'admin', 'root_admin_plan_override', %(now)s,
                    %(app_account_token)s, 'root_admin', %(updated_by)s,
                    '{}'::jsonb
                )
                """,
                {
                    "organization_id": request_id,
                    "username": previous_account.get("owner_username"),
                    "previous_plan": previous_account.get("plan"),
                    "new_plan": updates["plan"],
                    "now": now,
                    "app_account_token": previous_account.get("app_account_token"),
                    "updated_by": (updated_by or "root_admin").strip(),
                },
            )

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
                    o.enabled_sports,
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


def _first_present(rows, field):
    for row in rows:
        value = row.get(field)
        if value not in (None, ""):
            return value
    return ""


def _serialize_root_admin_user_summary(username, membership_rows):
    ordered_rows = sorted(
        membership_rows,
        key=lambda row: (
            0 if (row.get("org_type") or "club") == "personal" else 1,
            row.get("created_at") or _utcnow(),
            row["membership_id"],
        ),
    )
    personal_rows = [row for row in ordered_rows if (row.get("org_type") or "club") == "personal"]
    club_rows = [row for row in ordered_rows if (row.get("org_type") or "club") != "personal"]
    personal_plan = (personal_rows[0].get("plan") if personal_rows else None) or None
    registered_at = min((row["created_at"] for row in ordered_rows if row.get("created_at")), default=None)
    personal_registration_rows = [row for row in personal_rows if row.get("interest_request_id") is not None]
    memberships_approved = all(
        (row.get("approval_status") or "approved") == "approved"
        for row in ordered_rows
    )
    personal_email_verified = all(
        bool(row.get("email_validated"))
        for row in personal_registration_rows
    )
    email_verified = memberships_approved and personal_email_verified
    verification_dates = [
        row.get("email_validated_at")
        for row in personal_registration_rows
        if row.get("email_validated_at")
    ]
    if not personal_registration_rows:
        verification_dates = [
            row.get("approved_at")
            for row in ordered_rows
            if row.get("approved_at")
        ]
    email_verified_at = max(verification_dates, default=None) if email_verified else None

    account_types = []
    if personal_plan == "personal_free":
        account_types.append("personal_free")
    if personal_plan == "personal_plus":
        account_types.append("personal_plus")
    if club_rows:
        account_types.append("club")

    return {
        "id": min(row["membership_id"] for row in ordered_rows),
        "username": username,
        "first_name": _first_present(ordered_rows, "first_name"),
        "surname": _first_present(ordered_rows, "surname"),
        "registered_at": registered_at.isoformat() if registered_at else None,
        "personal_plan": personal_plan,
        "has_personal_account": bool(personal_rows),
        "has_club_account": bool(club_rows),
        "club_count": len(club_rows),
        "membership_count": len(ordered_rows),
        "account_types": account_types,
        "email_verified": email_verified,
        "email_verified_at": email_verified_at.isoformat() if email_verified_at else None,
        "unverified_membership_count": sum(
            (row.get("approval_status") or "approved") != "approved"
            for row in ordered_rows
        ),
    }


def get_root_admin_users(connection, account_type=None, query=None):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                u.id AS membership_id,
                u.clubusername,
                u.first_name,
                u.surname,
                u.created_at,
                u.approval_status,
                o.org_type,
                o.plan,
                o.interest_request_id,
                i.email_validated
            FROM "SkwshOrgUsers" AS u
            INNER JOIN "SkwshOrgSettings" AS o
                ON o.id = u.organization_id
            LEFT JOIN "HitnScoreInterestRequests" AS i
                ON i.id = o.interest_request_id
            ORDER BY LOWER(u.clubusername), u.created_at ASC, u.id ASC
            """
        )
        rows = cursor.fetchall()

    memberships_by_username = {}
    for row in rows:
        username = (row.get("clubusername") or "").strip().lower()
        if username:
            memberships_by_username.setdefault(username, []).append(row)

    users = [
        _serialize_root_admin_user_summary(username, membership_rows)
        for username, membership_rows in memberships_by_username.items()
    ]
    users.sort(key=lambda user: (user["surname"].lower(), user["first_name"].lower(), user["username"]))

    summary = {
        "total_user_count": len(users),
        "personal_free_count": sum("personal_free" in user["account_types"] for user in users),
        "personal_plus_count": sum("personal_plus" in user["account_types"] for user in users),
        "club_user_count": sum("club" in user["account_types"] for user in users),
        "unverified_user_count": sum(not user["email_verified"] for user in users),
    }

    requested_account_type = (account_type or "").strip().lower()
    if requested_account_type == "unverified":
        users = [user for user in users if not user["email_verified"]]
    elif requested_account_type in {"personal_free", "personal_plus", "club"}:
        users = [user for user in users if requested_account_type in user["account_types"]]

    search_text = (query or "").strip().lower()
    if search_text:
        users = [
            user
            for user in users
            if search_text in " ".join(
                [user["username"], user["first_name"], user["surname"]]
            ).lower()
        ]

    return {
        "summary": summary,
        "users": users,
        "filters": {
            "account_type": requested_account_type,
            "query": search_text,
        },
    }


def _root_admin_user_username(connection, user_id):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT clubusername
            FROM "SkwshOrgUsers"
            WHERE id = %(user_id)s
            LIMIT 1
            """,
            {"user_id": int(user_id)},
        )
        row = cursor.fetchone()

    return (row or {}).get("clubusername")


def get_root_admin_user_profile(connection, user_id):
    username = _root_admin_user_username(connection, user_id)
    if not username:
        return None

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                u.id AS membership_id,
                u.clubusername,
                u.role,
                u.approval_status,
                u.first_name,
                u.surname,
                u.country,
                u.telephone,
                u.city_location,
                u.created_at,
                u.invitation_sent_at,
                u.approved_at,
                o.id AS organization_id,
                o.organization_name,
                o.org_type,
                o.plan,
                o.enabled_sports,
                o.interest_request_id,
                i.email_validated,
                i.email_validated_at,
                i.approved_by
            FROM "SkwshOrgUsers" AS u
            INNER JOIN "SkwshOrgSettings" AS o
                ON o.id = u.organization_id
            LEFT JOIN "HitnScoreInterestRequests" AS i
                ON i.id = o.interest_request_id
            WHERE LOWER(u.clubusername) = LOWER(%(username)s)
            ORDER BY
                CASE WHEN o.org_type = 'personal' THEN 0 ELSE 1 END,
                o.organization_name ASC,
                u.id ASC
            """,
            {"username": username},
        )
        membership_rows = cursor.fetchall()

        cursor.execute(
            """
            SELECT
                m.sport,
                COUNT(*) AS match_count
            FROM matches AS m
            WHERE LOWER(COALESCE(m.referee_name, '')) = LOWER(%(username)s)
               OR m.tenant_id IN (
                    SELECT personal_u.organization_id
                    FROM "SkwshOrgUsers" AS personal_u
                    INNER JOIN "SkwshOrgSettings" AS personal_o
                        ON personal_o.id = personal_u.organization_id
                    WHERE LOWER(personal_u.clubusername) = LOWER(%(username)s)
                      AND personal_o.org_type = 'personal'
               )
            GROUP BY m.sport
            ORDER BY COUNT(*) DESC, m.sport ASC
            """,
            {"username": username},
        )
        sport_rows = cursor.fetchall()

        cursor.execute(
            """
            SELECT
                m.id,
                m.sport,
                m.status,
                m.player1_name,
                m.player1_surname,
                m.player2_name,
                m.player2_surname,
                m.created_at,
                m.updated_at,
                o.organization_name
            FROM matches AS m
            LEFT JOIN "SkwshOrgSettings" AS o
                ON o.id = m.tenant_id
            WHERE LOWER(COALESCE(m.referee_name, '')) = LOWER(%(username)s)
               OR m.tenant_id IN (
                    SELECT personal_u.organization_id
                    FROM "SkwshOrgUsers" AS personal_u
                    INNER JOIN "SkwshOrgSettings" AS personal_o
                        ON personal_o.id = personal_u.organization_id
                    WHERE LOWER(personal_u.clubusername) = LOWER(%(username)s)
                      AND personal_o.org_type = 'personal'
               )
            ORDER BY COALESCE(m.updated_at, m.created_at) DESC, m.id DESC
            LIMIT 10
            """,
            {"username": username},
        )
        recent_match_rows = cursor.fetchall()

        cursor.execute(
            """
            SELECT id, organization_name
            FROM "SkwshOrgSettings"
            WHERE COALESCE(org_type, 'club') <> 'personal'
              AND id NOT IN (
                  SELECT organization_id
                  FROM "SkwshOrgUsers"
                  WHERE LOWER(clubusername) = LOWER(%(username)s)
              )
            ORDER BY organization_name ASC, id ASC
            """,
            {"username": username},
        )
        available_clubs = cursor.fetchall()

        cursor.execute(
            """
            SELECT MAX(last_seen_at) AS last_activity_at
            FROM org_user_sessions
            WHERE LOWER(username) = LOWER(%(username)s)
            """,
            {"username": username},
        )
        session_activity = cursor.fetchone() or {}

    summary = _serialize_root_admin_user_summary(username.lower(), membership_rows)
    memberships = []
    for row in membership_rows:
        memberships.append(
            {
                "id": row["membership_id"],
                "organization_id": row["organization_id"],
                "organization_name": row.get("organization_name") or f"Organisation {row['organization_id']}",
                "organization_type": row.get("org_type") or "club",
                "plan": row.get("plan") or ("personal_free" if row.get("org_type") == "personal" else "club_essentials"),
                "role": row.get("role") or "user",
                "status": row.get("approval_status") or "approved",
                "enabled_sports": normalize_enabled_sports(row.get("enabled_sports")),
                "registered_at": row["created_at"].isoformat() if row.get("created_at") else None,
                "invitation_sent_at": row["invitation_sent_at"].isoformat() if row.get("invitation_sent_at") else None,
                "approved_at": row["approved_at"].isoformat() if row.get("approved_at") else None,
            }
        )

    recent_matches = []
    for row in recent_match_rows:
        player1 = " ".join(part for part in [row.get("player1_name"), row.get("player1_surname")] if part).strip()
        player2 = " ".join(part for part in [row.get("player2_name"), row.get("player2_surname")] if part).strip()
        recent_matches.append(
            {
                "id": str(row["id"]),
                "sport": row.get("sport") or "squash",
                "sport_label": SPORT_LABELS.get(row.get("sport") or "squash", (row.get("sport") or "squash").title()),
                "status": row.get("status") or "active",
                "players": f"{player1 or 'Player 1'} vs {player2 or 'Player 2'}",
                "organization_name": row.get("organization_name") or "Unknown organisation",
                "created_at": row["created_at"].isoformat() if row.get("created_at") else None,
                "updated_at": row["updated_at"].isoformat() if row.get("updated_at") else None,
            }
        )

    summary.update(
        {
            "email": username.lower(),
            "country": _first_present(membership_rows, "country"),
            "telephone": _first_present(membership_rows, "telephone"),
            "city_location": _first_present(membership_rows, "city_location"),
            "last_activity_at": (
                session_activity["last_activity_at"].isoformat()
                if session_activity.get("last_activity_at")
                else None
            ),
        }
    )
    game_types = [
        {
            "sport": row.get("sport") or "squash",
            "label": SPORT_LABELS.get(row.get("sport") or "squash", (row.get("sport") or "squash").title()),
            "match_count": row.get("match_count") or 0,
        }
        for row in sport_rows
    ]

    return {
        "user": summary,
        "memberships": memberships,
        "activity": {
            "match_count": sum(item["match_count"] for item in game_types),
            "game_types": game_types,
            "recent_matches": recent_matches,
            "attribution_note": "Club activity is attributed from the recorded referee username; personal activity includes matches in the user's personal account.",
        },
        "available_clubs": [
            {
                "id": row["id"],
                "organization_name": row.get("organization_name") or f"Organisation {row['id']}",
            }
            for row in available_clubs
        ],
    }


def add_root_admin_user_club_membership(
    connection,
    user_id,
    organization_id,
    role,
    *,
    invitation_source_email=None,
    approval_base_url=None,
):
    username = _root_admin_user_username(connection, user_id)
    if not username:
        raise LookupError("User not found")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT COALESCE(org_type, 'club') AS org_type
            FROM "SkwshOrgSettings"
            WHERE id = %(organization_id)s
            LIMIT 1
            """,
            {"organization_id": int(organization_id)},
        )
        organization = cursor.fetchone()
    if not organization:
        raise LookupError("Club not found")
    if organization.get("org_type") == "personal":
        raise ValueError("Users can only be added to club organisations here")

    return create_organization_user(
        connection,
        organization_id,
        username,
        None,
        role,
        allow_existing_password_reuse=True,
        invitation_source_email=invitation_source_email,
        approval_base_url=approval_base_url,
    )


def remove_root_admin_user_club_membership(connection, user_id, membership_id):
    username = _root_admin_user_username(connection, user_id)
    if not username:
        raise LookupError("User not found")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT u.organization_id, u.clubusername, COALESCE(o.org_type, 'club') AS org_type
            FROM "SkwshOrgUsers" AS u
            INNER JOIN "SkwshOrgSettings" AS o
                ON o.id = u.organization_id
            WHERE u.id = %(membership_id)s
              AND LOWER(u.clubusername) = LOWER(%(username)s)
            LIMIT 1
            """,
            {"membership_id": int(membership_id), "username": username},
        )
        membership = cursor.fetchone()

    if not membership:
        raise LookupError("Club membership not found")
    if membership.get("org_type") == "personal":
        raise ValueError("Personal account membership cannot be removed as a club association")

    deleted = delete_organization_user(
        connection,
        membership["organization_id"],
        membership_id,
    )
    if not deleted:
        raise LookupError("Club membership not found")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT MIN(id) AS next_user_id
            FROM "SkwshOrgUsers"
            WHERE LOWER(clubusername) = LOWER(%(username)s)
            """,
            {"username": username},
        )
        remaining_user = cursor.fetchone() or {}
    return {
        "deleted": True,
        "membership_id": int(membership_id),
        "organization_id": membership["organization_id"],
        "next_user_id": remaining_user.get("next_user_id"),
    }


def update_root_admin_user_password(connection, user_id, password):
    next_password = str(password or "")
    if len(next_password) < 8:
        raise ValueError("Password must be at least 8 characters")

    username = _root_admin_user_username(connection, user_id)
    if not username:
        raise LookupError("User not found")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE "SkwshOrgUsers"
            SET password_hash = %(password_hash)s,
                password_reset_token = NULL,
                password_reset_requested_at = NULL
            WHERE LOWER(clubusername) = LOWER(%(username)s)
            """,
            {
                "password_hash": generate_password_hash(next_password),
                "username": username,
            },
        )

    from common.session_logic import revoke_active_sessions_for_username
    revoke_active_sessions_for_username(connection, username, reason="password_reset_by_root_admin")
    connection.commit()
    return {"updated": True, "username": username.lower()}


def verify_root_admin_user_email(connection, user_id, verified_by):
    username = _root_admin_user_username(connection, user_id)
    if not username:
        raise LookupError("User not found")

    verified_at = _utcnow()
    actor = (verified_by or "").strip() or "Root Admin"
    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE "SkwshOrgUsers"
            SET approval_status = 'approved',
                approved_at = COALESCE(approved_at, %(verified_at)s)
            WHERE LOWER(clubusername) = LOWER(%(username)s)
              AND approval_status = 'pending'
            """,
            {"username": username, "verified_at": verified_at},
        )
        approved_memberships = cursor.rowcount

        cursor.execute(
            """
            UPDATE "HitnScoreInterestRequests"
            SET email_validated = true,
                email_validated_at = COALESCE(email_validated_at, %(verified_at)s),
                updated_at = %(verified_at)s,
                approved_by = %(verified_by)s
            WHERE LOWER(email) = LOWER(%(username)s)
              AND use_type = 'personal'
              AND email_validated IS NOT TRUE
            """,
            {
                "username": username,
                "verified_at": verified_at,
                "verified_by": actor,
            },
        )
        validated_registrations = cursor.rowcount

    connection.commit()
    return {
        "verified": True,
        "username": username.lower(),
        "verified_at": verified_at.isoformat(),
        "verified_by": actor,
        "approved_memberships": approved_memberships,
        "validated_registrations": validated_registrations,
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

    enabled_sports = fetch_platform_enabled_sports(connection)

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
                org_webaddress,
                enabled_sports
            )
            VALUES (
                %(created_at)s,
                %(organization_name)s,
                %(org_address)s,
                %(org_postcode)s,
                %(org_contact)s,
                %(org_telephone)s,
                %(org_email)s,
                %(org_webaddress)s,
                %(enabled_sports)s
            )
            RETURNING
                id,
                organization_name,
                org_address,
                org_postcode,
                org_contact,
                org_telephone,
                org_email,
                org_webaddress,
                enabled_sports
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
                "enabled_sports": Jsonb(enabled_sports),
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


def approve_root_admin_org_user(connection, organization_id, user_id):
    return approve_organization_user_by_id(connection, organization_id, user_id)
