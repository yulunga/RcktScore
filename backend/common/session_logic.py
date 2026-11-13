import hashlib
import os
import secrets
from datetime import datetime, timedelta, timezone

from common.auth_logic import _serialize_org_user
from common.access_control import (
    CAPABILITY_MATCH_READ,
    CAPABILITY_MATCH_MANAGE,
    ROLE_ADMIN,
    normalize_membership_role,
    membership_has_capability,
)
from common.organization_logic import USER_STATUS_APPROVED, normalize_email_address
from common.utils import error_response


def _utcnow():
    return datetime.now(timezone.utc)


DEFAULT_ORG_USER_SESSION_TTL_DAYS = 30
MAX_ORG_USER_SESSION_TTL_DAYS = 90
WEB_SESSION_COOKIE = "__Host-hitnscore_session"
ROOT_ADMIN_SESSION_COOKIE = "__Host-hitnscore_root_admin"
UNSAFE_METHODS = {"POST", "PUT", "PATCH", "DELETE"}


def _session_ttl_days():
    configured_value = (os.getenv("ORG_USER_SESSION_TTL_DAYS") or "").strip()
    try:
        days = int(configured_value or DEFAULT_ORG_USER_SESSION_TTL_DAYS)
    except ValueError:
        days = DEFAULT_ORG_USER_SESSION_TTL_DAYS
    return max(1, min(days, MAX_ORG_USER_SESSION_TTL_DAYS))


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


def _cookie_value(event, cookie_name):
    cookie_parts = list(event.get("cookies") or [])
    headers = _request_headers(event)
    if headers.get("cookie"):
        cookie_parts.extend(headers["cookie"].split(";"))
    for cookie_part in cookie_parts:
        name, separator, value = str(cookie_part).strip().partition("=")
        if separator and name == cookie_name:
            return value.strip()
    return ""


def _bearer_token_from_event(event):
    headers = _request_headers(event)
    authorization = (headers.get("authorization") or "").strip()
    if authorization.lower().startswith("bearer "):
        return authorization[7:].strip()
    return ""


def session_token_from_event(event):
    return _bearer_token_from_event(event)


def session_credentials_from_event(event, cookie_name=WEB_SESSION_COOKIE):
    bearer_token = _bearer_token_from_event(event)
    cookie_token = _cookie_value(event, cookie_name)
    if bearer_token and cookie_token:
        raise SessionAuthError(
            400,
            "AMBIGUOUS_SESSION_CREDENTIALS",
            "Use either browser-cookie authentication or native bearer authentication, not both.",
        )
    if cookie_token:
        return cookie_token, "cookie"
    if bearer_token:
        return bearer_token, "bearer"
    return "", None


def web_app_origin():
    return (os.getenv("WEB_APP_ORIGIN") or "https://app.hitnscore.com").rstrip("/")


def validate_web_origin(event):
    origin = (_request_headers(event).get("origin") or "").rstrip("/")
    if origin != web_app_origin():
        raise SessionAuthError(403, "ORIGIN_REJECTED", "This request did not originate from the HitnScore web app.")


def _request_method(event):
    request_context = event.get("requestContext") or {}
    http_context = request_context.get("http") or {}
    return str(http_context.get("method") or event.get("httpMethod") or "GET").upper()


def _validate_cookie_csrf(event, session_row):
    if _request_method(event) not in UNSAFE_METHODS:
        return
    validate_web_origin(event)
    supplied = (_request_headers(event).get("x-csrf-token") or "").strip()
    expected = str(session_row.get("csrf_token") or "")
    if not supplied or not expected or not secrets.compare_digest(supplied, expected):
        raise SessionAuthError(403, "CSRF_VALIDATION_FAILED", "The security token for this request is missing or invalid.")


def session_cookie(token, max_age):
    return f"{WEB_SESSION_COOKIE}={token}; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age={int(max_age)}"


def session_cookie_for_result(session_result):
    remaining = max(0, int((session_result["expires_at"] - _utcnow()).total_seconds()))
    return session_cookie(session_result["token"], remaining)


def clear_session_cookie():
    return f"{WEB_SESSION_COOKIE}=; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=0"


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


