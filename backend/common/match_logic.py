from datetime import datetime, timezone
from uuid import uuid4


ALLOWED_ACTION_TYPES = {"let", "stroke", "serve_side", "timer"}


def _utcnow():
    return datetime.now(timezone.utc)


def _event_summary(match_row, event_type, payload):
    if event_type == "match_started":
        return f"{match_row['player1_name']} vs {match_row['player2_name']} started"
    if event_type == "match_ended":
        return payload.get("note") or "Match ended"
    if event_type == "score_point":
        scorer = payload.get("scorer")
        if scorer == "player1":
            return f"{match_row['player1_name']} scored"
        if scorer == "player2":
            return f"{match_row['player2_name']} scored"
    if event_type == "let":
        return payload.get("note") or "Let called"
    if event_type == "stroke":
        player_side = payload.get("player_side")
        if player_side == "player1":
            return f"Stroke awarded to {match_row['player1_name']}"
        if player_side == "player2":
            return f"Stroke awarded to {match_row['player2_name']}"
    if event_type == "serve_side":
        return f"Serve changed to {payload.get('side', 'Right')}"
    if event_type == "timer":
        return payload.get("note") or "Timer event"
    return event_type.replace("_", " ").title()


def _serialize_event(match_row, event_row):
    payload = event_row.get("payload") or {}
    return {
        "id": event_row["id"],
        "event_type": event_row["event_type"],
        "payload": payload,
        "event_source": event_row["event_source"],
        "created_at": event_row["created_at"].isoformat(),
        "summary": _event_summary(match_row, event_row["event_type"], payload),
    }


def _build_state(match_row, event_rows):
    state = {
        "player1_score": 0,
        "player2_score": 0,
        "current_server": None,
        "service_side": "Right",
        "events": [],
    }

    for event_row in event_rows:
        payload = event_row.get("payload") or {}
        event_type = event_row["event_type"]
        state["events"].append(_serialize_event(match_row, event_row))

        if event_type == "score_point":
            scorer = payload.get("scorer")
            if scorer == "player1":
                state["player1_score"] += 1
                state["current_server"] = match_row["player1_name"]
            elif scorer == "player2":
                state["player2_score"] += 1
                state["current_server"] = match_row["player2_name"]

        elif event_type == "stroke":
            player_side = payload.get("player_side")
            if player_side == "player1":
                state["player1_score"] += 1
                state["current_server"] = match_row["player1_name"]
            elif player_side == "player2":
                state["player2_score"] += 1
                state["current_server"] = match_row["player2_name"]

        elif event_type == "serve_side":
            state["service_side"] = payload.get("side", state["service_side"])

    return state


def _serialize_match(match_row, event_rows):
    return {
        "id": match_row["id"],
        "tenant_id": match_row["tenant_id"],
        "court_id": match_row["court_id"],
        "court_name": match_row["court_name"],
        "player1_name": match_row["player1_name"],
        "player1_surname": match_row.get("player1_surname"),
        "player1_country": match_row.get("player1_country"),
        "player2_name": match_row["player2_name"],
        "player2_surname": match_row.get("player2_surname"),
        "player2_country": match_row.get("player2_country"),
        "referee_name": match_row.get("referee_name"),
        "score_type": match_row["score_type"],
        "status": match_row["status"],
        "created_at": match_row["created_at"].isoformat(),
        "updated_at": match_row["updated_at"].isoformat(),
        "state": _build_state(match_row, event_rows),
    }


def _fetch_match_row(connection, match_id):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT *
            FROM matches
            WHERE id = %(match_id)s
            LIMIT 1
            """,
            {"match_id": match_id},
        )
        return cursor.fetchone()


def _fetch_match_events(connection, match_id):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id, match_id, event_type, payload, event_source, created_at
            FROM match_events
            WHERE match_id = %(match_id)s
            ORDER BY created_at ASC, id ASC
            """,
            {"match_id": match_id},
        )
        return cursor.fetchall()


def get_match(connection, match_id):
    match_row = _fetch_match_row(connection, match_id)
    if not match_row:
        return None
    return _serialize_match(match_row, _fetch_match_events(connection, match_id))


def list_matches(connection, tenant_id, status=None, limit=10):
    query = [
        """
        SELECT *
        FROM matches
        WHERE tenant_id = %(tenant_id)s
        """
    ]
    params = {"tenant_id": tenant_id, "limit": limit}

    if status:
        query.append("AND status = %(status)s")
        params["status"] = status

    query.append("ORDER BY updated_at DESC, created_at DESC LIMIT %(limit)s")

    with connection.cursor() as cursor:
        cursor.execute("\n".join(query), params)
        match_rows = cursor.fetchall()

    return [
        _serialize_match(match_row, _fetch_match_events(connection, match_row["id"]))
        for match_row in match_rows
    ]


