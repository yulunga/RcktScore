from datetime import datetime, timezone
from uuid import uuid4

from psycopg.types.json import Jsonb


ALLOWED_ACTION_TYPES = {"let", "stroke", "server", "serve_side", "timer"}
VALID_BEST_OF_OPTIONS = {1, 3, 5}
VALID_MATCH_STATUSES = {"active", "scheduled", "completed"}


def _utcnow():
    return datetime.now(timezone.utc)


def _coerce_int(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _best_of_value(value):
    parsed = _coerce_int(value, default=1)
    return parsed if parsed in VALID_BEST_OF_OPTIONS else 1


def _match_status_value(value):
    parsed = str(value or "active").strip().lower()
    return parsed if parsed in VALID_MATCH_STATUSES else "active"


def _games_to_win(best_of):
    return (_best_of_value(best_of) // 2) + 1


def _player_name(match_like, side):
    if side == "player1":
        return match_like["player1_name"]
    if side == "player2":
        return match_like["player2_name"]
    return None


def _is_left_handed(match_like, side):
    handedness = str(match_like.get(f"{side}_handedness") or "").strip().lower()
    return handedness == "left"


def _service_side_for_receiver(match_like, current_server_side):
    receiver_side = "player2" if current_server_side == "player1" else "player1"
    return "Left" if _is_left_handed(match_like, receiver_side) else "Right"


def _opposite_service_side(side):
    return "Left" if str(side or "Right").strip().lower() == "right" else "Right"


def _next_service_side_after_point(match_like, previous_server_side, previous_service_side, scorer_side):
    if scorer_side == previous_server_side:
        return _opposite_service_side(previous_service_side)

    return _service_side_for_receiver(match_like, scorer_side)


def _initial_scores(match_like):
    if match_like.get("handicap_enabled"):
        return (
            _coerce_int(match_like.get("player1_offset")),
            _coerce_int(match_like.get("player2_offset")),
        )
    return (0, 0)


def _is_game_complete(player1_score, player2_score, target):
    highest_score = max(player1_score, player2_score)
    lowest_score = min(player1_score, player2_score)

    if highest_score < target:
        return False
    if lowest_score <= target - 2 and highest_score == target:
        return True
    return highest_score - lowest_score >= 2


def _winner_from_scores(match_like, player1_score, player2_score):
    if player1_score > player2_score:
        return ("player1", match_like["player1_name"])
    if player2_score > player1_score:
        return ("player2", match_like["player2_name"])
    return ("draw", "Draw")


def _match_leader(match_like, state):
    if state["player1_games_won"] > state["player2_games_won"]:
        return ("player1", match_like["player1_name"])
    if state["player2_games_won"] > state["player1_games_won"]:
        return ("player2", match_like["player2_name"])
    return _winner_from_scores(match_like, state["player1_score"], state["player2_score"])


def _event_summary(match_row, event_type, payload):
    if event_type == "match_started":
        return (
            f"{match_row['player1_name']} vs {match_row['player2_name']} started "
            f"(best of {payload.get('best_of', 1)})"
        )
    if event_type == "match_ended":
        if payload.get("ended_early"):
            return payload.get("reason") or "Match ended early"
        if payload.get("winner_name"):
            return f"{payload['winner_name']} won the match"
        return payload.get("note") or "Match ended"
    if event_type == "score_point":
        scorer = payload.get("scorer")
        scorer_name = _player_name(match_row, scorer)
        if payload.get("match_completed") and scorer_name:
            return f"{scorer_name} won the match"
        if payload.get("game_result") and scorer_name:
            return f"{scorer_name} won game {payload['game_result']['game_number']}"
        if scorer_name:
            return f"{scorer_name} scored"
    if event_type == "let":
        return payload.get("note") or "Let called"
    if event_type == "stroke":
        scorer_name = _player_name(match_row, payload.get("player_side"))
        if payload.get("match_completed") and scorer_name:
            return f"Stroke awarded to {scorer_name} to win the match"
        if payload.get("game_result") and scorer_name:
            return f"Stroke awarded to {scorer_name} to win game {payload['game_result']['game_number']}"
        if scorer_name:
            return f"Stroke awarded to {scorer_name}"
    if event_type == "serve_side":
        return f"Serve changed to {payload.get('side', 'Right')}"
    if event_type == "server":
        server_side = payload.get("current_server_side")
        if server_side == "player2":
            return f"{match_row['player2_name']} selected to serve first"
        return f"{match_row['player1_name']} selected to serve first"
    if event_type == "timer":
        return payload.get("note") or "Timer event"
    return event_type.replace("_", " ").title()


def _serialize_event(match_row, event_row):
    payload = event_row.get("payload") or {}
    return {
        "id": str(event_row["id"]),
        "event_type": event_row["event_type"],
        "payload": payload,
        "event_source": event_row["event_source"],
        "created_at": event_row["created_at"].isoformat(),
        "summary": _event_summary(match_row, event_row["event_type"], payload),
    }


def _initial_state(match_row):
    best_of = _best_of_value(match_row.get("best_of", 1))
    player1_score, player2_score = _initial_scores(match_row)
    return {
        "player1_score": player1_score,
        "player2_score": player2_score,
        "player1_games_won": _coerce_int(match_row.get("player1_games_won")),
        "player2_games_won": _coerce_int(match_row.get("player2_games_won")),
        "current_game_number": _coerce_int(match_row.get("current_game_number"), 1),
        "best_of": best_of,
        "games_to_win": _coerce_int(match_row.get("games_to_win"), _games_to_win(best_of)),
        "current_server": match_row["player1_name"],
        "current_server_side": "player1",
        "service_side": _service_side_for_receiver(match_row, "player1"),
        "handicap": {
            "enabled": bool(match_row.get("handicap_enabled")),
            "player1_band": match_row.get("player1_band"),
            "player2_band": match_row.get("player2_band"),
            "player1_offset": _coerce_int(match_row.get("player1_offset")),
            "player2_offset": _coerce_int(match_row.get("player2_offset")),
        },
        "game_history": [],
        "match_complete": match_row.get("status") == "completed",
        "winner_side": match_row.get("winner_side"),
        "winner_name": match_row.get("winner_name"),
        "ended_early": bool(match_row.get("ended_early")),
        "match_end_reason": match_row.get("end_reason"),
        "events": [],
    }


def _build_state(match_row, event_rows):
    state = _initial_state(match_row)

    for event_row in event_rows:
        payload = event_row.get("payload") or {}
        event_type = event_row["event_type"]
        state["events"].append(_serialize_event(match_row, event_row))

        if event_type == "match_started":
            state["best_of"] = _best_of_value(payload.get("best_of", state["best_of"]))
            state["games_to_win"] = _coerce_int(payload.get("games_to_win"), _games_to_win(state["best_of"]))
            state["current_game_number"] = _coerce_int(payload.get("current_game_number"), state["current_game_number"])
            state["player1_games_won"] = _coerce_int(payload.get("player1_games_won"), state["player1_games_won"])
            state["player2_games_won"] = _coerce_int(payload.get("player2_games_won"), state["player2_games_won"])
            state["current_server"] = payload.get("current_server", state["current_server"])
            state["current_server_side"] = payload.get("current_server_side", state["current_server_side"])
            state["service_side"] = payload.get("service_side", state["service_side"])
            state["player1_score"] = _coerce_int(payload.get("player1_score"), state["player1_score"])
            state["player2_score"] = _coerce_int(payload.get("player2_score"), state["player2_score"])
            if payload.get("handicap_enabled"):
                state["handicap"] = {
                    "enabled": True,
                    "player1_band": payload.get("player1_band"),
                    "player2_band": payload.get("player2_band"),
                    "player1_offset": _coerce_int(payload.get("player1_offset")),
                    "player2_offset": _coerce_int(payload.get("player2_offset")),
                }

        elif event_type in {"score_point", "stroke"}:
            game_result = payload.get("game_result")
            if game_result:
                state["game_history"].append(game_result)

            if "player1_score" in payload:
                state["player1_score"] = _coerce_int(payload.get("player1_score"), state["player1_score"])
                state["player2_score"] = _coerce_int(payload.get("player2_score"), state["player2_score"])
                state["player1_games_won"] = _coerce_int(payload.get("player1_games_won"), state["player1_games_won"])
                state["player2_games_won"] = _coerce_int(payload.get("player2_games_won"), state["player2_games_won"])
                state["current_game_number"] = _coerce_int(payload.get("current_game_number"), state["current_game_number"])
                state["current_server"] = payload.get("current_server", state["current_server"])
                state["current_server_side"] = payload.get("current_server_side", state["current_server_side"])
                state["service_side"] = payload.get("service_side", state["service_side"])
                state["best_of"] = _best_of_value(payload.get("best_of", state["best_of"]))
                state["games_to_win"] = _coerce_int(payload.get("games_to_win"), state["games_to_win"])
                if payload.get("match_completed"):
                    state["match_complete"] = True
                    state["winner_side"] = payload.get("winner_side")
                    state["winner_name"] = payload.get("winner_name")
            else:
                scorer = payload.get("scorer") or payload.get("player_side")
                if scorer == "player1":
                    state["player1_score"] += 1
                    state["current_server"] = match_row["player1_name"]
                    state["current_server_side"] = "player1"
                    state["service_side"] = _next_service_side_after_point(
                        match_row,
                        state.get("current_server_side"),
                        state.get("service_side"),
                        "player1",
                    )
                elif scorer == "player2":
                    state["player2_score"] += 1
                    state["current_server"] = match_row["player2_name"]
                    state["current_server_side"] = "player2"
                    state["service_side"] = _next_service_side_after_point(
                        match_row,
                        state.get("current_server_side"),
                        state.get("service_side"),
                        "player2",
                    )

        elif event_type == "serve_side":
            state["service_side"] = payload.get("side", state["service_side"])

        elif event_type == "server":
            server_side = payload.get("current_server_side")
            if server_side in {"player1", "player2"}:
                state["current_server_side"] = server_side
                state["current_server"] = _player_name(match_row, server_side)
                state["service_side"] = payload.get("service_side") or _service_side_for_receiver(match_row, server_side)

        elif event_type == "match_ended":
            state["match_complete"] = True
            state["ended_early"] = bool(payload.get("ended_early"))
            state["match_end_reason"] = payload.get("reason") or payload.get("note")
            state["winner_side"] = payload.get("winner_side")
            state["winner_name"] = payload.get("winner_name")
            state["player1_score"] = _coerce_int(payload.get("player1_score"), state["player1_score"])
            state["player2_score"] = _coerce_int(payload.get("player2_score"), state["player2_score"])
            state["player1_games_won"] = _coerce_int(payload.get("player1_games_won"), state["player1_games_won"])
            state["player2_games_won"] = _coerce_int(payload.get("player2_games_won"), state["player2_games_won"])
            state["current_game_number"] = _coerce_int(payload.get("current_game_number"), state["current_game_number"])

    return state


def _serialize_match(match_row, event_rows):
    best_of = _best_of_value(match_row.get("best_of", 1))
    return {
        "id": str(match_row["id"]),
        "tenant_id": match_row["tenant_id"],
        "court_id": match_row["court_id"],
        "court_name": match_row["court_name"],
        "court_alias": match_row.get("court_alias"),
        "sport": match_row.get("sport") or "squash",
        "player1_name": match_row["player1_name"],
        "player1_surname": match_row.get("player1_surname"),
        "player1_country": match_row.get("player1_country"),
        "player1_handedness": match_row.get("player1_handedness") or "right",
        "player2_name": match_row["player2_name"],
        "player2_surname": match_row.get("player2_surname"),
        "player2_country": match_row.get("player2_country"),
        "player2_handedness": match_row.get("player2_handedness") or "right",
        "referee_name": match_row.get("referee_name"),
        "score_type": match_row["score_type"],
        "best_of": best_of,
        "games_to_win": _coerce_int(match_row.get("games_to_win"), _games_to_win(best_of)),
        "current_game_number": _coerce_int(match_row.get("current_game_number"), 1),
        "player1_games_won": _coerce_int(match_row.get("player1_games_won")),
        "player2_games_won": _coerce_int(match_row.get("player2_games_won")),
        "handicap_enabled": bool(match_row.get("handicap_enabled")),
        "player1_band": match_row.get("player1_band"),
        "player2_band": match_row.get("player2_band"),
        "player1_offset": _coerce_int(match_row.get("player1_offset")),
        "player2_offset": _coerce_int(match_row.get("player2_offset")),
        "player1_final_score": _coerce_int(match_row.get("player1_final_score")),
        "player2_final_score": _coerce_int(match_row.get("player2_final_score")),
        "winner_side": match_row.get("winner_side"),
        "winner_name": match_row.get("winner_name"),
        "ended_early": bool(match_row.get("ended_early")),
        "end_reason": match_row.get("end_reason"),
        "status": match_row["status"],
        "created_at": match_row["created_at"].isoformat(),
        "completed_at": match_row["completed_at"].isoformat() if match_row.get("completed_at") else None,
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

    if status == "completed":
        query.append("ORDER BY COALESCE(completed_at, updated_at) DESC, updated_at DESC LIMIT %(limit)s")
    else:
        query.append("ORDER BY updated_at DESC, created_at DESC LIMIT %(limit)s")

    with connection.cursor() as cursor:
        cursor.execute("\n".join(query), params)
        match_rows = cursor.fetchall()

    return [
        _serialize_match(match_row, _fetch_match_events(connection, match_row["id"]))
        for match_row in match_rows
    ]


def _find_active_match_on_court(connection, tenant_id, court_id):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT *
            FROM matches
            WHERE tenant_id = %(tenant_id)s
              AND court_id = %(court_id)s
              AND status = 'active'
            ORDER BY updated_at DESC, created_at DESC
            LIMIT 1
            """,
            {
                "tenant_id": tenant_id,
                "court_id": court_id,
            },
        )
        return cursor.fetchone()


def _fetch_tenant_plan(connection, tenant_id):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT org_type, plan
            FROM "SkwshOrgSettings"
            WHERE id = %(tenant_id)s
            LIMIT 1
            """,
            {"tenant_id": tenant_id},
        )
        row = cursor.fetchone()

    return {
        "org_type": (row or {}).get("org_type") or "club",
        "plan": (row or {}).get("plan") or "club_essentials",
    }


def _is_personal_tenant(tenant_id, tenant_plan):
    if (tenant_plan or {}).get("org_type") == "personal":
        return True

    return _coerce_int(tenant_id) >= 50000


def is_personal_tenant(connection, tenant_id):
    return _is_personal_tenant(tenant_id, _fetch_tenant_plan(connection, tenant_id))


def _ensure_personal_match_court(connection, tenant_id):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id, court_name, court_alias
            FROM "SkwshCourts"
            WHERE organization_name = %(tenant_id)s
            ORDER BY id ASC
            LIMIT 1
            """,
            {"tenant_id": int(tenant_id)},
        )
        court_row = cursor.fetchone()
        if court_row:
            return court_row

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
                %(tenant_id)s
            )
            RETURNING id, court_name, court_alias
            """,
            {
                "created_at": _utcnow(),
                "tenant_id": int(tenant_id),
            },
        )
        return cursor.fetchone()


def create_match(connection, payload, source="api"):
    match_id = str(uuid4())
    tenant_id = payload["tenant_id"]
    now = _utcnow()
    tenant_plan = _fetch_tenant_plan(connection, tenant_id)
    is_personal_tenant = _is_personal_tenant(tenant_id, tenant_plan)
    match_payload = {**payload}

    if is_personal_tenant:
        personal_court = _ensure_personal_match_court(connection, tenant_id)
        match_payload.update({
            "court_id": personal_court["id"],
            "court_name": personal_court.get("court_name") or "Personal Match",
            "court_alias": personal_court.get("court_alias") or personal_court.get("court_name") or "Personal Match",
            "referee_name": None,
        })

    best_of = _best_of_value(payload.get("best_of", 1))
    games_to_win = _games_to_win(best_of)
    requested_status = "active" if is_personal_tenant else _match_status_value(payload.get("status"))
    conflicting_match = None
    match_status = requested_status
    handicap_enabled = False if is_personal_tenant else bool(payload.get("handicap_enabled"))
    player1_offset = _coerce_int(payload.get("player1_offset")) if handicap_enabled else 0
    player2_offset = _coerce_int(payload.get("player2_offset")) if handicap_enabled else 0

    if requested_status == "active" and not is_personal_tenant:
        conflicting_match = _find_active_match_on_court(
            connection,
            tenant_id=tenant_id,
            court_id=match_payload["court_id"],
        )
        if conflicting_match:
            match_status = "scheduled"

    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO matches (
                id,
                tenant_id,
                court_id,
                court_name,
                court_alias,
                sport,
                player1_name,
                player1_surname,
                player1_country,
                player1_handedness,
                player2_name,
                player2_surname,
                player2_country,
                player2_handedness,
                referee_name,
                score_type,
                best_of,
                games_to_win,
                current_game_number,
                player1_games_won,
                player2_games_won,
                handicap_enabled,
                player1_band,
                player2_band,
                player1_offset,
                player2_offset,
                player1_final_score,
                player2_final_score,
                winner_side,
                winner_name,
                ended_early,
                end_reason,
                status,
                created_at,
                completed_at,
                updated_at
            )
            VALUES (
                %(id)s,
                %(tenant_id)s,
                %(court_id)s,
                %(court_name)s,
                %(court_alias)s,
                %(sport)s,
                %(player1_name)s,
                %(player1_surname)s,
                %(player1_country)s,
                %(player1_handedness)s,
                %(player2_name)s,
                %(player2_surname)s,
                %(player2_country)s,
                %(player2_handedness)s,
                %(referee_name)s,
                %(score_type)s,
                %(best_of)s,
                %(games_to_win)s,
                1,
                0,
                0,
                %(handicap_enabled)s,
                %(player1_band)s,
                %(player2_band)s,
                %(player1_offset)s,
                %(player2_offset)s,
                %(player1_final_score)s,
                %(player2_final_score)s,
                %(winner_side)s,
                %(winner_name)s,
                false,
                %(end_reason)s,
                %(status)s,
                %(created_at)s,
                %(completed_at)s,
                %(updated_at)s
            )
            """,
            {
                "id": match_id,
                "tenant_id": tenant_id,
                "court_id": match_payload["court_id"],
                "court_name": match_payload["court_name"],
                "court_alias": match_payload.get("court_alias"),
                "sport": match_payload.get("sport") or "squash",
                "player1_name": match_payload["player1_name"],
                "player1_surname": match_payload.get("player1_surname"),
                "player1_country": match_payload.get("player1_country"),
                "player1_handedness": str(match_payload.get("player1_handedness") or "right").lower(),
                "player2_name": match_payload["player2_name"],
                "player2_surname": match_payload.get("player2_surname"),
                "player2_country": match_payload.get("player2_country"),
                "player2_handedness": str(match_payload.get("player2_handedness") or "right").lower(),
                "referee_name": match_payload.get("referee_name"),
                "score_type": int(match_payload.get("score_type", 15)),
                "best_of": best_of,
                "games_to_win": games_to_win,
                "handicap_enabled": handicap_enabled,
                "player1_band": match_payload.get("player1_band"),
                "player2_band": match_payload.get("player2_band"),
                "player1_offset": player1_offset,
                "player2_offset": player2_offset,
                "player1_final_score": None,
                "player2_final_score": None,
                "winner_side": None,
                "winner_name": None,
                "end_reason": None,
                "status": match_status,
                "created_at": now,
                "completed_at": None,
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
                "payload": Jsonb({
                    "court_id": match_payload["court_id"],
                    "court_name": match_payload["court_name"],
                    "court_alias": match_payload.get("court_alias"),
                    "sport": match_payload.get("sport") or "squash",
                    "best_of": best_of,
                    "games_to_win": games_to_win,
                    "current_game_number": 1,
                    "player1_games_won": 0,
                    "player2_games_won": 0,
                    "current_server": match_payload["player1_name"],
                    "current_server_side": "player1",
                    "service_side": _service_side_for_receiver(match_payload, "player1"),
                    "player1_score": player1_offset,
                    "player2_score": player2_offset,
                    "handicap_enabled": handicap_enabled,
                    "player1_band": match_payload.get("player1_band"),
                    "player2_band": match_payload.get("player2_band"),
                    "player1_offset": player1_offset,
                    "player2_offset": player2_offset,
                }),
                "event_source": source,
                "created_at": now,
            },
        )

    connection.commit()
    match = get_match(connection, match_id)
    if match and conflicting_match:
        match["auto_scheduled"] = True
        match["requested_status"] = requested_status
        match["auto_schedule_reason"] = (
            f"There is an active game currently on {match_payload['court_name']}. "
            "The new match has been set up as a scheduled match ready to start later."
        )
        match["conflicting_match_id"] = str(conflicting_match["id"])
        match["conflicting_court_name"] = conflicting_match.get("court_name") or match_payload["court_name"]
    return match


def activate_scheduled_match(connection, match_id):
    match_row = _fetch_match_row(connection, match_id)
    if not match_row:
        return None

    if match_row["status"] != "scheduled":
        return get_match(connection, match_id)

    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE matches
            SET status = 'active',
                updated_at = %(updated_at)s
            WHERE id = %(match_id)s
            """,
            {
                "match_id": match_id,
                "updated_at": _utcnow(),
            },
        )

    connection.commit()
    return get_match(connection, match_id)


