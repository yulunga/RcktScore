from uuid import uuid4

from psycopg.types.json import Jsonb

from common import squash_match_logic as shared


SPORT = "tennis"
ALLOWED_ACTION_TYPES = {"let", "match_settings", "server", "serve_side", "stroke", "timer"}
VALID_BEST_OF_OPTIONS = {1, 3, 5}
VALID_SCORE_TYPE_OPTIONS = {4, 6}
TENNIS_POINT_LABELS = {
    0: "0",
    1: "15",
    2: "30",
    3: "40",
}


def _player_name(match_like, side):
    if side == "player1":
        return match_like["player1_name"]
    if side == "player2":
        return match_like["player2_name"]
    return None


def _opponent(side):
    return "player2" if side == "player1" else "player1"


def _best_of_value(value):
    parsed = shared._coerce_int(value, default=3)
    return parsed if parsed in VALID_BEST_OF_OPTIONS else 3


def _score_type_value(value):
    parsed = shared._coerce_int(value, default=6)
    return parsed if parsed in VALID_SCORE_TYPE_OPTIONS else 6


def _games_to_win(best_of):
    return (_best_of_value(best_of) // 2) + 1


def _match_status_value(value):
    parsed = str(value or "active").strip().lower()
    return parsed if parsed in shared.VALID_MATCH_STATUSES else "active"


def _tie_break_trigger(score_type):
    return 3 if _score_type_value(score_type) == 4 else 6


def _should_start_tie_break(player1_set_games, player2_set_games, score_type):
    trigger = _tie_break_trigger(score_type)
    return player1_set_games == trigger and player2_set_games == trigger


def _is_regular_game_complete(player1_score, player2_score):
    highest = max(player1_score, player2_score)
    lowest = min(player1_score, player2_score)
    return highest >= 4 and (highest - lowest) >= 2


def _is_tie_break_complete(player1_score, player2_score):
    highest = max(player1_score, player2_score)
    lowest = min(player1_score, player2_score)
    return highest >= 7 and (highest - lowest) >= 2


def _is_set_complete(player1_set_games, player2_set_games, score_type):
    highest = max(player1_set_games, player2_set_games)
    lowest = min(player1_set_games, player2_set_games)
    target = _score_type_value(score_type)
    return highest >= target and (highest - lowest) >= 2


def _winner_side(player1_value, player2_value):
    if player1_value > player2_value:
        return "player1"
    if player2_value > player1_value:
        return "player2"
    return "draw"


def _tennis_score_labels(player1_score, player2_score, is_tie_break):
    if is_tie_break:
        return str(player1_score), str(player2_score)

    if player1_score >= 3 and player2_score >= 3:
        if player1_score == player2_score:
            return "40", "40"
        if player1_score > player2_score:
            return "Ad", "40"
        return "40", "Ad"

    return (
        TENNIS_POINT_LABELS.get(player1_score, "40"),
        TENNIS_POINT_LABELS.get(player2_score, "40"),
    )


def _service_side_for_next_point(player1_score, player2_score):
    total_points = shared._coerce_int(player1_score) + shared._coerce_int(player2_score)
    return "Right" if total_points % 2 == 0 else "Left"


def _next_tie_break_server(first_server_side, player1_score, player2_score):
    total_points_played = shared._coerce_int(player1_score) + shared._coerce_int(player2_score)
    if total_points_played <= 0:
        return first_server_side
    if total_points_played == 1:
        return _opponent(first_server_side)

    block_index = (total_points_played - 1) // 2
    return _opponent(first_server_side) if block_index % 2 == 0 else first_server_side


def _event_summary(match_row, event_type, payload):
    if event_type == "match_started":
        return (
            f"{match_row['player1_name']} vs {match_row['player2_name']} started "
            f"(best of {payload.get('best_of', 3)} sets)"
        )
    if event_type == "match_settings":
        return (
            f"Match settings updated: first to {payload.get('score_type', match_row['score_type'])} games, "
            f"best of {payload.get('best_of', match_row['best_of'])} sets"
        )
    if event_type == "match_ended":
        if payload.get("ended_early"):
            return payload.get("reason") or "Match ended early"
        if payload.get("winner_name"):
            return f"{payload['winner_name']} won the match"
        return payload.get("note") or "Match ended"
    if event_type in {"score_point", "stroke"}:
        scorer_side = payload.get("scorer") or payload.get("player_side")
        scorer_name = _player_name(match_row, scorer_side)
        set_result = payload.get("game_result")
        if payload.get("match_completed") and scorer_name:
            return f"{scorer_name} won the match"
        if set_result and scorer_name:
            return f"{scorer_name} won set {set_result['game_number']}"
        if scorer_name:
            return f"{scorer_name} won the point"
    if event_type == "server":
        server_side = payload.get("current_server_side")
        if server_side == "player2":
            return f"{match_row['player2_name']} selected to serve first"
        return f"{match_row['player1_name']} selected to serve first"
    if event_type == "serve_side":
        return f"Serve changed to {payload.get('side', 'Right')}"
    if event_type == "let":
        return payload.get("note") or "Let called"
    if event_type == "timer":
        if "match_duration_seconds" in payload:
            return f"Match duration recorded: {shared._coerce_int(payload.get('match_duration_seconds'))} seconds"
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
    best_of = _best_of_value(match_row.get("best_of", 3))
    score_type = _score_type_value(match_row.get("score_type", 6))
    player1_score_label, player2_score_label = _tennis_score_labels(0, 0, False)
    return {
        "player1_score": 0,
        "player2_score": 0,
        "score_type": score_type,
        "player1_shirt_color": shared._shirt_color_value(
            match_row.get("player1_shirt_color"),
            shared.DEFAULT_PLAYER_SHIRT_COLORS["player1"],
        ),
        "player2_shirt_color": shared._shirt_color_value(
            match_row.get("player2_shirt_color"),
            shared.DEFAULT_PLAYER_SHIRT_COLORS["player2"],
        ),
        "player1_games_won": shared._coerce_int(match_row.get("player1_games_won")),
        "player2_games_won": shared._coerce_int(match_row.get("player2_games_won")),
        "current_game_number": shared._coerce_int(match_row.get("current_game_number"), 1),
        "games_to_win": shared._coerce_int(match_row.get("games_to_win"), _games_to_win(best_of)),
        "best_of": best_of,
        "current_server": match_row["player1_name"],
        "current_server_side": "player1",
        "service_side": "Right",
        "handicap": {
            "enabled": False,
            "player1_band": None,
            "player2_band": None,
            "player1_offset": 0,
            "player2_offset": 0,
        },
        "player1_set_games": 0,
        "player2_set_games": 0,
        "is_tie_break": False,
        "tiebreak_first_server_side": None,
        "score_display_mode": "tennis",
        "player1_score_label": player1_score_label,
        "player2_score_label": player2_score_label,
        "game_history": [],
        "match_complete": match_row.get("status") == "completed",
        "winner_side": match_row.get("winner_side"),
        "winner_name": match_row.get("winner_name"),
        "ended_early": bool(match_row.get("ended_early")),
        "match_end_reason": match_row.get("end_reason"),
        "match_duration_seconds": shared._coerce_int(match_row.get("match_duration_seconds")),
        "events": [],
    }


def _apply_score_labels(state):
    player1_label, player2_label = _tennis_score_labels(
        state["player1_score"],
        state["player2_score"],
        state.get("is_tie_break"),
    )
    state["player1_score_label"] = player1_label
    state["player2_score_label"] = player2_label
    state["score_display_mode"] = "tennis"
    return state


def _build_state(match_row, event_rows):
    state = _initial_state(match_row)

    for event_row in event_rows:
        payload = event_row.get("payload") or {}
        event_type = event_row["event_type"]
        state["events"].append(_serialize_event(match_row, event_row))

        if event_type == "match_started":
            state["score_type"] = _score_type_value(payload.get("score_type", state["score_type"]))
            state["best_of"] = _best_of_value(payload.get("best_of", state["best_of"]))
            state["games_to_win"] = shared._coerce_int(payload.get("games_to_win"), _games_to_win(state["best_of"]))
            state["current_game_number"] = shared._coerce_int(payload.get("current_game_number"), state["current_game_number"])
            state["player1_games_won"] = shared._coerce_int(payload.get("player1_games_won"), state["player1_games_won"])
            state["player2_games_won"] = shared._coerce_int(payload.get("player2_games_won"), state["player2_games_won"])
            state["player1_set_games"] = shared._coerce_int(payload.get("player1_set_games"), state["player1_set_games"])
            state["player2_set_games"] = shared._coerce_int(payload.get("player2_set_games"), state["player2_set_games"])
            state["current_server"] = payload.get("current_server", state["current_server"])
            state["current_server_side"] = payload.get("current_server_side", state["current_server_side"])
            state["service_side"] = payload.get("service_side", state["service_side"])
            state["player1_score"] = shared._coerce_int(payload.get("player1_score"), state["player1_score"])
            state["player2_score"] = shared._coerce_int(payload.get("player2_score"), state["player2_score"])
            state["player1_shirt_color"] = shared._shirt_color_value(
                payload.get("player1_shirt_color"),
                state["player1_shirt_color"],
            )
            state["player2_shirt_color"] = shared._shirt_color_value(
                payload.get("player2_shirt_color"),
                state["player2_shirt_color"],
            )
            state["is_tie_break"] = bool(payload.get("is_tie_break"))
            state["tiebreak_first_server_side"] = payload.get("tiebreak_first_server_side")
            _apply_score_labels(state)
        elif event_type == "match_settings":
            state["score_type"] = _score_type_value(payload.get("score_type", state["score_type"]))
            state["best_of"] = _best_of_value(payload.get("best_of", state["best_of"]))
            state["games_to_win"] = shared._coerce_int(payload.get("games_to_win"), _games_to_win(state["best_of"]))
            state["player1_shirt_color"] = shared._shirt_color_value(
                payload.get("player1_shirt_color"),
                state["player1_shirt_color"],
            )
            state["player2_shirt_color"] = shared._shirt_color_value(
                payload.get("player2_shirt_color"),
                state["player2_shirt_color"],
            )
            _apply_score_labels(state)
        elif event_type in {"score_point", "stroke"}:
            set_result = payload.get("game_result")
            if set_result:
                state["game_history"].append(set_result)

            state["player1_score"] = shared._coerce_int(payload.get("player1_score"), state["player1_score"])
            state["player2_score"] = shared._coerce_int(payload.get("player2_score"), state["player2_score"])
            state["player1_games_won"] = shared._coerce_int(payload.get("player1_games_won"), state["player1_games_won"])
            state["player2_games_won"] = shared._coerce_int(payload.get("player2_games_won"), state["player2_games_won"])
            state["current_game_number"] = shared._coerce_int(payload.get("current_game_number"), state["current_game_number"])
            state["current_server"] = payload.get("current_server", state["current_server"])
            state["current_server_side"] = payload.get("current_server_side", state["current_server_side"])
            state["service_side"] = payload.get("service_side", state["service_side"])
            state["player1_set_games"] = shared._coerce_int(payload.get("player1_set_games"), state["player1_set_games"])
            state["player2_set_games"] = shared._coerce_int(payload.get("player2_set_games"), state["player2_set_games"])
            state["is_tie_break"] = bool(payload.get("is_tie_break"))
            state["tiebreak_first_server_side"] = payload.get("tiebreak_first_server_side")
            if payload.get("match_completed"):
                state["match_complete"] = True
                state["winner_side"] = payload.get("winner_side")
                state["winner_name"] = payload.get("winner_name")
            _apply_score_labels(state)
        elif event_type == "serve_side":
            state["service_side"] = payload.get("side", state["service_side"])
        elif event_type == "server":
            server_side = payload.get("current_server_side")
            if server_side in {"player1", "player2"}:
                state["current_server_side"] = server_side
                state["current_server"] = _player_name(match_row, server_side)
                state["service_side"] = payload.get("service_side") or "Right"
        elif event_type == "match_ended":
            state["match_complete"] = True
            state["ended_early"] = bool(payload.get("ended_early"))
            state["match_end_reason"] = payload.get("reason") or payload.get("note")
            state["winner_side"] = payload.get("winner_side")
            state["winner_name"] = payload.get("winner_name")
            state["player1_score"] = shared._coerce_int(payload.get("player1_score"), state["player1_score"])
            state["player2_score"] = shared._coerce_int(payload.get("player2_score"), state["player2_score"])
            state["player1_games_won"] = shared._coerce_int(payload.get("player1_games_won"), state["player1_games_won"])
            state["player2_games_won"] = shared._coerce_int(payload.get("player2_games_won"), state["player2_games_won"])
            state["player1_set_games"] = shared._coerce_int(payload.get("player1_set_games"), state["player1_set_games"])
            state["player2_set_games"] = shared._coerce_int(payload.get("player2_set_games"), state["player2_set_games"])
            state["current_game_number"] = shared._coerce_int(payload.get("current_game_number"), state["current_game_number"])
            state["match_duration_seconds"] = shared._coerce_int(
                payload.get("match_duration_seconds"),
                state["match_duration_seconds"],
            )
            state["is_tie_break"] = bool(payload.get("is_tie_break"))
            _apply_score_labels(state)
        elif event_type == "timer":
            state["match_duration_seconds"] = shared._coerce_int(
                payload.get("match_duration_seconds"),
                state["match_duration_seconds"],
            )

    return state


def _serialize_match(match_row, event_rows):
    best_of = _best_of_value(match_row.get("best_of", 3))
    return {
        "id": str(match_row["id"]),
        "tenant_id": match_row["tenant_id"],
        "court_id": match_row["court_id"],
        "court_name": match_row["court_name"],
        "court_alias": match_row.get("court_alias"),
        "court_display_code": match_row.get("court_display_code") or "",
        "sport": match_row.get("sport") or SPORT,
        "player1_name": match_row["player1_name"],
        "player1_surname": match_row.get("player1_surname"),
        "player1_country": match_row.get("player1_country"),
        "player1_handedness": match_row.get("player1_handedness") or "right",
        "player1_shirt_color": shared._shirt_color_value(
            match_row.get("player1_shirt_color"),
            shared.DEFAULT_PLAYER_SHIRT_COLORS["player1"],
        ),
        "player2_name": match_row["player2_name"],
        "player2_surname": match_row.get("player2_surname"),
        "player2_country": match_row.get("player2_country"),
        "player2_handedness": match_row.get("player2_handedness") or "right",
        "player2_shirt_color": shared._shirt_color_value(
            match_row.get("player2_shirt_color"),
            shared.DEFAULT_PLAYER_SHIRT_COLORS["player2"],
        ),
        "referee_name": match_row.get("referee_name"),
        "score_type": _score_type_value(match_row.get("score_type", 6)),
        "best_of": best_of,
        "games_to_win": shared._coerce_int(match_row.get("games_to_win"), _games_to_win(best_of)),
        "current_game_number": shared._coerce_int(match_row.get("current_game_number"), 1),
        "player1_games_won": shared._coerce_int(match_row.get("player1_games_won")),
        "player2_games_won": shared._coerce_int(match_row.get("player2_games_won")),
        "handicap_enabled": False,
        "player1_band": None,
        "player2_band": None,
        "player1_offset": 0,
        "player2_offset": 0,
        "player1_final_score": shared._coerce_int(match_row.get("player1_final_score")),
        "player2_final_score": shared._coerce_int(match_row.get("player2_final_score")),
        "winner_side": match_row.get("winner_side"),
        "winner_name": match_row.get("winner_name"),
        "ended_early": bool(match_row.get("ended_early")),
        "end_reason": match_row.get("end_reason"),
        "match_duration_seconds": shared._coerce_int(match_row.get("match_duration_seconds")),
        "status": match_row["status"],
        "created_at": match_row["created_at"].isoformat(),
        "completed_at": match_row["completed_at"].isoformat() if match_row.get("completed_at") else None,
        "updated_at": match_row["updated_at"].isoformat(),
        "state": _build_state(match_row, event_rows),
    }


def serialize_match(match_row, event_rows):
    return _serialize_match(match_row, event_rows)


def get_match(connection, match_id):
    match_row = shared._fetch_match_row(connection, match_id)
    if not match_row:
        return None
    return _serialize_match(match_row, shared._fetch_match_events(connection, match_id))


def _update_match_summary(connection, match_id, state, completed_at=None):
    now = shared._utcnow()
    status = "completed" if state.get("match_complete") else "active"
    effective_completed_at = completed_at

    if status == "completed" and effective_completed_at is None:
        current_row = shared._fetch_match_row(connection, match_id)
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
                match_duration_seconds = %(match_duration_seconds)s,
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
                "match_duration_seconds": shared._coerce_int(state.get("match_duration_seconds")),
                "status": status,
                "completed_at": effective_completed_at if state.get("match_complete") else None,
                "updated_at": now,
                "match_id": match_id,
            },
        )


