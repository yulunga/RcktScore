import hashlib
import secrets
from datetime import datetime, timezone

from common.auth_logic import _serialize_org_user
from common.organization_logic import USER_STATUS_APPROVED, normalize_email_address
from common.utils import error_response


def _utcnow():
    return datetime.now(timezone.utc)


class SessionAuthError(Exception):
    def __init__(self, status_code, code, message, details=None):
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message
        self.details = details


def session_error_response(error):
    return error_response(error.status_code, error.code, error.message, error.details)


def _token_hash(token):
    return hashlib.sha256((token or "").encode("utf-8")).hexdigest()


def _request_headers(event):
    return {
        (key or "").lower(): value
        for key, value in (event.get("headers") or {}).items()
    }


def is_root_admin_request(event):
    headers = _request_headers(event)
    value = (headers.get("x-root-admin-request") or "").strip().lower()
    return value in {"1", "true", "yes"}


def session_token_from_event(event):
    headers = _request_headers(event)
    authorization = (headers.get("authorization") or "").strip()
    if authorization.lower().startswith("bearer "):
        return authorization[7:].strip()

    return (headers.get("x-session-token") or "").strip()


def normalize_login_source(login_source):
    normalized = (login_source or "").strip().lower()
    if normalized in {"web", "web_app", "browser"}:
        return "web_app"
    if normalized in {"mobile", "mobile_app", "ios", "ios_app"}:
        return "mobile_app"
    return "web_app"


def login_source_label(login_source):
    normalized = normalize_login_source(login_source)
    if normalized == "mobile_app":
        return "mobile app"
    return "web app"


def revoke_active_sessions_for_username(connection, username, reason="replaced_by_new_login", login_source=None):
    normalized_username = normalize_email_address(username)
    if not normalized_username:
        return

    source_clause = ""
    query_params = {
        "username": normalized_username,
        "revoked_at": _utcnow(),
        "revoked_reason": reason,
    }
    if login_source:
        source_clause = "AND login_source = %(login_source)s"
        query_params["login_source"] = normalize_login_source(login_source)

    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            UPDATE org_user_sessions
            SET revoked_at = %(revoked_at)s,
                revoked_reason = %(revoked_reason)s
            WHERE LOWER(username) = LOWER(%(username)s)
              AND revoked_at IS NULL
              {source_clause}
            """,
            query_params,
        )


def create_org_user_session(connection, username, login_source="login"):
    normalized_username = normalize_email_address(username)
    if not normalized_username:
        raise ValueError("username is required")

    normalized_source = normalize_login_source(login_source)
    token = secrets.token_urlsafe(48)
    now = _utcnow()
    revoke_active_sessions_for_username(
        connection,
        normalized_username,
        reason="replaced_by_new_login",
        login_source=normalized_source,
    )

    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO org_user_sessions (
                username,
                token_hash,
                login_source,
                created_at,
                last_seen_at
            )
            VALUES (
                %(username)s,
                %(token_hash)s,
                %(login_source)s,
                %(created_at)s,
                %(last_seen_at)s
            )
            """,
            {
                "username": normalized_username,
                "token_hash": _token_hash(token),
                "login_source": normalized_source,
                "created_at": now,
                "last_seen_at": now,
            },
        )

    connection.commit()
    return token


def get_active_session_for_username(connection, username, login_source):
    normalized_username = normalize_email_address(username)
    normalized_source = normalize_login_source(login_source)
    if not normalized_username:
        return None

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                id,
                username,
                login_source,
                created_at,
                last_seen_at
            FROM org_user_sessions
            WHERE LOWER(username) = LOWER(%(username)s)
              AND login_source = %(login_source)s
              AND revoked_at IS NULL
            ORDER BY id DESC
            LIMIT 1
            """,
            {
                "username": normalized_username,
                "login_source": normalized_source,
            },
        )
        return cursor.fetchone()


def revoke_org_user_session(connection, token, reason="logout"):
    hashed = _token_hash(token)
    if not hashed:
        return False

    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE org_user_sessions
            SET revoked_at = COALESCE(revoked_at, %(revoked_at)s),
                revoked_reason = COALESCE(revoked_reason, %(revoked_reason)s)
            WHERE token_hash = %(token_hash)s
            """,
            {
                "token_hash": hashed,
                "revoked_at": _utcnow(),
                "revoked_reason": reason,
            },
        )
        updated = cursor.rowcount > 0

    connection.commit()
    return updated