def _update_match_summary(connection, match_id, state, completed_at=None):
    now = _utcnow()
    status = "completed" if state.get("match_complete") else "active"
    effective_completed_at = completed_at

    if status == "completed" and effective_completed_at is None:
        current_row = _fetch_match_row(connection, match_id)
        effective_completed_at = (current_row or {}).get("completed_at") or now

    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE matches
            SET current_game_number = %(current_game_number)s,
                player1_games_won = %(player1_games_won)s,
                player2_games_won = %(player2_games_won)s,
                player1_final_score = %(player1_final_score)s,
                player2_final_score = %(player2_final_score)s,
                winner_side = %(winner_side)s,
                winner_name = %(winner_name)s,
                ended_early = %(ended_early)s,
                end_reason = %(end_reason)s,
                status = %(status)s,
                completed_at = %(completed_at)s,
                updated_at = %(updated_at)s
            WHERE id = %(match_id)s
            """,
            {
                "current_game_number": state["current_game_number"],
                "player1_games_won": state["player1_games_won"],
                "player2_games_won": state["player2_games_won"],
                "player1_final_score": state["player1_score"] if state.get("match_complete") else None,
                "player2_final_score": state["player2_score"] if state.get("match_complete") else None,
                "winner_side": state.get("winner_side") if state.get("match_complete") else None,
                "winner_name": state.get("winner_name") if state.get("match_complete") else None,
                "ended_early": bool(state.get("ended_early")) if state.get("match_complete") else False,
                "end_reason": state.get("match_end_reason") if state.get("match_complete") else None,
                "status": status,
                "completed_at": effective_completed_at if state.get("match_complete") else None,
                "updated_at": now,
                "match_id": match_id,
            },
        )


def _prepare_scoring_transition(match, scorer_side, event_type, extra_payload=None):
    state = match["state"]
    if match["status"] == "completed" or state.get("match_complete"):
        raise ValueError("Match is already complete")

    scoring_game_number = state["current_game_number"]
    player1_score = state["player1_score"]
    player2_score = state["player2_score"]
    previous_server_side = state.get("current_server_side")
    previous_service_side = state.get("service_side")

    if scorer_side == "player1":
        player1_score += 1
        current_server = match["player1_name"]
        current_server_side = "player1"
        service_side = _next_service_side_after_point(
            match,
            previous_server_side,
            previous_service_side,
            "player1",
        )
    else:
        player2_score += 1
        current_server = match["player2_name"]
        current_server_side = "player2"
        service_side = _next_service_side_after_point(
            match,
            previous_server_side,
            previous_service_side,
            "player2",
        )

    player1_games_won = state["player1_games_won"]
    player2_games_won = state["player2_games_won"]
    current_game_number = scoring_game_number
    game_result = None
    match_completed = False
    ended_early = False
    match_end_reason = None
    winner_side = None
    winner_name = None

    if _is_game_complete(player1_score, player2_score, match["score_type"]):
        winner_side, winner_name = _winner_from_scores(match, player1_score, player2_score)
        if winner_side == "player1":
            player1_games_won += 1
        elif winner_side == "player2":
            player2_games_won += 1

        game_result = {
            "game_number": scoring_game_number,
            "player1_score": player1_score,
            "player2_score": player2_score,
            "winner_side": winner_side,
            "winner_name": winner_name,
        }

        if player1_games_won >= state["games_to_win"] or player2_games_won >= state["games_to_win"]:
            match_completed = True
        else:
            current_game_number += 1
            player1_score, player2_score = _initial_scores(match)
            current_server = winner_name
            current_server_side = winner_side
            service_side = _service_side_for_receiver(match, current_server_side)
            winner_side = None
            winner_name = None

    payload = {
        **(extra_payload or {}),
        "game_number": scoring_game_number,
        "current_game_number": current_game_number,
        "best_of": state["best_of"],
        "games_to_win": state["games_to_win"],
        "player1_score": player1_score,
        "player2_score": player2_score,
        "player1_games_won": player1_games_won,
        "player2_games_won": player2_games_won,
        "current_server": current_server,
        "current_server_side": current_server_side,
        "service_side": service_side,
        "game_completed": bool(game_result),
        "game_result": game_result,
        "match_completed": match_completed,
        "winner_side": winner_side if match_completed else None,
        "winner_name": winner_name if match_completed else None,
        "ended_early": ended_early,
        "end_reason": match_end_reason,
    }

    next_state = {
        **state,
        "player1_score": player1_score,
        "player2_score": player2_score,
        "player1_games_won": player1_games_won,
        "player2_games_won": player2_games_won,
        "current_game_number": current_game_number,
        "current_server": current_server,
        "current_server_side": current_server_side,
        "service_side": service_side,
        "match_complete": match_completed,
        "winner_side": winner_side if match_completed else None,
        "winner_name": winner_name if match_completed else None,
        "ended_early": ended_early,
        "match_end_reason": match_end_reason,
        "game_history": [
            *state["game_history"],
            *([game_result] if game_result else []),
        ],
    }

    return {
        "event_type": event_type,
        "payload": payload,
        "state": next_state,
    }


def _append_event(connection, match_id, event_type, payload, source="api", state_override=None, completed_at=None):
    match_row = _fetch_match_row(connection, match_id)
    if not match_row:
        return None
    if match_row["status"] == "completed" and event_type != "match_ended":
        raise ValueError("Match is already complete")

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
                "payload": Jsonb(payload),
                "event_source": source,
                "created_at": _utcnow(),
            },
        )

    if state_override is not None:
        _update_match_summary(connection, match_id, state_override, completed_at=completed_at)
    else:
        with connection.cursor() as cursor:
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

    match = get_match(connection, match_id)
    if not match:
        return None

    transition = _prepare_scoring_transition(
        match,
        scorer_side=scorer,
        event_type="score_point",
        extra_payload={"scorer": scorer},
    )
    completed_at = _utcnow() if transition["state"]["match_complete"] else None
    return _append_event(
        connection,
        match_id,
        transition["event_type"],
        transition["payload"],
        source=source,
        state_override=transition["state"],
        completed_at=completed_at,
    )


def event_action(connection, match_id, action_type, payload, source="api"):
    if action_type not in ALLOWED_ACTION_TYPES:
        raise ValueError(f"action_type must be one of: {', '.join(sorted(ALLOWED_ACTION_TYPES))}")

    if action_type == "stroke":
        scorer_side = payload.get("player_side")
        if scorer_side not in {"player1", "player2"}:
            raise ValueError("stroke events require player_side = 'player1' or 'player2'")

        match = get_match(connection, match_id)
        if not match:
            return None

        transition = _prepare_scoring_transition(
            match,
            scorer_side=scorer_side,
            event_type="stroke",
            extra_payload=payload,
        )
        completed_at = _utcnow() if transition["state"]["match_complete"] else None
        return _append_event(
            connection,
            match_id,
            transition["event_type"],
            transition["payload"],
            source=source,
            state_override=transition["state"],
            completed_at=completed_at,
        )

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

    match = get_match(connection, match_id)
    if not match:
        connection.commit()
        return None

    _update_match_summary(connection, match_id, match["state"])
    connection.commit()
    return get_match(connection, match_id)


def end_match(connection, match_id, source="api", reason=None, ended_early=None):
    match = get_match(connection, match_id)
    if not match:
        return None

    state = match["state"]
    winner_side, winner_name = _match_leader(match, state)
    final_ended_early = bool(ended_early) if ended_early is not None else not state.get("match_complete")
    final_reason = reason or ("Ended by operator" if final_ended_early else None)
    now = _utcnow()

    final_state = {
        **state,
        "match_complete": True,
        "winner_side": winner_side,
        "winner_name": winner_name,
        "ended_early": final_ended_early,
        "match_end_reason": final_reason,
    }

    payload = {
        "status": "completed",
        "ended_early": final_ended_early,
        "reason": final_reason,
        "winner_side": winner_side,
        "winner_name": winner_name,
        "player1_score": state["player1_score"],
        "player2_score": state["player2_score"],
        "player1_games_won": state["player1_games_won"],
        "player2_games_won": state["player2_games_won"],
        "current_game_number": state["current_game_number"],
    }

    return _append_event(
        connection,
        match_id,
        "match_ended",
        payload,
        source=source,
        state_override=final_state,
        completed_at=now,
    )


def websocket_payload(match):
    return {
        "type": "match.updated",
        "match": match,
    }