def create_org_user_session(connection, username, login_source="login", client_platform=None):
    normalized_username = normalize_email_address(username)
    if not normalized_username:
        raise ValueError("username is required")

    normalized_source = normalize_login_source(login_source)
    token = secrets.token_urlsafe(48)
    csrf_token = secrets.token_urlsafe(32)
    now = _utcnow()
    expires_at = now + timedelta(days=_session_ttl_days())
    revoke_active_sessions_for_username(
        connection,
        normalized_username,
        reason="replaced_by_new_login",
    )

    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            INSERT INTO org_user_sessions (
                username,
                token_hash,
                login_source,
                created_at,
                last_seen_at,
                expires_at,
                csrf_token,
                client_platform
            )
            VALUES (
                %(username)s,
                %(token_hash)s,
                %(login_source)s,
                %(created_at)s,
                %(last_seen_at)s,
                %(expires_at)s,
                %(csrf_token)s,
                %(client_platform)s
            )
            """,
            {
                "username": normalized_username,
                "token_hash": _token_hash(token),
                "login_source": normalized_source,
                "created_at": now,
                "last_seen_at": now,
                "expires_at": expires_at,
                "csrf_token": csrf_token,
                "client_platform": (
                    client_platform if normalized_source == "mobile_app" and client_platform in ("ios", "android") else None
                ),
            },
        )

    connection.commit()
    return {"token": token, "csrf_token": csrf_token, "expires_at": expires_at}


def get_active_session_for_username(connection, username, login_source=None):
    normalized_username = normalize_email_address(username)
    if not normalized_username:
        return None

    source_clause = ""
    query_params = {
        "username": normalized_username,
        "now": _utcnow(),
    }
    if login_source:
        source_clause = "AND login_source = %(login_source)s"
        query_params["login_source"] = normalize_login_source(login_source)

    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            SELECT
                id,
                username,
                login_source,
                csrf_token,
                created_at,
                last_seen_at,
                expires_at
            FROM org_user_sessions
            WHERE LOWER(username) = LOWER(%(username)s)
              {source_clause}
              AND revoked_at IS NULL
              AND expires_at > %(now)s
            ORDER BY id DESC
            LIMIT 1
            """,
            query_params,
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
                expires_at,
                login_source,
                csrf_token,
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
    token, credential_type = session_credentials_from_event(event)
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

    if session_row["expires_at"] <= _utcnow():
        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE org_user_sessions
                SET revoked_at = COALESCE(revoked_at, %(revoked_at)s),
                    revoked_reason = COALESCE(revoked_reason, 'expired')
                WHERE id = %(session_id)s
                """,
                {"session_id": session_row["id"], "revoked_at": _utcnow()},
            )
        connection.commit()
        raise SessionAuthError(401, "SESSION_EXPIRED", "Your session has expired. Please sign in again.")

    login_source = normalize_login_source(session_row.get("login_source"))
    if credential_type == "cookie" and login_source != "web_app":
        raise SessionAuthError(401, "SESSION_TRANSPORT_MISMATCH", "This native session cannot be used as a browser cookie.")
    if credential_type == "bearer" and login_source == "web_app":
        raise SessionAuthError(401, "SESSION_TRANSPORT_MISMATCH", "Browser sessions must use the secure session cookie.")
    if credential_type == "cookie":
        _validate_cookie_csrf(event, session_row)

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
        "login_source": login_source,
        "credential_type": credential_type,
        "csrf_token": session_row.get("csrf_token"),
        "expires_at": session_row.get("expires_at"),
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
                o.enabled_sports,
                u.enabled_sports_web,
                u.enabled_sports_ios,
                platform.enabled_sports_web AS platform_enabled_sports_web,
                platform.enabled_sports_ios AS platform_enabled_sports_ios,
                o.organization_name,
                to_jsonb(u) AS user_json
            FROM "SkwshOrgUsers" AS u
            LEFT JOIN "SkwshOrgSettings" AS o
                ON o.id = u.organization_id
            LEFT JOIN platform_settings AS platform
                ON platform.id = 'default'
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


def authorize_organization_session(
    connection,
    event,
    organization_id,
    require_admin=False,
    allow_root_admin=False,
    required_capability=None,
):
    if allow_root_admin:
        from common.root_admin_session_logic import find_root_admin_session

        root_admin_session = find_root_admin_session(connection, event)
        if root_admin_session:
            return {
                "root_admin_session": root_admin_session,
                "membership": None,
            }

    session = require_org_user_session(connection, event)
    membership_row = _get_membership_row(connection, session["username"], organization_id)

    if not membership_row:
        raise SessionAuthError(403, "SESSION_FORBIDDEN", "You do not have access to this organisation.")

    membership = _serialize_org_user(membership_row, client_type=session.get("login_source"))
    if membership["status"] != USER_STATUS_APPROVED:
        raise SessionAuthError(403, "SESSION_FORBIDDEN", "Your organisation access is not approved.")

    if require_admin and membership["role"] != "admin" and membership["organization_type"] != "personal":
        raise SessionAuthError(403, "SESSION_ADMIN_REQUIRED", "Administrator access is required for this action.")
    if required_capability and not membership_has_capability(membership, required_capability):
        raise SessionAuthError(
            403,
            "SESSION_CAPABILITY_REQUIRED",
            "Your club role does not allow this action.",
            {"capability": required_capability},
        )

    return {
        "session": session,
        "membership": membership,
    }


def authorize_personal_profile_session(connection, event, organization_id):
    auth_context = authorize_organization_session(connection, event, organization_id, require_admin=False)
    return auth_context


def _get_match_access_context(connection, match_id):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT tenant_id, sport, status, scoring_owner_membership_id, scoring_locked_at
            FROM matches
            WHERE id = %(match_id)s
            LIMIT 1
            """,
            {"match_id": match_id},
        )
        row = cursor.fetchone()

    return row


