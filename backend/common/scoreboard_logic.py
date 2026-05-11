import hashlib
import secrets
from datetime import datetime, timedelta, timezone

from common.match_logic import get_active_match_for_court


DISPLAY_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
DISPLAY_CODE_LENGTH = 12
DISPLAY_SESSION_TTL_HOURS = 24


def _utcnow():
    return datetime.now(timezone.utc)


class DisplaySessionError(Exception):
    def __init__(self, status_code, code, message, details=None):
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message
        self.details = details


def normalize_display_code(value):
    return "".join(character for character in str(value or "").upper() if character.isalnum())


def _token_hash(token):
    return hashlib.sha256((token or "").encode("utf-8")).hexdigest()


def _request_headers(event):
    return {
        (key or "").lower(): value
        for key, value in (event.get("headers") or {}).items()
    }


def _session_token_from_event(event):
    headers = _request_headers(event)
    authorization = (headers.get("authorization") or "").strip()
    if authorization.lower().startswith("bearer "):
        return authorization[7:].strip()

    return (headers.get("x-session-token") or "").strip()


def _serialize_court(row, *, include_display_code=False):
    created_at = row.get("created_at")
    display_code_created_at = row.get("display_code_created_at")
    display_code_last_used_at = row.get("display_code_last_used_at")
    payload = {
        "id": row["id"],
        "tenant_id": row["organization_name"],
        "court_name": row.get("court_name") or "",
        "court_alias": row.get("court_alias") or "",
        "display_code_enabled": bool(row.get("display_code_enabled")),
        "created_at": created_at.isoformat() if created_at else None,
        "display_code_created_at": display_code_created_at.isoformat() if display_code_created_at else None,
        "display_code_last_used_at": display_code_last_used_at.isoformat() if display_code_last_used_at else None,
    }
    if include_display_code:
        payload["display_code"] = row.get("display_code") or ""
    return payload


def _court_tenant_id(row):
    if row.get("organization_name") is not None:
        return row["organization_name"]
    return row.get("tenant_id")


def generate_unique_display_code(connection):
    for _ in range(20):
        code = "".join(secrets.choice(DISPLAY_CODE_ALPHABET) for _ in range(DISPLAY_CODE_LENGTH))
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id
                FROM "SkwshCourts"
                WHERE display_code = %(display_code)s
                LIMIT 1
                """,
                {"display_code": code},
            )
            if not cursor.fetchone():
                return code

    raise ValueError("Unable to generate a unique display code right now")


def issue_court_display_code(connection, organization_id, court_id):
    tenant_id = int(organization_id)
    now = _utcnow()
    display_code = generate_unique_display_code(connection)

    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE "SkwshCourts"
            SET display_code = %(display_code)s,
                display_code_enabled = TRUE,
                display_code_created_at = %(display_code_created_at)s,
                display_code_last_used_at = NULL
            WHERE id = %(court_id)s
              AND organization_name = %(organization_id)s
            RETURNING
                id,
                organization_name,
                court_name,
                court_alias,
                created_at,
                display_code,
                display_code_enabled,
                display_code_created_at,
                display_code_last_used_at
            """,
            {
                "court_id": int(court_id),
                "organization_id": tenant_id,
                "display_code": display_code,
                "display_code_created_at": now,
            },
        )
        court_row = cursor.fetchone()

    connection.commit()
    return _serialize_court(court_row, include_display_code=True) if court_row else None


