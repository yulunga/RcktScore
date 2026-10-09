import re
import random
import secrets
from datetime import date, datetime, timezone
from uuid import UUID

from psycopg.types.json import Jsonb


VALID_SPORTS = {"squash", "racketball", "tennis", "padel"}
VALID_DRAW_FORMATS = {"knockout", "knockout_plate", "round_robin", "monrad"}
VALID_STATUSES = {"draft", "registration", "draw_published", "in_progress", "completed", "cancelled"}
VALID_AUDIENCES = {"internal", "open"}
ABILITY_GRADES = {1: "A", 2: "B", 3: "C", 4: "D"}
EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
PUBLIC_DRAW_KEY_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
PUBLIC_DRAW_KEY_LENGTH = 12


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


def _serialize_event(row, entries=None, draws=None):
    return {
        "id": str(row["id"]),
        "organization_id": row["organization_id"],
        "name": row.get("name") or "",
        "sport": row.get("sport") or "squash",
        "draw_format": row.get("draw_format") or "knockout",
        "audience": row.get("audience") or "internal",
        "graded_enabled": bool(row.get("graded_enabled")),
        "draw_size_limit": row.get("draw_size_limit"),
        "status": row.get("status") or "draft",
        "venue_name": row.get("venue_name") or "",
        "starts_on": _iso(row.get("starts_on")),
        "ends_on": _iso(row.get("ends_on")),
        "scoring_config": row.get("scoring_config") or {},
        "format_config": row.get("format_config") or {},
        "revision": int(row.get("revision") or 1),
        "public_draw_key": row.get("public_draw_key") or "",
        "public_draw_enabled": bool(row.get("public_draw_enabled")),
        "draw_published_at": _iso(row.get("draw_published_at")),
        "created_by_username": row.get("created_by_username") or "",
        "created_at": _iso(row.get("created_at")),
        "updated_at": _iso(row.get("updated_at")),
        "entry_count": int(row.get("entry_count") or len(entries or [])),
        **({"entries": entries} if entries is not None else {}),
        **({"draws": draws} if draws is not None else {}),
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
        "ability_level": row.get("ability_level"),
        "ability_grade": ABILITY_GRADES.get(row.get("ability_level")),
        "status": row.get("entry_status") or "registered",
        "created_at": _iso(row.get("created_at")),
    }


def _default_draw_groups(event):
    grades = ("A", "B", "C", "D") if event.get("graded_enabled") else (None,)
    return [{
        "id": None,
        "name": f"Grade {grade}" if grade else "Open Draw",
        "grade": grade,
        "status": "draft",
    } for grade in grades]