def _get_session_row(connection, token, *, include_revoked=False):
    hashed = _token_hash(token)
    if not hashed:
        return None

    revoked_clause = "" if include_revoked else "AND revoked_at IS NULL"

    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            SELECT
                id,
                username,
                created_at,
                last_seen_at,
                revoked_at,
                revoked_reason
            FROM org_user_sessions
            WHERE token_hash = %(token_hash)s
              {revoked_clause}
            ORDER BY id DESC
            LIMIT 1
            """,
            {"token_hash": hashed},
        )
        return cursor.fetchone()


def require_org_user_session(connection, event):
    token = session_token_from_event(event)
    if not token:
        raise SessionAuthError(401, "SESSION_REQUIRED", "Please sign in to continue.")

    session_row = _get_session_row(connection, token)
    if not session_row:
        revoked_row = _get_session_row(connection, token, include_revoked=True)
        if revoked_row and revoked_row.get("revoked_reason") == "replaced_by_new_login":
            raise SessionAuthError(
                401,
                "SESSION_REPLACED",
                "You were signed out because your account was used to sign in elsewhere.",
            )

        raise SessionAuthError(401, "SESSION_INVALID", "Your session is no longer valid. Please sign in again.")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE org_user_sessions
            SET last_seen_at = %(last_seen_at)s
            WHERE id = %(session_id)s
            """,
            {
                "session_id": session_row["id"],
                "last_seen_at": _utcnow(),
            },
        )
    connection.commit()

    return {
        "id": session_row["id"],
        "username": session_row["username"],
        "token": token,
    }


def _get_membership_row(connection, username, organization_id):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                u.id,
                u.clubusername,
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
              AND u.organization_id = %(organization_id)s
            LIMIT 1
            """,
            {
                "username": normalize_email_address(username),
                "organization_id": int(organization_id),
            },
        )
        return cursor.fetchone()


def authorize_organization_session(connection, event, organization_id, require_admin=False):
    session = require_org_user_session(connection, event)
    membership_row = _get_membership_row(connection, session["username"], organization_id)

    if not membership_row:
        raise SessionAuthError(403, "SESSION_FORBIDDEN", "You do not have access to this organisation.")

    membership = _serialize_org_user(membership_row)
    if membership["status"] != USER_STATUS_APPROVED:
        raise SessionAuthError(403, "SESSION_FORBIDDEN", "Your organisation access is not approved.")

    if require_admin and membership["role"] != "admin" and membership["organization_type"] != "personal":
        raise SessionAuthError(403, "SESSION_ADMIN_REQUIRED", "Administrator access is required for this action.")

    return {
        "session": session,
        "membership": membership,
    }


def authorize_personal_profile_session(connection, event, organization_id, username):
    auth_context = authorize_organization_session(connection, event, organization_id, require_admin=False)
    session_username = normalize_email_address(auth_context["session"]["username"])
    requested_username = normalize_email_address(username)

    if session_username != requested_username:
        raise SessionAuthError(403, "SESSION_FORBIDDEN", "You can only update your own personal profile.")

    return auth_context


def _get_match_tenant_id(connection, match_id):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT tenant_id
            FROM matches
            WHERE id = %(match_id)s
            LIMIT 1
            """,
            {"match_id": match_id},
        )
        row = cursor.fetchone()

    return (row or {}).get("tenant_id")


def authorize_match_session(connection, event, match_id):
    tenant_id = _get_match_tenant_id(connection, match_id)
    if tenant_id is None:
        raise SessionAuthError(404, "MATCH_NOT_FOUND", "Match not found")

    auth_context = authorize_organization_session(connection, event, tenant_id, require_admin=False)
    auth_context["tenant_id"] = tenant_id
    return auth_context
