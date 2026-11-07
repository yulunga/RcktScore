import hashlib
import os
import secrets
from datetime import datetime, timedelta, timezone

from common.session_logic import (
    ROOT_ADMIN_SESSION_COOKIE,
    SessionAuthError,
    _request_headers,
    _validate_cookie_csrf,
    session_credentials_from_event,
)


DEFAULT_ROOT_ADMIN_SESSION_TTL_HOURS = 8
MAX_ROOT_ADMIN_SESSION_TTL_HOURS = 24


def _utcnow():
    return datetime.now(timezone.utc)


def _token_hash(token):
    return hashlib.sha256((token or "").encode("utf-8")).hexdigest()


def _session_ttl_hours():
    configured_value = (os.getenv("ROOT_ADMIN_SESSION_TTL_HOURS") or "").strip()
    try:
        hours = int(configured_value or DEFAULT_ROOT_ADMIN_SESSION_TTL_HOURS)
    except ValueError:
        hours = DEFAULT_ROOT_ADMIN_SESSION_TTL_HOURS
    return max(1, min(hours, MAX_ROOT_ADMIN_SESSION_TTL_HOURS))


def revoke_active_root_admin_sessions(connection, root_admin_id, reason="replaced_by_new_login"):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE root_admin_sessions
            SET revoked_at = %(revoked_at)s,
                revoked_reason = %(revoked_reason)s
            WHERE root_admin_id = %(root_admin_id)s
              AND revoked_at IS NULL
            """,
            {
                "root_admin_id": int(root_admin_id),
                "revoked_at": _utcnow(),
                "revoked_reason": reason,
            },
        )


def create_root_admin_session(connection, root_admin):
    root_admin_id = root_admin.get("id")
    if root_admin_id is None:
        raise ValueError("root admin id is required")

    token = f"rra_{secrets.token_urlsafe(48)}"
    csrf_token = secrets.token_urlsafe(32)
    now = _utcnow()
    expires_at = now + timedelta(hours=_session_ttl_hours())

    # Serialize concurrent logins for the same account before replacing its session.
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id
            FROM "SkRootAdmin"
            WHERE id = %(root_admin_id)s
            FOR UPDATE
            """,
            {"root_admin_id": int(root_admin_id)},
        )

    revoke_active_root_admin_sessions(connection, root_admin_id)

    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO root_admin_sessions (
                root_admin_id,
                token_hash,
                created_at,
                expires_at,
                last_seen_at,
                csrf_token
            )
            VALUES (
                %(root_admin_id)s,
                %(token_hash)s,
                %(created_at)s,
                %(expires_at)s,
                %(last_seen_at)s,
                %(csrf_token)s
            )
            """,
            {
                "root_admin_id": int(root_admin_id),
                "token_hash": _token_hash(token),
                "created_at": now,
                "expires_at": expires_at,
                "last_seen_at": now,
                "csrf_token": csrf_token,
            },
        )

    connection.commit()
    return {
        "token": token,
        "csrf_token": csrf_token,
        "expires_at": expires_at,
    }


def _get_root_admin_session_row(connection, token):
    if not token:
        return None
    hashed = _token_hash(token)

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                session.id,
                session.root_admin_id,
                session.created_at,
                session.expires_at,
                session.last_seen_at,
                session.revoked_at,
                session.revoked_reason,
                session.csrf_token,
                admin.rtusername
            FROM root_admin_sessions AS session
            INNER JOIN "SkRootAdmin" AS admin
                ON admin.id = session.root_admin_id
            WHERE session.token_hash = %(token_hash)s
            LIMIT 1
            """,
            {"token_hash": hashed},
        )
        return cursor.fetchone()