def _record_match_scorer_lock(
    connection,
    match_id,
    tenant_id,
    previous_membership_id,
    new_membership_id,
    action,
):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO match_scorer_lock_audit (
                match_id,
                tenant_id,
                previous_membership_id,
                new_membership_id,
                action,
                created_at
            ) VALUES (
                %(match_id)s,
                %(tenant_id)s,
                %(previous_membership_id)s,
                %(new_membership_id)s,
                %(action)s,
                %(created_at)s
            )
            """,
            {
                "match_id": match_id,
                "tenant_id": int(tenant_id),
                "previous_membership_id": previous_membership_id,
                "new_membership_id": int(new_membership_id),
                "action": action,
                "created_at": _utcnow(),
            },
        )


def _claim_unowned_club_match(connection, match_id, tenant_id, membership_id, action="claimed"):
    now = _utcnow()
    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE matches
            SET scoring_owner_membership_id = %(membership_id)s,
                scoring_locked_at = %(locked_at)s
            WHERE id = %(match_id)s
              AND tenant_id = %(tenant_id)s
              AND scoring_owner_membership_id IS NULL
              AND status IN ('active', 'scheduled')
            RETURNING scoring_owner_membership_id, scoring_locked_at
            """,
            {
                "match_id": match_id,
                "tenant_id": int(tenant_id),
                "membership_id": int(membership_id),
                "locked_at": now,
            },
        )
        claimed = cursor.fetchone()
    if claimed:
        _record_match_scorer_lock(
            connection,
            match_id,
            tenant_id,
            None,
            membership_id,
            action,
        )
    return claimed


def _match_scoring_access(match_context, membership):
    membership_id = (membership or {}).get("id")
    owner_id = (match_context or {}).get("scoring_owner_membership_id")
    is_personal = (membership or {}).get("organization_type") == "personal"
    is_admin = normalize_membership_role((membership or {}).get("role")) == ROLE_ADMIN
    is_owner = bool(owner_id and membership_id and int(owner_id) == int(membership_id))
    locked = bool(owner_id) and not is_personal
    can_score = is_personal or not locked or is_owner
    return {
        "locked": locked,
        "is_owner": is_owner,
        "can_score": can_score,
        "can_take_over": bool(is_admin and locked and not is_owner),
    }


def attach_match_scoring_access(match, auth_context):
    if match is not None:
        match["scoring_access"] = dict((auth_context or {}).get("scoring_access") or {})
    return match


