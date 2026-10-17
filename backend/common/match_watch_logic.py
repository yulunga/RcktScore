import secrets

from common.match_logic import get_match


WATCH_CODE_LENGTH = 8
WATCH_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


class MatchWatchError(Exception):
    def __init__(self, status_code, code, message):
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message


def normalize_watch_code(value):
    return "".join(character for character in str(value or "").upper() if character.isalnum())


def ensure_personal_plus(membership):
    if (membership or {}).get("organization_type") != "personal":
        raise MatchWatchError(403, "PERSONAL_PLUS_REQUIRED", "Remote match viewing requires a Personal Plus account.")
    if (membership or {}).get("plan") != "personal_plus":
        raise MatchWatchError(403, "PERSONAL_PLUS_REQUIRED", "Upgrade to Personal Plus to watch matches remotely.")


def _generate_watch_code():
    return "".join(secrets.choice(WATCH_CODE_ALPHABET) for _ in range(WATCH_CODE_LENGTH))


def ensure_match_watch_code(connection, match_id):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT viewer_code
            FROM matches
            WHERE id = %(match_id)s
              AND COALESCE(is_archived, false) = false
            LIMIT 1
            """,
            {"match_id": match_id},
        )
        row = cursor.fetchone()

    if not row:
        return None
    if row.get("viewer_code"):
        return row["viewer_code"]

    for _ in range(20):
        code = _generate_watch_code()
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT 1 FROM matches WHERE UPPER(viewer_code) = %(viewer_code)s LIMIT 1",
                {"viewer_code": code},
            )
            if cursor.fetchone():
                continue
            cursor.execute(
                """
                UPDATE matches
                SET viewer_code = %(viewer_code)s
                WHERE id = %(match_id)s
                  AND viewer_code IS NULL
                RETURNING viewer_code
                """,
                {"match_id": match_id, "viewer_code": code},
            )
            updated = cursor.fetchone()
        connection.commit()
        if updated:
            return updated["viewer_code"]

        with connection.cursor() as cursor:
            cursor.execute("SELECT viewer_code FROM matches WHERE id = %(match_id)s", {"match_id": match_id})
            existing = cursor.fetchone()
        if existing and existing.get("viewer_code"):
            return existing["viewer_code"]

    raise MatchWatchError(503, "WATCH_CODE_UNAVAILABLE", "Unable to create a match viewing code right now.")


def _match_id_for_code(connection, code):
    normalized = normalize_watch_code(code)
    if len(normalized) != WATCH_CODE_LENGTH:
        raise MatchWatchError(400, "WATCH_CODE_INVALID", "Enter the 8-character match viewing code.")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id
            FROM matches
            WHERE UPPER(viewer_code) = %(viewer_code)s
              AND COALESCE(is_archived, false) = false
            LIMIT 1
            """,
            {"viewer_code": normalized},
        )
        row = cursor.fetchone()
    if not row:
        raise MatchWatchError(404, "WATCH_MATCH_NOT_FOUND", "No match was found for that viewing code.")
    return row["id"], normalized


def _is_saved(connection, match_id, viewer_organization_id):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT EXISTS (
                SELECT 1
                FROM match_view_profiles
                WHERE match_id = %(match_id)s
                  AND viewer_organization_id = %(viewer_organization_id)s
            ) AS is_saved
            """,
            {"match_id": match_id, "viewer_organization_id": int(viewer_organization_id)},
        )
        return bool((cursor.fetchone() or {}).get("is_saved"))


def get_watched_match(connection, viewer_organization_id, code):
    match_id, normalized = _match_id_for_code(connection, code)
    match = get_match(connection, match_id)
    if not match:
        raise MatchWatchError(404, "WATCH_MATCH_NOT_FOUND", "No match was found for that viewing code.")
    return {
        "code": normalized,
        "saved": _is_saved(connection, match_id, viewer_organization_id),
        "finished": match.get("status") == "completed" or bool((match.get("state") or {}).get("match_complete")),
        "match": match,
    }


def save_watched_match(connection, viewer_organization_id, username, code):
    match_id, normalized = _match_id_for_code(connection, code)
    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO match_view_profiles (match_id, viewer_organization_id, added_by_username)
            VALUES (%(match_id)s, %(viewer_organization_id)s, %(username)s)
            ON CONFLICT (match_id, viewer_organization_id) DO NOTHING
            """,
            {
                "match_id": match_id,
                "viewer_organization_id": int(viewer_organization_id),
                "username": str(username or "").strip().lower(),
            },
        )
    connection.commit()
    payload = get_watched_match(connection, viewer_organization_id, normalized)
    payload["saved"] = True
    return payload


def list_saved_watched_matches(connection, viewer_organization_id, limit=100):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT matches.id,
                   matches.viewer_code,
                   matches.player1_name,
                   matches.player1_surname,
                   matches.player2_name,
                   matches.player2_surname,
                   matches.court_name,
                   matches.sport,
                   matches.status,
                   matches.best_of,
                   matches.score_type,
                   matches.updated_at,
                   matches.completed_at,
                   matches.match_duration_seconds,
                   matches.winner_name
            FROM match_view_profiles AS profiles
            JOIN matches ON matches.id = profiles.match_id
            WHERE profiles.viewer_organization_id = %(viewer_organization_id)s
              AND COALESCE(matches.is_archived, false) = false
            ORDER BY
                CASE WHEN matches.status = 'active' THEN 0 ELSE 1 END,
                COALESCE(matches.completed_at, matches.updated_at) DESC
            LIMIT %(limit)s
            """,
            {"viewer_organization_id": int(viewer_organization_id), "limit": max(0, int(limit))},
        )
        rows = cursor.fetchall() or []

    return [
        {
            **row,
            "id": str(row["id"]),
            "viewer_code": row.get("viewer_code") or "",
            "saved_to_profile": True,
            "locked": False,
        }
        for row in rows
    ]