def _serialize_draw_match(row):
    return {
        "id": str(row["id"]),
        "round_number": int(row.get("round_number") or 1),
        "match_number": int(row.get("match_number") or 1),
        "status": row.get("status") or "pending",
        "player1_entry_id": str(row["player1_entry_id"]) if row.get("player1_entry_id") else None,
        "player2_entry_id": str(row["player2_entry_id"]) if row.get("player2_entry_id") else None,
        "winner_entry_id": str(row["winner_entry_id"]) if row.get("winner_entry_id") else None,
        "player1_name": row.get("player1_name") or "",
        "player2_name": row.get("player2_name") or "",
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
    audience = (payload.get("audience") or "internal").strip().lower()
    graded_enabled = bool(payload.get("graded_enabled", False))
    draw_size_limit = payload.get("draw_size_limit")
    starts_on = _parse_date(payload.get("starts_on"), "starts_on")
    ends_on = _parse_date(payload.get("ends_on"), "ends_on")
    if not name:
        raise ValueError("Tournament name is required")
    if sport not in VALID_SPORTS:
        raise ValueError("sport must be squash, racketball, tennis or padel")
    if draw_format not in VALID_DRAW_FORMATS:
        raise ValueError("Unsupported draw format")
    if audience not in VALID_AUDIENCES:
        raise ValueError("audience must be internal or open")
    if draw_size_limit not in (None, ""):
        try:
            draw_size_limit = int(draw_size_limit)
        except (TypeError, ValueError) as exc:
            raise ValueError("draw_size_limit must be at least 2") from exc
        if draw_size_limit < 2:
            raise ValueError("draw_size_limit must be at least 2")
    else:
        draw_size_limit = None
    if starts_on and ends_on and ends_on < starts_on:
        raise ValueError("ends_on cannot be before starts_on")

    now = _utcnow()
    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO tournament_events (
                organization_id, name, sport, draw_format, audience,
                graded_enabled, draw_size_limit, status, venue_name,
                starts_on, ends_on, scoring_config, format_config,
                created_by_username, created_at, updated_at
            )
            VALUES (
                %(organization_id)s, %(name)s, %(sport)s, %(draw_format)s,
                %(audience)s, %(graded_enabled)s, %(draw_size_limit)s,
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
                "audience": audience,
                "graded_enabled": graded_enabled,
                "draw_size_limit": draw_size_limit,
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
        draw_grades = ("A", "B", "C", "D") if graded_enabled else (None,)
        for grade in draw_grades:
            cursor.execute(
                """
                INSERT INTO tournament_draws (
                    tournament_id, name, grade, status, created_at, updated_at
                )
                VALUES (
                    %(tournament_id)s, %(name)s, %(grade)s, 'draft', %(created_at)s, %(updated_at)s
                )
                """,
                {
                    "tournament_id": row["id"],
                    "name": f"Grade {grade}" if grade else "Open Draw",
                    "grade": grade,
                    "created_at": now,
                    "updated_at": now,
                },
            )
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
                "payload": Jsonb({
                    "name": name,
                    "sport": sport,
                    "draw_format": draw_format,
                    "audience": audience,
                    "graded_enabled": graded_enabled,
                    "draw_size_limit": draw_size_limit,
                }),
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
        cursor.execute(
            """
            SELECT to_regclass('public.tournament_draws') AS draw_table,
                   to_regclass('public.tournament_matches') AS match_table
            """
        )
        draw_tables = cursor.fetchone() or {}
        if draw_tables.get("draw_table"):
            cursor.execute(
                """
                SELECT id, name, grade, status
                FROM tournament_draws
                WHERE tournament_id = %(tournament_id)s
                ORDER BY grade ASC NULLS FIRST, name ASC
                """,
                {"tournament_id": row["id"]},
            )
            draws = []
            for draw in cursor.fetchall():
                matches = []
                if draw_tables.get("match_table"):
                    cursor.execute(
                        """
                        SELECT fixture.*,
                               CONCAT_WS(' ', player1.first_name_snapshot, player1.surname_snapshot) AS player1_name,
                               CONCAT_WS(' ', player2.first_name_snapshot, player2.surname_snapshot) AS player2_name
                        FROM tournament_matches AS fixture
                        LEFT JOIN tournament_entries AS player1 ON player1.id = fixture.player1_entry_id
                        LEFT JOIN tournament_entries AS player2 ON player2.id = fixture.player2_entry_id
                        WHERE fixture.draw_id = %(draw_id)s
                        ORDER BY fixture.round_number, fixture.match_number
                        """,
                        {"draw_id": draw["id"]},
                    )
                    matches = [_serialize_draw_match(match) for match in cursor.fetchall()]
                draws.append({
                    "id": str(draw["id"]),
                    "name": draw.get("name") or "Draw",
                    "grade": draw.get("grade"),
                    "status": draw.get("status") or "draft",
                    "matches": matches,
                })
        else:
            # Keep reads available during a staggered backend/schema deployment.
            # Migration 032 remains required before creating or editing draw data.
            draws = _default_draw_groups(row)
    return _serialize_event(row, entries=entries, draws=draws)


def _knockout_pairings(entries):
    if not entries:
        return []
    if len(entries) == 1:
        return [(entries[0], None)]
    bracket_size = 1
    while bracket_size < len(entries):
        bracket_size *= 2
    bye_count = bracket_size - len(entries)
    pairings = [(entry, None) for entry in entries[:bye_count]]
    remaining = entries[bye_count:]
    pairings.extend((remaining[index], remaining[index + 1]) for index in range(0, len(remaining), 2))
    return pairings


def _seed_order(bracket_size):
    order = [1, 2]
    while len(order) < bracket_size:
        complement = len(order) * 2 + 1
        order = [value for seed in order for value in (seed, complement - seed)]
    return order[:bracket_size]


def _seeded_knockout_pairings(entries, randomizer):
    if not entries:
        return []
    if len(entries) == 1:
        return [(entries[0], None)]

    bracket_size = 1
    while bracket_size < len(entries):
        bracket_size *= 2
    slots = [None] * bracket_size
    position_by_seed = {seed: index for index, seed in enumerate(_seed_order(bracket_size))}
    placed_ids = set()
    for entry in sorted(entries, key=lambda item: item.get("seed") or bracket_size + 1):
        seed = entry.get("seed")
        if seed and seed in position_by_seed and seed <= bracket_size:
            slots[position_by_seed[seed]] = entry
            placed_ids.add(str(entry["id"]))

    remaining = [entry for entry in entries if str(entry["id"]) not in placed_ids]
    randomizer.shuffle(remaining)
    bye_count = bracket_size - len(entries)
    reserved_byes = set()
    seeded_positions = sorted(
        (entry.get("seed"), index)
        for index, entry in enumerate(slots)
        if entry and entry.get("seed")
    )
    for _seed, index in seeded_positions:
        opponent_index = index ^ 1
        if bye_count and slots[opponent_index] is None:
            reserved_byes.add(opponent_index)
            bye_count -= 1

    available_slots = [
        index for index, entry in enumerate(slots)
        if entry is None and index not in reserved_byes
    ]
    for index, entry in zip(available_slots, remaining):
        slots[index] = entry
    remaining = remaining[len(available_slots):]
    for index, entry in zip(sorted(reserved_byes), remaining):
        slots[index] = entry

    return [(slots[index], slots[index + 1]) for index in range(0, bracket_size, 2)]


def _round_robin_pairings(entries):
    rotation = list(entries)
    if len(rotation) % 2:
        rotation.append(None)
    rounds = []
    for round_index in range(len(rotation) - 1):
        matches = []
        for index in range(len(rotation) // 2):
            player1 = rotation[index]
            player2 = rotation[-(index + 1)]
            if player1 is not None and player2 is not None:
                matches.append((player1, player2))
        rounds.append(matches)
        rotation = [rotation[0], rotation[-1], *rotation[1:-1]]
    return rounds


def generate_tournament_draw(connection, tournament_id, organization_id, actor_username):
    event = _fetch_event(connection, tournament_id, organization_id)
    if not event:
        raise LookupError("Tournament not found")
    if event["status"] not in {"draft", "registration", "draw_published"}:
        raise ValueError("The draw has already been generated")

    rebuilding_missing_draw = event["status"] == "draw_published"
    rebuilt_public_key = None
    if rebuilding_missing_draw:
        with connection.cursor() as cursor:
            cursor.execute("SELECT to_regclass('public.tournament_matches') AS table_name")
            match_table = cursor.fetchone() or {}
            if not match_table.get("table_name"):
                raise ValueError("Tournament draw storage is not installed. Apply migration 034 before rebuilding the draw")
            cursor.execute(
                """
                SELECT COUNT(*) AS match_count
                FROM tournament_matches AS fixture
                INNER JOIN tournament_draws AS draw ON draw.id = fixture.draw_id
                WHERE draw.tournament_id = %(event_id)s
                """,
                {"event_id": event["id"]},
            )
            existing_match_count = int((cursor.fetchone() or {}).get("match_count") or 0)
        if existing_match_count:
            return get_tournament(connection, event["id"], organization_id)
        rebuilt_public_key = event.get("public_draw_key") or _generate_public_draw_key(connection)

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT entry.id, entry.seed, entry.ability_level,
                   entry.first_name_snapshot, entry.surname_snapshot
            FROM tournament_entries AS entry
            WHERE entry.event_id = %(event_id)s
              AND entry.entry_status <> 'withdrawn'
            ORDER BY entry.seed ASC NULLS LAST, LOWER(entry.first_name_snapshot), LOWER(entry.surname_snapshot)
            """,
            {"event_id": event["id"]},
        )
        entries = cursor.fetchall()
        if len(entries) < 2:
            raise ValueError("Add at least two players before generating the draw")

        cursor.execute(
            "SELECT id, name, grade FROM tournament_draws WHERE tournament_id = %(event_id)s ORDER BY grade NULLS FIRST",
            {"event_id": event["id"]},
        )
        draws = cursor.fetchall()
        now = _utcnow()
        generated_match_count = 0
        for draw in draws:
            draw_entries = [
                entry for entry in entries
                if not draw.get("grade") or ABILITY_GRADES.get(entry.get("ability_level")) == draw["grade"]
            ]
            seeded = [entry for entry in draw_entries if entry.get("seed")]
            unseeded = [entry for entry in draw_entries if not entry.get("seed")]
            randomizer = random.Random(f"{event['id']}:{draw['id']}:{event.get('revision') or 1}")
            randomizer.shuffle(unseeded)
            ordered_entries = seeded + unseeded
            cursor.execute("DELETE FROM tournament_matches WHERE draw_id = %(draw_id)s", {"draw_id": draw["id"]})

            if event["draw_format"] == "round_robin":
                rounds = _round_robin_pairings(ordered_entries)
            else:
                rounds = [_seeded_knockout_pairings(draw_entries, randomizer)]

            for round_index, pairings in enumerate(rounds, start=1):
                for match_index, (player1, player2) in enumerate(pairings, start=1):
                    winner_id = player1["id"] if player1 and not player2 else None
                    cursor.execute(
                        """
                        INSERT INTO tournament_matches (
                            draw_id, round_number, match_number,
                            player1_entry_id, player2_entry_id, winner_entry_id,
                            status, created_at, updated_at
                        )
                        VALUES (
                            %(draw_id)s, %(round_number)s, %(match_number)s,
                            %(player1_id)s, %(player2_id)s, %(winner_id)s,
                            %(status)s, %(created_at)s, %(updated_at)s
                        )
                        """,
                        {
                            "draw_id": draw["id"],
                            "round_number": round_index,
                            "match_number": match_index,
                            "player1_id": player1["id"] if player1 else None,
                            "player2_id": player2["id"] if player2 else None,
                            "winner_id": winner_id,
                            "status": "bye" if winner_id else "pending",
                            "created_at": now,
                            "updated_at": now,
                        },
                    )
                    generated_match_count += 1
            cursor.execute(
                """
                UPDATE tournament_draws
                SET status = %(status)s, updated_at = %(updated_at)s
                WHERE id = %(draw_id)s
                """,
                {
                    "status": "published" if rebuilding_missing_draw and ordered_entries else "draft",
                    "updated_at": now,
                    "draw_id": draw["id"],
                },
            )

        if generated_match_count == 0:
            raise ValueError("No grade contains enough players to generate a fixture")
        cursor.execute(
            """
            UPDATE tournament_events
            SET status = %(status)s,
                public_draw_key = COALESCE(%(public_draw_key)s, public_draw_key),
                public_draw_enabled = %(public_draw_enabled)s,
                draw_published_at = CASE WHEN %(status)s = 'draw_published' THEN %(updated_at)s ELSE draw_published_at END,
                revision = revision + 1,
                updated_at = %(updated_at)s
            WHERE id = %(event_id)s
            """,
            {
                "status": "draw_published" if rebuilding_missing_draw else "draft",
                "public_draw_key": rebuilt_public_key,
                "public_draw_enabled": rebuilding_missing_draw,
                "updated_at": now,
                "event_id": event["id"],
            },
        )
        cursor.execute(
            """
            INSERT INTO tournament_audit_events (
                organization_id, tournament_id, actor_username, action,
                entity_type, entity_id, payload, created_at
            )
            VALUES (
                %(organization_id)s, %(tournament_id)s, %(actor_username)s,
                %(action)s, 'tournament', %(entity_id)s, %(payload)s, %(created_at)s
            )
            """,
            {
                "organization_id": int(organization_id),
                "tournament_id": event["id"],
                "actor_username": actor_username,
                "action": "draw_rebuilt" if rebuilding_missing_draw else "draw_generated",
                "entity_id": str(event["id"]),
                "payload": Jsonb({"format": event["draw_format"], "match_count": generated_match_count}),
                "created_at": now,
            },
        )
    connection.commit()
    return get_tournament(connection, event["id"], organization_id)


def _generate_public_draw_key(connection):
    for _ in range(20):
        key = "".join(secrets.choice(PUBLIC_DRAW_KEY_ALPHABET) for _ in range(PUBLIC_DRAW_KEY_LENGTH))
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT id FROM tournament_events WHERE public_draw_key = %(key)s LIMIT 1",
                {"key": key},
            )
            if not cursor.fetchone():
                return key
    raise ValueError("Unable to create a unique public draw key right now")


def publish_tournament_draw(connection, tournament_id, organization_id, actor_username):
    event = _fetch_event(connection, tournament_id, organization_id)
    if not event:
        raise LookupError("Tournament not found")
    if event["status"] not in {"draft", "registration", "draw_published"}:
        raise ValueError("This draw cannot be published")
    enabling_legacy_public_access = event["status"] == "draw_published"
    if enabling_legacy_public_access and event.get("public_draw_key") and event.get("public_draw_enabled"):
        return get_tournament(connection, event["id"], organization_id)

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT COUNT(*) AS match_count
            FROM tournament_matches AS fixture
            INNER JOIN tournament_draws AS draw ON draw.id = fixture.draw_id
            WHERE draw.tournament_id = %(event_id)s
            """,
            {"event_id": event["id"]},
        )
        if int((cursor.fetchone() or {}).get("match_count") or 0) == 0:
            raise ValueError("Generate and review the draft draw before publishing")

        public_draw_key = event.get("public_draw_key") or _generate_public_draw_key(connection)
        now = _utcnow()
        cursor.execute(
            """
            UPDATE tournament_events
            SET status = 'draw_published', public_draw_key = %(public_draw_key)s,
                public_draw_enabled = TRUE, draw_published_at = %(published_at)s,
                revision = revision + 1, updated_at = %(published_at)s
            WHERE id = %(event_id)s
            """,
            {"public_draw_key": public_draw_key, "published_at": now, "event_id": event["id"]},
        )
        cursor.execute(
            "UPDATE tournament_draws SET status = 'published', updated_at = %(updated_at)s WHERE tournament_id = %(event_id)s",
            {"updated_at": now, "event_id": event["id"]},
        )
        cursor.execute(
            """
            INSERT INTO tournament_audit_events (
                organization_id, tournament_id, actor_username, action,
                entity_type, entity_id, payload, created_at
            ) VALUES (
                %(organization_id)s, %(event_id)s, %(actor_username)s, %(action)s,
                'tournament', %(entity_id)s, %(payload)s, %(created_at)s
            )
            """,
            {
                "organization_id": int(organization_id),
                "event_id": event["id"],
                "actor_username": actor_username,
                "action": "draw_public_access_enabled" if enabling_legacy_public_access else "draw_published",
                "entity_id": str(event["id"]),
                "payload": Jsonb({"public_draw_key": public_draw_key}),
                "created_at": now,
            },
        )
    connection.commit()
    return get_tournament(connection, event["id"], organization_id)


def return_tournament_draw_to_draft(connection, tournament_id, organization_id, actor_username):
    event = _fetch_event(connection, tournament_id, organization_id)
    if not event:
        raise LookupError("Tournament not found")
    if event["status"] != "draw_published":
        raise ValueError("Only a published draw can be returned to draft")

    now = _utcnow()
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT COUNT(*) AS result_count
            FROM tournament_matches AS fixture
            INNER JOIN tournament_draws AS draw ON draw.id = fixture.draw_id
            WHERE draw.tournament_id = %(event_id)s
              AND fixture.status IN ('in_progress', 'completed', 'walkover')
            """,
            {"event_id": event["id"]},
        )
        if int((cursor.fetchone() or {}).get("result_count") or 0):
            raise ValueError("A draw with started or completed matches cannot be returned to draft")
        cursor.execute(
            """
            UPDATE tournament_events
            SET status = 'draft', public_draw_enabled = FALSE,
                revision = revision + 1, updated_at = %(updated_at)s
            WHERE id = %(event_id)s
            """,
            {"updated_at": now, "event_id": event["id"]},
        )
        cursor.execute(
            "UPDATE tournament_draws SET status = 'draft', updated_at = %(updated_at)s WHERE tournament_id = %(event_id)s",
            {"updated_at": now, "event_id": event["id"]},
        )
        cursor.execute(
            """
            INSERT INTO tournament_audit_events (
                organization_id, tournament_id, actor_username, action,
                entity_type, entity_id, payload, created_at
            ) VALUES (
                %(organization_id)s, %(event_id)s, %(actor_username)s, 'draw_returned_to_draft',
                'tournament', %(entity_id)s, '{}'::jsonb, %(created_at)s
            )
            """,
            {
                "organization_id": int(organization_id),
                "event_id": event["id"],
                "actor_username": actor_username,
                "entity_id": str(event["id"]),
                "created_at": now,
            },
        )
    connection.commit()
    return get_tournament(connection, event["id"], organization_id)


def update_tournament_draw_slot(connection, tournament_id, match_id, organization_id, payload, actor_username):
    event = _fetch_event(connection, tournament_id, organization_id)
    if not event:
        raise LookupError("Tournament not found")
    if event["status"] not in {"draft", "registration"}:
        raise ValueError("Return the draw to draft before moving players")
    slot = payload.get("slot")
    if slot not in {"player1", "player2"}:
        raise ValueError("slot must be player1 or player2")
    entry_id = _uuid(payload.get("entry_id"), "entry_id")
    target_column = f"{slot}_entry_id"

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT fixture.*, draw.grade
            FROM tournament_matches AS fixture
            INNER JOIN tournament_draws AS draw ON draw.id = fixture.draw_id
            WHERE fixture.id = %(match_id)s
              AND fixture.round_number = 1
              AND draw.tournament_id = %(event_id)s
            LIMIT 1
            """,
            {"match_id": _uuid(match_id, "match_id"), "event_id": event["id"]},
        )
        target = cursor.fetchone()
        if not target:
            raise LookupError("Draft draw match not found")
        cursor.execute(
            """
            SELECT id, ability_level
            FROM tournament_entries
            WHERE id = %(entry_id)s AND event_id = %(event_id)s AND entry_status <> 'withdrawn'
            LIMIT 1
            """,
            {"entry_id": entry_id, "event_id": event["id"]},
        )
        entry = cursor.fetchone()
        if not entry:
            raise ValueError("The selected player is not an active tournament entry")
        if target.get("grade") and ABILITY_GRADES.get(entry.get("ability_level")) != target["grade"]:
            raise ValueError("Players can only be moved within their grade draw")

        current_target_entry = target.get(target_column)
        cursor.execute(
            """
            SELECT id, player1_entry_id, player2_entry_id
            FROM tournament_matches
            WHERE draw_id = %(draw_id)s AND round_number = 1
              AND (player1_entry_id = %(entry_id)s OR player2_entry_id = %(entry_id)s)
            LIMIT 1
            """,
            {"draw_id": target["draw_id"], "entry_id": entry_id},
        )
        source = cursor.fetchone()
        if not source:
            raise ValueError("The selected player is not in this draft draw")
        source_column = "player1_entry_id" if str(source.get("player1_entry_id")) == entry_id else "player2_entry_id"
        if str(source["id"]) != str(target["id"]) or source_column != target_column:
            cursor.execute(
                f"UPDATE tournament_matches SET {source_column} = %(replacement_id)s, winner_entry_id = NULL, status = 'pending', updated_at = %(updated_at)s WHERE id = %(source_id)s",
                {"replacement_id": current_target_entry, "updated_at": _utcnow(), "source_id": source["id"]},
            )
            cursor.execute(
                f"UPDATE tournament_matches SET {target_column} = %(entry_id)s, winner_entry_id = NULL, status = 'pending', updated_at = %(updated_at)s WHERE id = %(target_id)s",
                {"entry_id": entry_id, "updated_at": _utcnow(), "target_id": target["id"]},
            )
            cursor.execute(
                """
                UPDATE tournament_matches
                SET status = CASE
                        WHEN player1_entry_id IS NULL OR player2_entry_id IS NULL THEN 'bye'
                        ELSE 'pending'
                    END,
                    winner_entry_id = CASE
                        WHEN player1_entry_id IS NULL THEN player2_entry_id
                        WHEN player2_entry_id IS NULL THEN player1_entry_id
                        ELSE NULL
                    END,
                    updated_at = %(updated_at)s
                WHERE draw_id = %(draw_id)s AND round_number = 1
                """,
                {"updated_at": _utcnow(), "draw_id": target["draw_id"]},
            )
        cursor.execute(
            """
            INSERT INTO tournament_audit_events (
                organization_id, tournament_id, actor_username, action,
                entity_type, entity_id, payload, created_at
            ) VALUES (
                %(organization_id)s, %(event_id)s, %(actor_username)s, 'draw_player_moved',
                'draw_match', %(entity_id)s, %(payload)s, %(created_at)s
            )
            """,
            {
                "organization_id": int(organization_id),
                "event_id": event["id"],
                "actor_username": actor_username,
                "entity_id": str(target["id"]),
                "payload": Jsonb({"slot": slot, "entry_id": entry_id}),
                "created_at": _utcnow(),
            },
        )
    connection.commit()
    return get_tournament(connection, event["id"], organization_id)


def get_public_tournament_draw(connection, access_key):
    normalized_key = "".join(character for character in str(access_key or "").upper() if character.isalnum())
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id, organization_id
            FROM tournament_events
            WHERE public_draw_key = %(access_key)s
              AND public_draw_enabled = TRUE
              AND status = 'draw_published'
            LIMIT 1
            """,
            {"access_key": normalized_key},
        )
        event = cursor.fetchone()
    if not event:
        return None
    tournament = get_tournament(connection, event["id"], event["organization_id"])
    return {
        "id": tournament["id"],
        "name": tournament["name"],
        "sport": tournament["sport"],
        "draw_format": tournament["draw_format"],
        "audience": tournament["audience"],
        "graded_enabled": tournament["graded_enabled"],
        "status": tournament["status"],
        "venue_name": tournament["venue_name"],
        "starts_on": tournament["starts_on"],
        "ends_on": tournament["ends_on"],
        "entries": [{
            "id": entry["id"],
            "display_name": entry["display_name"],
            "seed": entry["seed"],
            "ability_grade": entry["ability_grade"],
        } for entry in tournament.get("entries", [])],
        "draws": tournament.get("draws", []),
    }


def _find_or_create_player(connection, organization_id, payload):
    player_id = payload.get("player_id")
    if player_id:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT * FROM players WHERE id = %(player_id)s LIMIT 1",
                {"player_id": _uuid(player_id, "player_id")},
            )
            player = cursor.fetchone()
        if not player:
            raise ValueError("Selected player was not found")
        return player

    first_name = (payload.get("first_name") or "").strip()
    surname = (payload.get("surname") or "").strip()
    email = _normalize_email(payload.get("email"))
    if not first_name:
        raise ValueError("Player first name is required")
    if not surname:
        raise ValueError("Player surname is required")
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
    ability_level = payload.get("ability_level")
    try:
        ability_level = int(ability_level)
    except (TypeError, ValueError) as exc:
        raise ValueError("Select a player ability level from 1 to 4") from exc
    if ability_level not in ABILITY_GRADES:
        raise ValueError("Select a player ability level from 1 to 4")
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
        if (event.get("audience") or "internal") == "internal" and relationship != "member":
            raise ValueError("Internal tournaments can only include members of the host club")
        if event.get("draw_size_limit"):
            cursor.execute(
                """
                SELECT COUNT(*) AS entry_count
                FROM tournament_entries
                WHERE event_id = %(event_id)s
                  AND entry_status <> 'withdrawn'
                """,
                {"event_id": event["id"]},
            )
            if int((cursor.fetchone() or {}).get("entry_count") or 0) >= int(event["draw_size_limit"]):
                raise ValueError("This tournament has reached its draw size limit")
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
                    event_id, player_id, seed, ability_level, entry_status,
                    first_name_snapshot, surname_snapshot, club_snapshot,
                    country_snapshot, created_at, updated_at
                )
                VALUES (
                    %(event_id)s, %(player_id)s, %(seed)s, %(ability_level)s, 'registered',
                    %(first_name)s, %(surname)s, %(club)s, %(country)s,
                    %(created_at)s, %(updated_at)s
                )
                RETURNING *
                """,
                {
                    "event_id": event["id"],
                    "player_id": player["id"],
                    "seed": seed,
                    "ability_level": ability_level,
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
                "payload": Jsonb({
                    "player_id": str(player["id"]),
                    "relationship": relationship,
                    "seed": seed,
                    "ability_level": ability_level,
                    "ability_grade": ABILITY_GRADES[ability_level],
                }),
                "created_at": now,
            },
        )
    connection.commit()
    return get_tournament(connection, event["id"], organization_id)