def _append_event(connection, match_id, event_type, payload, source="api", state_override=None, completed_at=None):
    match_row = shared._fetch_match_row(connection, match_id)
    if not match_row:
        return None
    if match_row["status"] == "completed" and event_type not in {"match_ended", "timer"}:
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
                "created_at": shared._utcnow(),
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
                {"updated_at": shared._utcnow(), "match_id": match_id},
            )

    connection.commit()
    return get_match(connection, match_id)


def create_match(connection, payload, source="api"):
    match_id = str(uuid4())
    tenant_id = payload["tenant_id"]
    now = shared._utcnow()
    tenant_plan = shared._fetch_tenant_plan(connection, tenant_id)
    is_personal_tenant = shared._is_personal_tenant(tenant_id, tenant_plan)
    can_choose_shirt_colors = shared._can_choose_shirt_colors(tenant_plan, tenant_id)
    match_payload = {**payload}

    if is_personal_tenant:
        active_match = shared._find_active_match_for_tenant(connection, tenant_id)
        if active_match:
            raise ValueError("Personal accounts can only have one active match at a time")

        personal_court = shared._ensure_personal_match_court(connection, tenant_id)
        match_payload.update({
            "court_id": personal_court["id"],
            "court_name": personal_court.get("court_name") or "Personal Match",
            "court_alias": personal_court.get("court_alias") or personal_court.get("court_name") or "Personal Match",
            "referee_name": None,
        })

    best_of = _best_of_value(payload.get("best_of", 3))
    games_to_win = _games_to_win(best_of)
    score_type = _score_type_value(payload.get("score_type", 6))
    requested_status = "active" if is_personal_tenant else _match_status_value(payload.get("status"))
    conflicting_match = None
    match_status = requested_status
    player1_shirt_color = shared._shirt_color_value(
        match_payload.get("player1_shirt_color") if can_choose_shirt_colors else None,
        shared.DEFAULT_PLAYER_SHIRT_COLORS["player1"],
    )
    player2_shirt_color = shared._shirt_color_value(
        match_payload.get("player2_shirt_color") if can_choose_shirt_colors else None,
        shared.DEFAULT_PLAYER_SHIRT_COLORS["player2"],
    )

    if requested_status == "active" and not is_personal_tenant:
        conflicting_match = shared._find_active_match_on_court(
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
                player1_shirt_color,
                player2_name,
                player2_surname,
                player2_country,
                player2_handedness,
                player2_shirt_color,
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
                %(player1_shirt_color)s,
                %(player2_name)s,
                %(player2_surname)s,
                %(player2_country)s,
                %(player2_handedness)s,
                %(player2_shirt_color)s,
                %(referee_name)s,
                %(score_type)s,
                %(best_of)s,
                %(games_to_win)s,
                1,
                0,
                0,
                false,
                NULL,
                NULL,
                0,
                0,
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
                "sport": SPORT,
                "player1_name": match_payload["player1_name"],
                "player1_surname": match_payload.get("player1_surname"),
                "player1_country": match_payload.get("player1_country"),
                "player1_handedness": str(match_payload.get("player1_handedness") or "right").lower(),
                "player1_shirt_color": player1_shirt_color,
                "player2_name": match_payload["player2_name"],
                "player2_surname": match_payload.get("player2_surname"),
                "player2_country": match_payload.get("player2_country"),
                "player2_handedness": str(match_payload.get("player2_handedness") or "right").lower(),
                "player2_shirt_color": player2_shirt_color,
                "referee_name": match_payload.get("referee_name"),
                "score_type": score_type,
                "best_of": best_of,
                "games_to_win": games_to_win,
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

        player1_score_label, player2_score_label = _tennis_score_labels(0, 0, False)
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
                    "sport": SPORT,
                    "score_type": score_type,
                    "best_of": best_of,
                    "games_to_win": games_to_win,
                    "current_game_number": 1,
                    "player1_games_won": 0,
                    "player2_games_won": 0,
                    "player1_set_games": 0,
                    "player2_set_games": 0,
                    "current_server": match_payload["player1_name"],
                    "current_server_side": "player1",
                    "service_side": "Right",
                    "player1_shirt_color": player1_shirt_color,
                    "player2_shirt_color": player2_shirt_color,
                    "player1_score": 0,
                    "player2_score": 0,
                    "player1_score_label": player1_score_label,
                    "player2_score_label": player2_score_label,
                    "score_display_mode": "tennis",
                    "is_tie_break": False,
                    "tiebreak_first_server_side": None,
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
    match_row = shared._fetch_match_row(connection, match_id)
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
                "updated_at": shared._utcnow(),
            },
        )

    connection.commit()
    return get_match(connection, match_id)