def _validate_root_admin_session_row(connection, session_row, token, event=None):
    if session_row.get("revoked_at") is not None:
        code = (
            "ROOT_ADMIN_SESSION_REPLACED"
            if session_row.get("revoked_reason") == "replaced_by_new_login"
            else "ROOT_ADMIN_SESSION_INVALID"
        )
        message = (
            "You were signed out because this root-admin account was used to sign in elsewhere."
            if code == "ROOT_ADMIN_SESSION_REPLACED"
            else "Your root-admin session is no longer valid. Please sign in again."
        )
        raise SessionAuthError(401, code, message)

    now = _utcnow()
    if session_row["expires_at"] <= now:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE root_admin_sessions
                SET revoked_at = %(revoked_at)s,
                    revoked_reason = 'expired'
                WHERE id = %(session_id)s
                  AND revoked_at IS NULL
                """,
                {
                    "session_id": session_row["id"],
                    "revoked_at": now,
                },
            )
        connection.commit()
        raise SessionAuthError(
            401,
            "ROOT_ADMIN_SESSION_EXPIRED",
            "Your root-admin session has expired. Please sign in again.",
        )

    if event is not None:
        _validate_cookie_csrf(event, session_row)

    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE root_admin_sessions
            SET last_seen_at = %(last_seen_at)s
            WHERE id = %(session_id)s
            """,
            {
                "session_id": session_row["id"],
                "last_seen_at": now,
            },
        )
    connection.commit()

    return {
        "id": session_row["root_admin_id"],
        "username": session_row["rtusername"],
        "role": "root_admin",
        "session_id": session_row["id"],
        "token": token,
        "csrf_token": session_row.get("csrf_token"),
        "expires_at": session_row["expires_at"].isoformat(),
    }


def find_root_admin_session(connection, event):
    # Reused organisation routes can accept either an ordinary user cookie or
    # the separate Root Admin cookie. This header selects which credential the
    # caller intends to use; it grants no trust by itself.
    if (_request_headers(event).get("x-hitnscore-session") or "").strip().lower() != "root_admin":
        return None
    token, credential_type = session_credentials_from_event(event, ROOT_ADMIN_SESSION_COOKIE)
    if credential_type == "bearer":
        return None
    if not token or not token.startswith("rra_"):
        return None

    session_row = _get_root_admin_session_row(connection, token)
    if not session_row:
        return None

    return _validate_root_admin_session_row(connection, session_row, token, event=event)


def require_root_admin_session(connection, event):
    token, credential_type = session_credentials_from_event(event, ROOT_ADMIN_SESSION_COOKIE)
    if not token:
        raise SessionAuthError(401, "ROOT_ADMIN_SESSION_REQUIRED", "Please sign in as root admin to continue.")

    session_row = _get_root_admin_session_row(connection, token)
    if not session_row:
        raise SessionAuthError(
            401,
            "ROOT_ADMIN_SESSION_INVALID",
            "Your root-admin session is no longer valid. Please sign in again.",
        )

    if credential_type != "cookie":
        raise SessionAuthError(
            401,
            "ROOT_ADMIN_SESSION_TRANSPORT_MISMATCH",
            "Root Admin sessions must use the secure browser cookie.",
        )

    return _validate_root_admin_session_row(connection, session_row, token, event=event)


def root_admin_session_cookie(token, max_age):
    return f"{ROOT_ADMIN_SESSION_COOKIE}={token}; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age={int(max_age)}"


def root_admin_session_cookie_for_result(session_result):
    remaining = max(0, int((session_result["expires_at"] - _utcnow()).total_seconds()))
    return root_admin_session_cookie(session_result["token"], remaining)


def clear_root_admin_session_cookie():
    return f"{ROOT_ADMIN_SESSION_COOKIE}=; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=0"


def revoke_root_admin_session(connection, token, reason="logout"):
    if not token:
        return False

    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE root_admin_sessions
            SET revoked_at = COALESCE(revoked_at, %(revoked_at)s),
                revoked_reason = COALESCE(revoked_reason, %(revoked_reason)s)
            WHERE token_hash = %(token_hash)s
            """,
            {
                "token_hash": _token_hash(token),
                "revoked_at": _utcnow(),
                "revoked_reason": reason,
            },
        )
        updated = cursor.rowcount > 0

    connection.commit()
    return updated
