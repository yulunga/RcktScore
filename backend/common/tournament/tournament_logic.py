import re
from datetime import date, datetime, timezone
from uuid import UUID

from psycopg.types.json import Jsonb


VALID_SPORTS = {"squash", "racketball", "tennis", "padel"}
VALID_DRAW_FORMATS = {"knockout", "knockout_plate", "round_robin", "monrad"}
VALID_STATUSES = {"draft", "registration", "draw_published", "in_progress", "completed", "cancelled"}
EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def _utcnow():
    return datetime.now(timezone.utc)


def _iso(value):
    return value.isoformat() if value else None


def _normalize_name(first_name, surname=""):
    return " ".join(f"{first_name or ''} {surname or ''}".lower().split())


def _normalize_email(value):
    return (value or "").strip().lower() or None


def _parse_date(value, field_name):
    if value in (None, ""):
        return None
    if isinstance(value, date):
        return value
    try:
        return date.fromisoformat(str(value))
    except ValueError as exc:
        raise ValueError(f"{field_name} must use YYYY-MM-DD") from exc


def _uuid(value, field_name):
    try:
        return str(UUID(str(value)))
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{field_name} must be a valid UUID") from exc


def _serialize_event(row, entries=None):
    return {
        "id": str(row["id"]),
        "organization_id": row["organization_id"],
        "name": row.get("name") or "",
        "sport": row.get("sport") or "squash",
        "draw_format": row.get("draw_format") or "knockout",
        "status": row.get("status") or "draft",
        "venue_name": row.get("venue_name") or "",
        "starts_on": _iso(row.get("starts_on")),
        "ends_on": _iso(row.get("ends_on")),
        "scoring_config": row.get("scoring_config") or {},
        "format_config": row.get("format_config") or {},
        "revision": int(row.get("revision") or 1),
        "created_by_username": row.get("created_by_username") or "",
        "created_at": _iso(row.get("created_at")),
        "updated_at": _iso(row.get("updated_at")),
        "entry_count": int(row.get("entry_count") or len(entries or [])),
        **({"entries": entries} if entries is not None else {}),
    }


def _serialize_entry(row):
    return {
        "id": str(row["id"]),
        "player_id": str(row["player_id"]),
        "user_id": str(row["user_id"]) if row.get("user_id") else None,
        "first_name": row.get("first_name_snapshot") or "",
        "surname": row.get("surname_snapshot") or "",
        "display_name": " ".join(
            part for part in [row.get("first_name_snapshot") or "", row.get("surname_snapshot") or ""] if part
        ),
        "email": row.get("email") or "",
        "registered_username": row.get("registered_username") or "",
        "claim_status": row.get("claim_status") or "unclaimed",
        "relationship": row.get("relationship") or "guest",
        "home_club_name": row.get("club_snapshot") or "",
        "country": row.get("country_snapshot") or "",
        "seed": row.get("seed"),
        "status": row.get("entry_status") or "registered",
        "created_at": _iso(row.get("created_at")),
    }


def list_tournaments(connection, organization_id):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT event.*, COUNT(entry.id) AS entry_count
            FROM tournament_events AS event
            LEFT JOIN tournament_entries AS entry
                ON entry.event_id = event.id
               AND entry.entry_status <> 'withdrawn'
            WHERE event.organization_id = %(organization_id)s
            GROUP BY event.id
            ORDER BY event.starts_on DESC NULLS LAST, event.created_at DESC
            """,
            {"organization_id": int(organization_id)},
        )
        rows = cursor.fetchall()
    return [_serialize_event(row) for row in rows]


def create_tournament(connection, organization_id, payload, actor_username):
    name = (payload.get("name") or "").strip()
    sport = (payload.get("sport") or "").strip().lower()
    draw_format = (payload.get("draw_format") or "").strip().lower()
    starts_on = _parse_date(payload.get("starts_on"), "starts_on")
    ends_on = _parse_date(payload.get("ends_on"), "ends_on")
    if not name:
        raise ValueError("Tournament name is required")
    if sport not in VALID_SPORTS:
        raise ValueError("sport must be squash, racketball, tennis or padel")
    if draw_format not in VALID_DRAW_FORMATS:
        raise ValueError("Unsupported draw format")
    if starts_on and ends_on and ends_on < starts_on:
        raise ValueError("ends_on cannot be before starts_on")

    now = _utcnow()
    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO tournament_events (
                organization_id, name, sport, draw_format, status, venue_name,
                starts_on, ends_on, scoring_config, format_config,
                created_by_username, created_at, updated_at
            )
            VALUES (
                %(organization_id)s, %(name)s, %(sport)s, %(draw_format)s,
                'draft', %(venue_name)s, %(starts_on)s, %(ends_on)s,
                %(scoring_config)s, %(format_config)s, %(created_by_username)s,
                %(created_at)s, %(updated_at)s
            )
            RETURNING *
            """,
            {
                "organization_id": int(organization_id),
                "name": name,
                "sport": sport,
                "draw_format": draw_format,
                "venue_name": (payload.get("venue_name") or "").strip() or None,
                "starts_on": starts_on,
                "ends_on": ends_on,
                "scoring_config": Jsonb(payload.get("scoring_config") or {}),
                "format_config": Jsonb(payload.get("format_config") or {}),
                "created_by_username": actor_username,
                "created_at": now,
                "updated_at": now,
            },
        )
        row = cursor.fetchone()
        cursor.execute(
            """
            INSERT INTO tournament_role_assignments (event_id, username, role, created_at)
            VALUES (%(event_id)s, %(username)s, 'organizer', %(created_at)s)
            ON CONFLICT (event_id, username, role) DO NOTHING
            """,
            {"event_id": row["id"], "username": actor_username, "created_at": now},
        )
        cursor.execute(
            """
            INSERT INTO tournament_audit_events (
                organization_id, tournament_id, actor_username, action,
                entity_type, entity_id, payload, created_at
            )
            VALUES (
                %(organization_id)s, %(tournament_id)s, %(actor_username)s,
                'created', 'tournament', %(entity_id)s, %(payload)s, %(created_at)s
            )
            """,
            {
                "organization_id": int(organization_id),
                "tournament_id": row["id"],
                "actor_username": actor_username,
                "entity_id": str(row["id"]),
                "payload": Jsonb({"name": name, "sport": sport, "draw_format": draw_format}),
                "created_at": now,
            },
        )
    connection.commit()
    return _serialize_event(row)