def _prepare_scoring_transition(match, scorer_side, event_type, extra_payload=None):
    state = match["state"]
    if match["status"] == "completed" or state.get("match_complete"):
        raise ValueError("Match is already complete")

    current_set_number = state["current_game_number"]
    player1_score = state["player1_score"]
    player2_score = state["player2_score"]
    player1_set_games = state.get("player1_set_games", 0)
    player2_set_games = state.get("player2_set_games", 0)
    player1_sets_won = state["player1_games_won"]
    player2_sets_won = state["player2_games_won"]
    best_of = state["best_of"]
    sets_to_win = state["games_to_win"]
    score_type = state["score_type"]
    current_server_side = state.get("current_server_side") or "player1"
    tiebreak_first_server_side = state.get("tiebreak_first_server_side")
    is_tie_break = bool(state.get("is_tie_break"))

    if scorer_side == "player1":
        player1_score += 1
    else:
        player2_score += 1

    set_completed = False
    match_completed = False
    winner_side = None
    winner_name = None
    next_server_side = current_server_side
    next_service_side = _service_side_for_next_point(player1_score, player2_score)
    next_set_number = current_set_number
    next_tie_break = is_tie_break
    next_tiebreak_first_server_side = tiebreak_first_server_side
    set_result = None

    if is_tie_break:
        first_server_side = tiebreak_first_server_side or current_server_side
        if _is_tie_break_complete(player1_score, player2_score):
            set_completed = True
            winner_side = _winner_side(player1_score, player2_score)
            if winner_side == "player1":
                player1_set_games += 1
                player1_sets_won += 1
            else:
                player2_set_games += 1
                player2_sets_won += 1
            winner_name = _player_name(match, winner_side)
            set_result = {
                "game_number": current_set_number,
                "player1_score": player1_set_games,
                "player2_score": player2_set_games,
                "winner_side": winner_side,
                "winner_name": winner_name,
            }
            if player1_sets_won >= sets_to_win or player2_sets_won >= sets_to_win:
                match_completed = True
            else:
                next_set_number += 1
                player1_score = 0
                player2_score = 0
                player1_set_games = 0
                player2_set_games = 0
                next_tie_break = False
                next_tiebreak_first_server_side = None
                next_server_side = _opponent(first_server_side)
                next_service_side = "Right"
        else:
            next_server_side = _next_tie_break_server(first_server_side, player1_score, player2_score)
    else:
        if _is_regular_game_complete(player1_score, player2_score):
            game_winner_side = _winner_side(player1_score, player2_score)
            if game_winner_side == "player1":
                player1_set_games += 1
            else:
                player2_set_games += 1

            if _is_set_complete(player1_set_games, player2_set_games, score_type):
                set_completed = True
                winner_side = game_winner_side
                if winner_side == "player1":
                    player1_sets_won += 1
                else:
                    player2_sets_won += 1
                winner_name = _player_name(match, winner_side)
                set_result = {
                    "game_number": current_set_number,
                    "player1_score": player1_set_games,
                    "player2_score": player2_set_games,
                    "winner_side": winner_side,
                    "winner_name": winner_name,
                }
                if player1_sets_won >= sets_to_win or player2_sets_won >= sets_to_win:
                    match_completed = True
                else:
                    next_set_number += 1
                    player1_set_games = 0
                    player2_set_games = 0
                    player1_score = 0
                    player2_score = 0
                    next_server_side = _opponent(current_server_side)
                    next_service_side = "Right"
            elif _should_start_tie_break(player1_set_games, player2_set_games, score_type):
                player1_score = 0
                player2_score = 0
                next_tie_break = True
                next_tiebreak_first_server_side = _opponent(current_server_side)
                next_server_side = next_tiebreak_first_server_side
                next_service_side = "Right"
            else:
                player1_score = 0
                player2_score = 0
                next_server_side = _opponent(current_server_side)
                next_service_side = "Right"

    if not match_completed:
        winner_side = None
        winner_name = None

    player1_score_label, player2_score_label = _tennis_score_labels(player1_score, player2_score, next_tie_break)
    payload = {
        **(extra_payload or {}),
        "game_number": current_set_number,
        "current_game_number": next_set_number,
        "best_of": best_of,
        "games_to_win": sets_to_win,
        "score_type": score_type,
        "player1_score": player1_score,
        "player2_score": player2_score,
        "player1_games_won": player1_sets_won,
        "player2_games_won": player2_sets_won,
        "player1_set_games": player1_set_games,
        "player2_set_games": player2_set_games,
        "current_server": _player_name(match, next_server_side),
        "current_server_side": next_server_side,
        "service_side": next_service_side,
        "is_tie_break": next_tie_break,
        "tiebreak_first_server_side": next_tiebreak_first_server_side,
        "player1_score_label": player1_score_label,
        "player2_score_label": player2_score_label,
        "score_display_mode": "tennis",
        "game_completed": set_completed and not match_completed,
        "game_result": set_result,
        "match_completed": match_completed,
        "winner_side": winner_side if match_completed else None,
        "winner_name": winner_name if match_completed else None,
        "ended_early": False,
        "end_reason": None,
    }

    next_state = {
        **state,
        "player1_score": player1_score,
        "player2_score": player2_score,
        "player1_games_won": player1_sets_won,
        "player2_games_won": player2_sets_won,
        "current_game_number": next_set_number,
        "current_server": _player_name(match, next_server_side),
        "current_server_side": next_server_side,
        "service_side": next_service_side,
        "player1_set_games": player1_set_games,
        "player2_set_games": player2_set_games,
        "is_tie_break": next_tie_break,
        "tiebreak_first_server_side": next_tiebreak_first_server_side,
        "score_display_mode": "tennis",
        "player1_score_label": player1_score_label,
        "player2_score_label": player2_score_label,
        "match_complete": match_completed,
        "winner_side": winner_side if match_completed else None,
        "winner_name": winner_name if match_completed else None,
        "ended_early": False,
        "match_end_reason": None,
        "game_history": [
            *state["game_history"],
            *([set_result] if set_result else []),
        ],
    }

    return {
        "event_type": event_type,
        "payload": payload,
        "state": next_state,
    }


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
    completed_at = shared._utcnow() if transition["state"]["match_complete"] else None
    return _append_event(
        connection,
        match_id,
        transition["event_type"],
        transition["payload"],
        source=source,
        state_override=transition["state"],
        completed_at=completed_at,
    )


