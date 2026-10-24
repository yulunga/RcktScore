from common import tennis_match_logic as shared


SPORT = "padel"


def create_match(connection, payload, source="api"):
    match_payload = {
        **payload,
        "sport": SPORT,
        "team_format": "doubles",
        "score_type": payload.get("score_type", 6),
        "best_of": payload.get("best_of", 3),
    }
    missing_partner_fields = [
        field
        for field in ("team1_player2_name", "team2_player2_name")
        if not str(match_payload.get(field) or "").strip()
    ]
    if missing_partner_fields:
        raise ValueError("Padel requires two named players on each team")
    return shared.create_match(connection, match_payload, source=source)


def score_point(connection, match_id, scorer, source="api", commit=True):
    return shared.score_point(connection, match_id, scorer, source=source, commit=commit)


def event_action(connection, match_id, action_type, payload, source="api", commit=True):
    return shared.event_action(connection, match_id, action_type, payload, source=source, commit=commit)


def undo_last_action(
    connection,
    match_id,
    source="api",
    actor_username=None,
    commit=True,
):
    return shared.undo_last_action(
        connection,
        match_id,
        source=source,
        actor_username=actor_username,
        commit=commit,
    )


def end_match(
    connection,
    match_id,
    source="api",
    reason=None,
    ended_early=None,
    match_duration_seconds=None,
    commit=True,
):
    return shared.end_match(
        connection,
        match_id,
        source=source,
        reason=reason,
        ended_early=ended_early,
        match_duration_seconds=match_duration_seconds,
        commit=commit,
    )


def activate_scheduled_match(connection, match_id, commit=True):
    return shared.activate_scheduled_match(connection, match_id, commit=commit)


def serialize_match(match_row, event_rows):
    return shared.serialize_match(match_row, event_rows)