def _fetch_event(connection, tournament_id, organization_id):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT *
            FROM tournament_events
            WHERE id = %(tournament_id)s
              AND organization_id = %(organization_id)s
            LIMIT 1
            """,
            {
                "tournament_id": _uuid(tournament_id, "tournament_id"),
                "organization_id": int(organization_id),
            },
        )
        return cursor.fetchone()


def get_tournament(connection, tournament_id, organization_id):
    row = _fetch_event(connection, tournament_id, organization_id)
    if not row:
        return None
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                entry.*,
                player.user_id,
                player.email,
                player.registered_username,
                player.claim_status,
                affiliation.relationship
            FROM tournament_entries AS entry
            INNER JOIN players AS player ON player.id = entry.player_id
            LEFT JOIN player_organization_affiliations AS affiliation
                ON affiliation.player_id = player.id
               AND affiliation.organization_id = %(organization_id)s
            WHERE entry.event_id = %(tournament_id)s
            ORDER BY entry.seed ASC NULLS LAST,
                     LOWER(entry.first_name_snapshot),
                     LOWER(entry.surname_snapshot),
                     entry.created_at ASC
            """,
            {"tournament_id": row["id"], "organization_id": int(organization_id)},
        )
        entries = [_serialize_entry(entry) for entry in cursor.fetchall()]
    return _serialize_event(row, entries=entries)


def _find_or_create_player(connection, organization_id, payload):
    first_name = (payload.get("first_name") or "").strip()
    surname = (payload.get("surname") or "").strip()
    email = _normalize_email(payload.get("email"))
    if not first_name:
        raise ValueError("Player first name is required")
    if email and not EMAIL_PATTERN.match(email):
        raise ValueError("Player email address is invalid")

    registered_username = None
    user_id = None
    if email:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT identity.id, identity.email
                FROM "users" AS identity
                WHERE identity.email_normalized = LOWER(%(email)s)
                LIMIT 1
                """,
                {"email": email},
            )
            registered_row = cursor.fetchone()
        user_id = (registered_row or {}).get("id")
        registered_username = (registered_row or {}).get("email")

    existing = None
    if email:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT *
                FROM players
                WHERE LOWER(email) = LOWER(%(email)s)
                   OR LOWER(registered_username) = LOWER(%(email)s)
                ORDER BY created_at ASC
                LIMIT 1
                """,
                {"email": email},
            )
            existing = cursor.fetchone()

    now = _utcnow()
    if existing:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE players
                SET user_id = COALESCE(user_id, %(user_id)s),
                    registered_username = COALESCE(registered_username, %(registered_username)s),
                    email = COALESCE(email, %(email)s),
                    first_name = %(first_name)s,
                    surname = %(surname)s,
                    normalized_name = %(normalized_name)s,
                    country = COALESCE(%(country)s, country),
                    home_club_name = COALESCE(%(home_club_name)s, home_club_name),
                    claim_status = CASE
                        WHEN COALESCE(registered_username, %(registered_username)s) IS NOT NULL THEN 'linked'
                        WHEN COALESCE(email, %(email)s) IS NOT NULL THEN 'claimable'
                        ELSE 'unclaimed'
                    END,
                    updated_at = %(updated_at)s,
                    claimed_at = CASE
                        WHEN COALESCE(registered_username, %(registered_username)s) IS NOT NULL
                        THEN COALESCE(claimed_at, %(updated_at)s)
                        ELSE claimed_at
                    END
                WHERE id = %(player_id)s
                RETURNING *
                """,
                {
                    "registered_username": registered_username,
                    "user_id": user_id,
                    "email": email,
                    "first_name": first_name,
                    "surname": surname,
                    "normalized_name": _normalize_name(first_name, surname),
                    "country": (payload.get("country") or "").strip() or None,
                    "home_club_name": (payload.get("home_club_name") or "").strip() or None,
                    "updated_at": now,
                    "player_id": existing["id"],
                },
            )
            return cursor.fetchone()

    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO players (
                user_id, registered_username, email, first_name, surname, normalized_name,
                country, home_club_name, claim_status, created_by_organization_id,
                created_at, updated_at, claimed_at
            )
            VALUES (
                %(user_id)s, %(registered_username)s, %(email)s, %(first_name)s, %(surname)s,
                %(normalized_name)s, %(country)s, %(home_club_name)s,
                %(claim_status)s, %(organization_id)s, %(created_at)s,
                %(updated_at)s, %(claimed_at)s
            )
            RETURNING *
            """,
            {
                "registered_username": registered_username,
                "user_id": user_id,
                "email": email,
                "first_name": first_name,
                "surname": surname,
                "normalized_name": _normalize_name(first_name, surname),
                "country": (payload.get("country") or "").strip() or None,
                "home_club_name": (payload.get("home_club_name") or "").strip() or None,
                "claim_status": "linked" if registered_username else ("claimable" if email else "unclaimed"),
                "organization_id": int(organization_id),
                "created_at": now,
                "updated_at": now,
                "claimed_at": now if registered_username else None,
            },
        )
        return cursor.fetchone()