def _update_match_settings(connection, match_id, payload, source="api"):
    match = get_match(connection, match_id)
    if not match:
        return None

    if match["state"].get("match_complete") or match.get("status") == "completed":
        raise ValueError("Completed matches cannot be changed")

    score_type = shared._coerce_int(payload.get("score_type"), match["score_type"])
    best_of = shared._coerce_int(payload.get("best_of"), match["best_of"])
    if score_type not in VALID_SCORE_TYPE_OPTIONS:
        raise ValueError("score_type must be one of: 4, 6")
    if best_of not in VALID_BEST_OF_OPTIONS:
        raise ValueError("best_of must be one of: 1, 3, 5")

    games_to_win = _games_to_win(best_of)
    sets_already_won = max(
        shared._coerce_int(match["state"].get("player1_games_won")),
        shared._coerce_int(match["state"].get("player2_games_won")),
    )
    if sets_already_won >= games_to_win:
        raise ValueError("Match format cannot be lower than sets already won")

    set_games_played = max(
        shared._coerce_int(match["state"].get("player1_set_games")),
        shared._coerce_int(match["state"].get("player2_set_games")),
    )
    if set_games_played > score_type:
        raise ValueError("Game format cannot be lower than games already played in the current set")

    tenant_plan = shared._fetch_tenant_plan(connection, match["tenant_id"])
    includes_shirt_colors = "player1_shirt_color" in payload or "player2_shirt_color" in payload
    if includes_shirt_colors and not shared._can_choose_shirt_colors(tenant_plan, match["tenant_id"]):
        raise ValueError("Player shirt colors are not available on this plan")

    player1_shirt_color = shared._shirt_color_value(
        payload.get("player1_shirt_color"),
        match.get("player1_shirt_color") or shared.DEFAULT_PLAYER_SHIRT_COLORS["player1"],
    )
    player2_shirt_color = shared._shirt_color_value(
        payload.get("player2_shirt_color"),
        match.get("player2_shirt_color") or shared.DEFAULT_PLAYER_SHIRT_COLORS["player2"],
    )

    now = shared._utcnow()
    settings_payload = {
        "score_type": score_type,
        "best_of": best_of,
        "games_to_win": games_to_win,
        "player1_shirt_color": player1_shirt_color,
        "player2_shirt_color": player2_shirt_color,
        "previous_score_type": match["score_type"],
        "previous_best_of": match["best_of"],
        "previous_player1_shirt_color": match.get("player1_shirt_color"),
        "previous_player2_shirt_color": match.get("player2_shirt_color"),
    }

    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE matches
            SET score_type = %(score_type)s,
                best_of = %(best_of)s,
                games_to_win = %(games_to_win)s,
                player1_shirt_color = %(player1_shirt_color)s,
                player2_shirt_color = %(player2_shirt_color)s,
                updated_at = %(updated_at)s
            WHERE id = %(match_id)s
            """,
            {
                "score_type": score_type,
                "best_of": best_of,
                "games_to_win": games_to_win,
                "player1_shirt_color": player1_shirt_color,
                "player2_shirt_color": player2_shirt_color,
                "updated_at": now,
                "match_id": match_id,
            },
        )
        cursor.execute(
            """
            INSERT INTO match_events (id, match_id, tenant_id, event_type, payload, event_source, created_at)
            VALUES (%(id)s, %(match_id)s, %(tenant_id)s, 'match_settings', %(payload)s, %(event_source)s, %(created_at)s)
            """,
            {
                "id": str(uuid4()),
                "match_id": match_id,
                "tenant_id": match["tenant_id"],
                "payload": Jsonb(settings_payload),
                "event_source": source,
                "created_at": now,
            },
        )

    connection.commit()
    return get_match(connection, match_id)


def _record_match_duration(connection, match_id, payload, source="api"):
    match = get_match(connection, match_id)
    if not match:
        return None

    duration_seconds = shared._coerce_int(
        payload.get("match_duration_seconds"),
        match.get("match_duration_seconds") or match["state"].get("match_duration_seconds"),
    )
    state_override = {
        **match["state"],
        "match_duration_seconds": duration_seconds,
    }

    return _append_event(
        connection,
        match_id,
        "timer",
        {
            **payload,
            "match_duration_seconds": duration_seconds,
        },
        source=source,
        state_override=state_override,
    )


def event_action(connection, match_id, action_type, payload, source="api"):
    if action_type not in ALLOWED_ACTION_TYPES:
        raise ValueError(f"action_type must be one of: {', '.join(sorted(ALLOWED_ACTION_TYPES))}")

    if action_type == "match_settings":
        return _update_match_settings(connection, match_id, payload, source=source)

    if action_type == "timer":
        return _record_match_duration(connection, match_id, payload, source=source)

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
        completed_at = shared._utcnow() if transition["state"]["match_complete"] else None
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


def _match_leader(match_like, state):
    if state["player1_games_won"] > state["player2_games_won"]:
        return "player1", match_like["player1_name"]
    if state["player2_games_won"] > state["player1_games_won"]:
        return "player2", match_like["player2_name"]
    if state.get("player1_set_games", 0) > state.get("player2_set_games", 0):
        return "player1", match_like["player1_name"]
    if state.get("player2_set_games", 0) > state.get("player1_set_games", 0):
        return "player2", match_like["player2_name"]
    point_winner = _winner_side(state["player1_score"], state["player2_score"])
    return point_winner, _player_name(match_like, point_winner)


def end_match(connection, match_id, source="api", reason=None, ended_early=None, match_duration_seconds=None):
    match = get_match(connection, match_id)
    if not match:
        return None

    state = match["state"]
    winner_side, winner_name = _match_leader(match, state)
    final_ended_early = bool(ended_early) if ended_early is not None else not state.get("match_complete")
    final_reason = reason or ("Ended by operator" if final_ended_early else None)
    now = shared._utcnow()

    final_state = {
        **state,
        "match_complete": True,
        "winner_side": winner_side,
        "winner_name": winner_name,
        "ended_early": final_ended_early,
        "match_end_reason": final_reason,
        "match_duration_seconds": shared._coerce_int(
            match_duration_seconds,
            state.get("match_duration_seconds"),
        ),
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
        "player1_set_games": state.get("player1_set_games", 0),
        "player2_set_games": state.get("player2_set_games", 0),
        "current_game_number": state["current_game_number"],
        "is_tie_break": bool(state.get("is_tie_break")),
        "match_duration_seconds": shared._coerce_int(
            match_duration_seconds,
            state.get("match_duration_seconds"),
        ),
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