def create_match(connection, payload, source="api"):
    match_id = str(uuid4())
    tenant_id = payload["tenant_id"]
    now = _utcnow()

    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO matches (
                id,
                tenant_id,
                court_id,
                court_name,
                player1_name,
                player1_surname,
                player1_country,
                player2_name,
                player2_surname,
                player2_country,
                referee_name,
                score_type,
                status,
                created_at,
                updated_at
            )
            VALUES (
                %(id)s,
                %(tenant_id)s,
                %(court_id)s,
                %(court_name)s,
                %(player1_name)s,
                %(player1_surname)s,
                %(player1_country)s,
                %(player2_name)s,
                %(player2_surname)s,
                %(player2_country)s,
                %(referee_name)s,
                %(score_type)s,
                'active',
                %(created_at)s,
                %(updated_at)s
            )
            """,
            {
                "id": match_id,
                "tenant_id": tenant_id,
                "court_id": payload["court_id"],
                "court_name": payload["court_name"],
                "player1_name": payload["player1_name"],
                "player1_surname": payload.get("player1_surname"),
                "player1_country": payload.get("player1_country"),
                "player2_name": payload["player2_name"],
                "player2_surname": payload.get("player2_surname"),
                "player2_country": payload.get("player2_country"),
                "referee_name": payload.get("referee_name"),
                "score_type": int(payload.get("score_type", 15)),
                "created_at": now,
                "updated_at": now,
            },
        )

        cursor.execute(
            """
            INSERT INTO match_events (id, match_id, tenant_id, event_type, payload, event_source, created_at)
            VALUES (%(id)s, %(match_id)s, %(tenant_id)s, 'match_started', %(payload)s, %(event_source)s, %(created_at)s)
            """,
            {
                "id": str(uuid4()),
                "match_id": match_id,
                "tenant_id": tenant_id,
                "payload": {
                    "court_id": payload["court_id"],
                    "court_name": payload["court_name"],
                },
                "event_source": source,
                "created_at": now,
            },
        )

    connection.commit()
    return get_match(connection, match_id)


def _append_event(connection, match_id, event_type, payload, source="api"):
    match_row = _fetch_match_row(connection, match_id)
    if not match_row:
        return None

    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO match_events (id, match_id, tenant_id, event_type, payload, event_source, created_at)
            VALUES (%(id)s, %(match_id)s, %(tenant_id)s, %(event_type)s, %(payload)s, %(event_source)s, %(created_at)s)
            """,
            {
                "id": str(uuid4()),
                "match_id": match_id,
                "tenant_id": match_row["tenant_id"],
                "event_type": event_type,
                "payload": payload,
                "event_source": source,
                "created_at": _utcnow(),
            },
        )
        cursor.execute(
            """
            UPDATE matches
            SET updated_at = %(updated_at)s
            WHERE id = %(match_id)s
            """,
            {"updated_at": _utcnow(), "match_id": match_id},
        )

    connection.commit()
    return get_match(connection, match_id)


def score_point(connection, match_id, scorer, source="api"):
    if scorer not in {"player1", "player2"}:
        raise ValueError("scorer must be 'player1' or 'player2'")
    return _append_event(connection, match_id, "score_point", {"scorer": scorer}, source=source)


def event_action(connection, match_id, action_type, payload, source="api"):
    if action_type not in ALLOWED_ACTION_TYPES:
        raise ValueError(f"action_type must be one of: {', '.join(sorted(ALLOWED_ACTION_TYPES))}")
    return _append_event(connection, match_id, action_type, payload, source=source)


def undo_last_action(connection, match_id):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id
            FROM match_events
            WHERE match_id = %(match_id)s
              AND event_type <> 'match_started'
            ORDER BY created_at DESC, id DESC
            LIMIT 1
            """,
            {"match_id": match_id},
        )
        last_event = cursor.fetchone()
        if not last_event:
            return get_match(connection, match_id)

        cursor.execute(
            """
            DELETE FROM match_events
            WHERE id = %(event_id)s
            """,
            {"event_id": last_event["id"]},
        )
        cursor.execute(
            """
            UPDATE matches
            SET updated_at = %(updated_at)s
            WHERE id = %(match_id)s
            """,
            {"updated_at": _utcnow(), "match_id": match_id},
        )

    connection.commit()
    return get_match(connection, match_id)


def end_match(connection, match_id, source="api"):
    match_row = _fetch_match_row(connection, match_id)
    if not match_row:
        return None

    now = _utcnow()
    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO match_events (id, match_id, tenant_id, event_type, payload, event_source, created_at)
            VALUES (%(id)s, %(match_id)s, %(tenant_id)s, 'match_ended', %(payload)s, %(event_source)s, %(created_at)s)
            """,
            {
                "id": str(uuid4()),
                "match_id": match_id,
                "tenant_id": match_row["tenant_id"],
                "payload": {"status": "completed"},
                "event_source": source,
                "created_at": now,
            },
        )
        cursor.execute(
            """
            UPDATE matches
            SET status = 'completed',
                updated_at = %(updated_at)s
            WHERE id = %(match_id)s
            """,
            {"updated_at": now, "match_id": match_id},
        )

    connection.commit()
    return get_match(connection, match_id)


def websocket_payload(match):
    return {
        "type": "match.updated",
        "match": match,
    }