def _get_court_by_display_code(connection, display_code):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                id,
                organization_name,
                court_name,
                court_alias,
                created_at,
                display_code,
                display_code_enabled,
                display_code_created_at,
                display_code_last_used_at
            FROM "SkwshCourts"
            WHERE display_code = %(display_code)s
              AND display_code_enabled = TRUE
            LIMIT 1
            """,
            {"display_code": display_code},
        )
        return cursor.fetchone()


def _build_scoreboard_payload(connection, court_row, *, display_session_token=None):
    tenant_id = _court_tenant_id(court_row)
    court_id = court_row["id"]
    current_match = get_active_match_for_court(connection, tenant_id, court_id)
    payload = {
        "court": _serialize_court(court_row),
        "match": current_match,
        "poll_interval_seconds": 5,
        "realtime_mode": "polling_v1",
    }
    if display_session_token:
        payload["display_session_token"] = display_session_token
    return payload


def create_scoreboard_display_session(connection, code):
    normalized_code = normalize_display_code(code)
    if len(normalized_code) != DISPLAY_CODE_LENGTH:
        raise ValueError("Enter the 12-character display code.")

    court_row = _get_court_by_display_code(connection, normalized_code)
    if not court_row:
        raise DisplaySessionError(404, "DISPLAY_CODE_NOT_FOUND", "Display code not recognised.")

    token = secrets.token_urlsafe(48)
    now = _utcnow()
    expires_at = now + timedelta(hours=DISPLAY_SESSION_TTL_HOURS)

    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO court_display_sessions (
                tenant_id,
                court_id,
                token_hash,
                created_at,
                expires_at,
                last_seen_at
            )
            VALUES (
                %(tenant_id)s,
                %(court_id)s,
                %(token_hash)s,
                %(created_at)s,
                %(expires_at)s,
                %(last_seen_at)s
            )
            """,
            {
                "tenant_id": court_row["organization_name"],
                "court_id": court_row["id"],
                "token_hash": _token_hash(token),
                "created_at": now,
                "expires_at": expires_at,
                "last_seen_at": now,
            },
        )
        cursor.execute(
            """
            UPDATE "SkwshCourts"
            SET display_code_last_used_at = %(last_used_at)s
            WHERE id = %(court_id)s
            """,
            {
                "court_id": court_row["id"],
                "last_used_at": now,
            },
        )

    connection.commit()
    return _build_scoreboard_payload(connection, court_row, display_session_token=token)


def require_scoreboard_display_session(connection, event):
    token = _session_token_from_event(event)
    if not token:
        raise DisplaySessionError(401, "DISPLAY_SESSION_REQUIRED", "Display session is required.")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                session.id AS session_id,
                session.tenant_id,
                session.court_id,
                session.expires_at,
                session.revoked_at,
                court.organization_name,
                court.court_name,
                court.court_alias,
                court.created_at,
                court.display_code_enabled,
                court.display_code_created_at,
                court.display_code_last_used_at
            FROM court_display_sessions AS session
            INNER JOIN "SkwshCourts" AS court
                ON court.id = session.court_id
            WHERE session.token_hash = %(token_hash)s
            LIMIT 1
            """,
            {"token_hash": _token_hash(token)},
        )
        row = cursor.fetchone()

    if not row or row.get("revoked_at") is not None:
        raise DisplaySessionError(401, "DISPLAY_SESSION_INVALID", "Display session is no longer valid.")

    now = _utcnow()
    if row["expires_at"] <= now:
        raise DisplaySessionError(401, "DISPLAY_SESSION_EXPIRED", "Display session has expired.")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE court_display_sessions
            SET last_seen_at = %(last_seen_at)s
            WHERE id = %(session_id)s
            """,
            {
                "session_id": row["session_id"],
                "last_seen_at": now,
            },
        )
        cursor.execute(
            """
            UPDATE "SkwshCourts"
            SET display_code_last_used_at = %(last_used_at)s
            WHERE id = %(court_id)s
            """,
            {
                "court_id": row["court_id"],
                "last_used_at": now,
            },
        )

    connection.commit()
    return {
        "tenant_id": row["tenant_id"],
        "court": {
            "id": row["court_id"],
            "organization_name": row["organization_name"],
            "court_name": row["court_name"],
            "court_alias": row.get("court_alias"),
            "created_at": row.get("created_at"),
            "display_code_enabled": row.get("display_code_enabled"),
            "display_code_created_at": row.get("display_code_created_at"),
            "display_code_last_used_at": row.get("display_code_last_used_at"),
        },
    }


def get_scoreboard_display_current(connection, event):
    session_context = require_scoreboard_display_session(connection, event)
    return _build_scoreboard_payload(connection, session_context["court"])