def update_tournament_entry(connection, tournament_id, entry_id, organization_id, payload, actor_username):
    event = _fetch_event(connection, tournament_id, organization_id)
    if not event:
        raise LookupError("Tournament not found")
    if event["status"] not in {"draft", "registration"}:
        raise ValueError("Entries can only be changed before the draw is published")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT entry.*, player.user_id, player.registered_username,
                   player.email, player.first_name AS player_first_name,
                   player.surname AS player_surname,
                   player.home_club_name
            FROM tournament_entries AS entry
            INNER JOIN players AS player ON player.id = entry.player_id
            WHERE entry.id = %(entry_id)s
              AND entry.event_id = %(event_id)s
            LIMIT 1
            """,
            {"entry_id": _uuid(entry_id, "entry_id"), "event_id": event["id"]},
        )
        entry = cursor.fetchone()
        if not entry:
            raise LookupError("Tournament entry not found")

        first_name = (payload.get("first_name", entry["first_name_snapshot"]) or "").strip()
        surname = (payload.get("surname", entry["surname_snapshot"]) or "").strip()
        if not first_name or not surname:
            raise ValueError("Player first name and surname are required")

        ability_level = payload.get("ability_level", entry.get("ability_level"))
        try:
            ability_level = int(ability_level)
        except (TypeError, ValueError) as exc:
            raise ValueError("Select a player ability level from 1 to 4") from exc
        if ability_level not in ABILITY_GRADES:
            raise ValueError("Select a player ability level from 1 to 4")
        seed = payload.get("seed", entry.get("seed"))
        if seed in (None, ""):
            seed = None
        else:
            try:
                seed = int(seed)
            except (TypeError, ValueError) as exc:
                raise ValueError("Seed must be a positive whole number") from exc
            if seed < 1:
                raise ValueError("Seed must be a positive whole number")
            cursor.execute(
                """
                SELECT id
                FROM tournament_entries
                WHERE event_id = %(event_id)s AND seed = %(seed)s
                  AND id <> %(entry_id)s AND entry_status <> 'withdrawn'
                LIMIT 1
                """,
                {"event_id": event["id"], "seed": seed, "entry_id": entry["id"]},
            )
            if cursor.fetchone():
                raise ValueError(f"Seed {seed} is already assigned to another player")

        linked_account = bool(entry.get("user_id") or entry.get("registered_username"))
        current_email = _normalize_email(entry.get("email"))
        next_email = _normalize_email(payload.get("email", current_email))
        next_club = (payload.get("home_club_name", entry.get("club_snapshot")) or "").strip() or None
        if next_email and not EMAIL_PATTERN.match(next_email):
            raise ValueError("Player email address is invalid")
        if linked_account and (next_email != current_email or next_club != (entry.get("club_snapshot") or None)):
            raise ValueError("Email and home club cannot be changed for a player linked to an existing HitNScore account")

        registered_username = entry.get("registered_username")
        user_id = entry.get("user_id")
        if not linked_account and next_email:
            cursor.execute(
                """
                SELECT id, email
                FROM "users"
                WHERE email_normalized = LOWER(%(email)s)
                LIMIT 1
                """,
                {"email": next_email},
            )
            identity = cursor.fetchone()
            if identity:
                user_id = identity["id"]
                registered_username = identity["email"]

            cursor.execute(
                """
                SELECT id
                FROM players
                WHERE id <> %(player_id)s
                  AND (
                    LOWER(email) = LOWER(%(email)s)
                    OR LOWER(registered_username) = LOWER(%(email)s)
                    OR (%(user_id)s IS NOT NULL AND user_id = %(user_id)s)
                  )
                LIMIT 1
                """,
                {"player_id": entry["player_id"], "email": next_email, "user_id": user_id},
            )
            if cursor.fetchone():
                raise ValueError("That email already belongs to another player. Add the existing player from search instead")

        relationship = "guest"
        if registered_username or next_email:
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
                    "username": registered_username or next_email,
                },
            )
            relationship = "member" if cursor.fetchone() else "guest"
        if (event.get("audience") or "internal") == "internal" and relationship != "member":
            raise ValueError("Internal tournaments can only include members of the host club")

        now = _utcnow()
        if not linked_account:
            cursor.execute(
                """
                UPDATE players
                SET user_id = %(user_id)s,
                    registered_username = %(registered_username)s,
                    email = %(email)s,
                    first_name = %(first_name)s,
                    surname = %(surname)s,
                    normalized_name = %(normalized_name)s,
                    home_club_name = %(home_club_name)s,
                    claim_status = %(claim_status)s,
                    claimed_at = CASE WHEN %(user_id)s IS NOT NULL THEN COALESCE(claimed_at, %(updated_at)s) ELSE NULL END,
                    updated_at = %(updated_at)s
                WHERE id = %(player_id)s
                """,
                {
                    "user_id": user_id,
                    "registered_username": registered_username,
                    "email": next_email,
                    "first_name": first_name,
                    "surname": surname,
                    "normalized_name": _normalize_name(first_name, surname),
                    "home_club_name": next_club,
                    "claim_status": "linked" if user_id else ("claimable" if next_email else "unclaimed"),
                    "updated_at": now,
                    "player_id": entry["player_id"],
                },
            )

        cursor.execute(
            """
            UPDATE tournament_entries
            SET first_name_snapshot = %(first_name)s,
                surname_snapshot = %(surname)s,
                club_snapshot = %(club)s,
                ability_level = %(ability_level)s,
                seed = %(seed)s,
                updated_at = %(updated_at)s
            WHERE id = %(entry_id)s
            """,
            {
                "first_name": first_name,
                "surname": surname,
                "club": next_club,
                "ability_level": ability_level,
                "seed": seed,
                "updated_at": now,
                "entry_id": entry["id"],
            },
        )
        cursor.execute(
            """
            INSERT INTO player_organization_affiliations (
                player_id, organization_id, relationship, created_at, updated_at
            )
            VALUES (%(player_id)s, %(organization_id)s, %(relationship)s, %(created_at)s, %(updated_at)s)
            ON CONFLICT (player_id, organization_id) DO UPDATE
            SET relationship = EXCLUDED.relationship, updated_at = EXCLUDED.updated_at
            """,
            {
                "player_id": entry["player_id"],
                "organization_id": int(organization_id),
                "relationship": relationship,
                "created_at": now,
                "updated_at": now,
            },
        )
        cursor.execute(
            """
            INSERT INTO tournament_audit_events (
                organization_id, tournament_id, actor_username, action,
                entity_type, entity_id, payload, created_at
            )
            VALUES (
                %(organization_id)s, %(tournament_id)s, %(actor_username)s,
                'entry_updated', 'entry', %(entity_id)s, %(payload)s, %(created_at)s
            )
            """,
            {
                "organization_id": int(organization_id),
                "tournament_id": event["id"],
                "actor_username": actor_username,
                "entity_id": str(entry["id"]),
                "payload": Jsonb({"ability_level": ability_level, "relationship": relationship, "seed": seed}),
                "created_at": now,
            },
        )
    connection.commit()
    return get_tournament(connection, event["id"], organization_id)


def search_tournament_players(connection, organization_id, query):
    search = " ".join((query or "").strip().split())
    if len(search) < 2:
        return []
    pattern = f"%{search}%"
    prefix = f"{search}%"
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT *
            FROM (
                SELECT
                    player.id AS player_id,
                    player.user_id,
                    player.first_name,
                    player.surname,
                    COALESCE(player.email, player.registered_username, identity.email) AS email,
                    player.home_club_name,
                    player.claim_status,
                    CASE WHEN membership.id IS NULL THEN 'guest' ELSE 'member' END AS relationship
                FROM players AS player
                LEFT JOIN "users" AS identity ON identity.id = player.user_id
                LEFT JOIN "SkwshOrgUsers" AS membership
                    ON membership.organization_id = %(organization_id)s
                   AND COALESCE(membership.approval_status, 'approved') = 'approved'
                   AND (
                        membership.user_id = player.user_id
                        OR LOWER(membership.clubusername) = LOWER(
                            COALESCE(player.registered_username, player.email, identity.email)
                        )
                   )
                WHERE player.normalized_name ILIKE %(pattern)s
                   OR COALESCE(player.email, '') ILIKE %(pattern)s
                   OR COALESCE(player.registered_username, '') ILIKE %(pattern)s

                UNION ALL

                SELECT
                    NULL::uuid AS player_id,
                    identity.id AS user_id,
                    identity.first_name,
                    identity.surname,
                    identity.email,
                    host.organization_name AS home_club_name,
                    'linked' AS claim_status,
                    CASE WHEN membership.id IS NULL THEN 'guest' ELSE 'member' END AS relationship
                FROM "users" AS identity
                LEFT JOIN "SkwshOrgUsers" AS membership
                    ON membership.user_id = identity.id
                   AND membership.organization_id = %(organization_id)s
                   AND COALESCE(membership.approval_status, 'approved') = 'approved'
                LEFT JOIN "SkwshOrgSettings" AS host ON host.id = membership.organization_id
                WHERE NOT EXISTS (SELECT 1 FROM players WHERE players.user_id = identity.id)
                  AND (
                    CONCAT_WS(' ', identity.first_name, identity.surname) ILIKE %(pattern)s
                    OR identity.email ILIKE %(pattern)s
                  )
            ) AS candidate
            ORDER BY
                CASE
                    WHEN LOWER(COALESCE(email, '')) = LOWER(%(search)s)
                      OR LOWER(CONCAT_WS(' ', first_name, surname)) = LOWER(%(search)s)
                    THEN 0
                    WHEN LOWER(COALESCE(email, '')) LIKE LOWER(%(prefix)s)
                      OR LOWER(COALESCE(first_name, '')) LIKE LOWER(%(prefix)s)
                      OR LOWER(COALESCE(surname, '')) LIKE LOWER(%(prefix)s)
                      OR LOWER(CONCAT_WS(' ', first_name, surname)) LIKE LOWER(%(prefix)s)
                    THEN 1
                    ELSE 2
                END,
                relationship DESC,
                LENGTH(CONCAT_WS(' ', first_name, surname)),
                LOWER(first_name), LOWER(surname), LOWER(email)
            LIMIT 20
            """,
            {
                "organization_id": int(organization_id),
                "pattern": pattern,
                "prefix": prefix,
                "search": search,
            },
        )
        rows = cursor.fetchall()
    return [{
        "player_id": str(row["player_id"]) if row.get("player_id") else None,
        "user_id": str(row["user_id"]) if row.get("user_id") else None,
        "first_name": row.get("first_name") or "",
        "surname": row.get("surname") or "",
        "display_name": " ".join(part for part in [row.get("first_name") or "", row.get("surname") or ""] if part),
        "email": row.get("email") or "",
        "home_club_name": row.get("home_club_name") or "",
        "claim_status": row.get("claim_status") or "unclaimed",
        "relationship": row.get("relationship") or "guest",
    } for row in rows]