def add_tournament_entry(connection, tournament_id, organization_id, payload, actor_username):
    event = _fetch_event(connection, tournament_id, organization_id)
    if not event:
        raise LookupError("Tournament not found")
    if event["status"] not in {"draft", "registration"}:
        raise ValueError("Entries can only be changed before the draw is published")

    player = _find_or_create_player(connection, organization_id, payload)
    seed = payload.get("seed")
    if seed not in (None, ""):
        try:
            seed = int(seed)
        except (TypeError, ValueError) as exc:
            raise ValueError("seed must be a positive number") from exc
        if seed < 1:
            raise ValueError("seed must be a positive number")
    else:
        seed = None

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT 1
            FROM "SkwshOrgUsers"
            WHERE organization_id = %(organization_id)s
              AND LOWER(clubusername) = LOWER(%(username)s)
              AND COALESCE(approval_status, 'approved') = 'approved'
            LIMIT 1
            """,
            {
                "organization_id": int(organization_id),
                "username": player.get("registered_username") or player.get("email") or "",
            },
        )
        relationship = "member" if cursor.fetchone() else "guest"
        now = _utcnow()
        cursor.execute(
            """
            INSERT INTO player_organization_affiliations (
                player_id, organization_id, relationship, created_at, updated_at
            )
            VALUES (
                %(player_id)s, %(organization_id)s, %(relationship)s,
                %(created_at)s, %(updated_at)s
            )
            ON CONFLICT (player_id, organization_id) DO UPDATE
            SET relationship = EXCLUDED.relationship,
                updated_at = EXCLUDED.updated_at
            """,
            {
                "player_id": player["id"],
                "organization_id": int(organization_id),
                "relationship": relationship,
                "created_at": now,
                "updated_at": now,
            },
        )
        try:
            cursor.execute(
                """
                INSERT INTO tournament_entries (
                    event_id, player_id, seed, entry_status,
                    first_name_snapshot, surname_snapshot, club_snapshot,
                    country_snapshot, created_at, updated_at
                )
                VALUES (
                    %(event_id)s, %(player_id)s, %(seed)s, 'registered',
                    %(first_name)s, %(surname)s, %(club)s, %(country)s,
                    %(created_at)s, %(updated_at)s
                )
                RETURNING *
                """,
                {
                    "event_id": event["id"],
                    "player_id": player["id"],
                    "seed": seed,
                    "first_name": player["first_name"],
                    "surname": player.get("surname") or "",
                    "club": player.get("home_club_name"),
                    "country": player.get("country"),
                    "created_at": now,
                    "updated_at": now,
                },
            )
            entry = cursor.fetchone()
        except Exception as exc:
            if getattr(exc, "sqlstate", None) == "23505":
                raise ValueError("This player is already entered in the tournament") from exc
            raise
        cursor.execute(
            """
            INSERT INTO tournament_audit_events (
                organization_id, tournament_id, actor_username, action,
                entity_type, entity_id, payload, created_at
            )
            VALUES (
                %(organization_id)s, %(tournament_id)s, %(actor_username)s,
                'entry_added', 'entry', %(entity_id)s, %(payload)s, %(created_at)s
            )
            """,
            {
                "organization_id": int(organization_id),
                "tournament_id": event["id"],
                "actor_username": actor_username,
                "entity_id": str(entry["id"]),
                "payload": Jsonb({"player_id": str(player["id"]), "relationship": relationship, "seed": seed}),
                "created_at": now,
            },
        )
    connection.commit()
    return get_tournament(connection, event["id"], organization_id)