def assign_match_scoring_owner(connection, match_id, auth_context, action="started"):
    membership = (auth_context or {}).get("membership") or {}
    if membership.get("organization_type") == "personal":
        auth_context["scoring_access"] = _match_scoring_access({}, membership)
        return False
    match_context = _get_match_access_context(connection, match_id)
    if not match_context:
        raise SessionAuthError(404, "MATCH_NOT_FOUND", "Match not found")
    claimed = _claim_unowned_club_match(
        connection,
        match_id,
        match_context["tenant_id"],
        membership["id"],
        action=action,
    )
    if claimed:
        connection.commit()
        match_context = _get_match_access_context(connection, match_id)
    auth_context["scoring_access"] = _match_scoring_access(match_context, membership)
    return bool(claimed)


def take_over_match_scoring(connection, match_id, auth_context):
    membership = (auth_context or {}).get("membership") or {}
    if membership.get("organization_type") != "club" or normalize_membership_role(membership.get("role")) != ROLE_ADMIN:
        raise SessionAuthError(
            403,
            "SESSION_ADMIN_REQUIRED",
            "A club administrator is required to take over match scoring.",
        )
    now = _utcnow()
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT tenant_id, status, scoring_owner_membership_id
            FROM matches
            WHERE id = %(match_id)s
              AND COALESCE(is_archived, false) = false
            FOR UPDATE
            """,
            {"match_id": match_id},
        )
        match_context = cursor.fetchone()
        if not match_context:
            raise SessionAuthError(404, "MATCH_NOT_FOUND", "Match not found")
        if int(match_context["tenant_id"]) != int(membership["organization_id"]):
            raise SessionAuthError(403, "SESSION_FORBIDDEN", "You do not have access to this match.")
        if match_context.get("status") == "completed":
            raise SessionAuthError(409, "MATCH_ALREADY_COMPLETE", "A completed match cannot be taken over.")
        previous_membership_id = match_context.get("scoring_owner_membership_id")
        cursor.execute(
            """
            UPDATE matches
            SET scoring_owner_membership_id = %(membership_id)s,
                scoring_locked_at = %(locked_at)s
            WHERE id = %(match_id)s
            """,
            {
                "match_id": match_id,
                "membership_id": int(membership["id"]),
                "locked_at": now,
            },
        )
    if previous_membership_id != membership["id"]:
        _record_match_scorer_lock(
            connection,
            match_id,
            match_context["tenant_id"],
            previous_membership_id,
            membership["id"],
            "admin_takeover",
        )
    connection.commit()
    refreshed = _get_match_access_context(connection, match_id)
    auth_context["scoring_access"] = _match_scoring_access(refreshed, membership)
    return auth_context["scoring_access"]


def authorize_match_session(connection, event, match_id, required_capability=CAPABILITY_MATCH_READ):
    match_context = _get_match_access_context(connection, match_id)
    if not match_context:
        raise SessionAuthError(404, "MATCH_NOT_FOUND", "Match not found")

    tenant_id = match_context["tenant_id"]
    auth_context = authorize_organization_session(
        connection,
        event,
        tenant_id,
        require_admin=False,
        required_capability=required_capability,
    )
    sport = str(match_context.get("sport") or "squash").strip().lower()
    if sport not in auth_context["membership"].get("enabled_sports", []):
        raise SessionAuthError(
            403,
            "SPORT_CLIENT_ACCESS_DENIED",
            "This racket sport is not enabled for your account on this client.",
        )
    if required_capability == CAPABILITY_MATCH_MANAGE:
        membership = auth_context["membership"]
        if membership.get("organization_type") == "club" and not match_context.get("scoring_owner_membership_id"):
            _claim_unowned_club_match(
                connection,
                match_id,
                tenant_id,
                membership["id"],
                action="claimed",
            )
            match_context = _get_match_access_context(connection, match_id)
        scoring_access = _match_scoring_access(match_context, membership)
        if not scoring_access["can_score"]:
            raise SessionAuthError(
                409,
                "MATCH_SCORER_LOCKED",
                (
                    "Another club scorer controls this match. Take over scoring before making changes."
                    if scoring_access["can_take_over"]
                    else "This match is currently controlled by another club scorer."
                ),
                {"can_take_over": scoring_access["can_take_over"]},
            )
        auth_context["scoring_access"] = scoring_access
    else:
        auth_context["scoring_access"] = _match_scoring_access(match_context, auth_context["membership"])
    auth_context["tenant_id"] = tenant_id
    auth_context["sport"] = sport
    return auth_context
