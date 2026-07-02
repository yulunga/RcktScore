from common import squash_match_logic as squash_logic
from common.sport_engine_registry import normalize_sport, resolve_engine_module
from common.sport_config import SPORT_LABELS, fetch_enabled_sports


def _fetch_match_row(connection, match_id):
    return squash_logic._fetch_match_row(connection, match_id)


def _fetch_match_events(connection, match_id):
    return squash_logic._fetch_match_events(connection, match_id)


def _serialize_match_row(connection, match_row):
    if not match_row:
        return None

    engine = resolve_engine_module(match_row.get("sport"))
    return engine.serialize_match(match_row, _fetch_match_events(connection, match_row["id"]))


def _resolve_engine_for_match_id(connection, match_id):
    match_row = _fetch_match_row(connection, match_id)
    if not match_row:
        return None, None

    return resolve_engine_module(match_row.get("sport")), match_row


def _auto_end_stale_active_matches(connection, tenant_id=None, match_id=None):
    where_clauses = ["matches.status = 'active'"]
    params = {"cutoff": squash_logic._utcnow()}

    if tenant_id is not None:
        where_clauses.append("matches.tenant_id = %(tenant_id)s")
        params["tenant_id"] = tenant_id
    if match_id is not None:
        where_clauses.append("matches.id = %(match_id)s")
        params["match_id"] = match_id

    inactivity_expression = f"INTERVAL '{squash_logic.STALE_ACTIVE_MATCH_HOURS} hours'"

    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            SELECT matches.id
            FROM matches
            LEFT JOIN LATERAL (
                SELECT MAX(created_at) AS latest_activity_at
                FROM match_events
                WHERE match_id = matches.id
                  AND event_type = ANY(%(activity_event_types)s)
            ) activity ON TRUE
            WHERE {' AND '.join(where_clauses)}
              AND COALESCE(activity.latest_activity_at, matches.updated_at, matches.created_at)
                    <= (%(cutoff)s - {inactivity_expression})
            """,
            {
                **params,
                "activity_event_types": list(squash_logic.STALE_ACTIVITY_EVENT_TYPES),
            },
        )
        stale_match_ids = [row["id"] for row in cursor.fetchall()]

    for stale_match_id in stale_match_ids:
        end_match(
            connection,
            stale_match_id,
            source="system",
            reason=(
                "Automatically ended after "
                f"{squash_logic.STALE_ACTIVE_MATCH_HOURS} hours without match activity"
            ),
            ended_early=True,
        )


def get_match(connection, match_id, close_stale=True):
    if close_stale:
        _auto_end_stale_active_matches(connection, match_id=match_id)

    return _serialize_match_row(connection, _fetch_match_row(connection, match_id))


def get_active_match_for_court(connection, tenant_id, court_id):
    _auto_end_stale_active_matches(connection, tenant_id=tenant_id)
    return _serialize_match_row(
        connection,
        squash_logic._find_active_match_on_court(connection, tenant_id, court_id),
    )


def list_matches(connection, tenant_id, status=None, limit=10):
    if status == "active":
        _auto_end_stale_active_matches(connection, tenant_id=tenant_id)

    query = [
        """
        SELECT
            matches.*,
            court.display_code AS court_display_code
        FROM matches
        LEFT JOIN "SkwshCourts" AS court
            ON court.id = matches.court_id
        WHERE tenant_id = %(tenant_id)s
        """
    ]
    params = {"tenant_id": tenant_id, "limit": limit}

    if status:
        query.append("AND status = %(status)s")
        params["status"] = status

    query.append(squash_logic._match_order_clause_for_status(status))

    with connection.cursor() as cursor:
        cursor.execute("\n".join(query), params)
        match_rows = cursor.fetchall()

    return [_serialize_match_row(connection, match_row) for match_row in match_rows]


def create_match(connection, payload, source="api"):
    normalized_sport = normalize_sport(payload.get("sport"))
    enabled_sports = fetch_enabled_sports(connection, payload.get("tenant_id"))
    if normalized_sport not in enabled_sports:
        sport_label = SPORT_LABELS.get(normalized_sport, normalized_sport.replace("_", " ").title())
        raise ValueError(f"{sport_label} is not enabled for this account or club")
    engine = resolve_engine_module(normalized_sport)
    return engine.create_match(
        connection,
        {
            **payload,
            "sport": normalized_sport,
        },
        source=source,
    )


def activate_scheduled_match(connection, match_id):
    engine, _ = _resolve_engine_for_match_id(connection, match_id)
    if engine is None:
        return None
    return engine.activate_scheduled_match(connection, match_id)


def score_point(connection, match_id, scorer, source="api"):
    engine, _ = _resolve_engine_for_match_id(connection, match_id)
    if engine is None:
        return None
    return engine.score_point(connection, match_id, scorer, source=source)


def event_action(connection, match_id, action_type, payload, source="api"):
    engine, _ = _resolve_engine_for_match_id(connection, match_id)
    if engine is None:
        return None
    return engine.event_action(connection, match_id, action_type, payload, source=source)


def undo_last_action(connection, match_id):
    engine, _ = _resolve_engine_for_match_id(connection, match_id)
    if engine is None:
        return None
    return engine.undo_last_action(connection, match_id)


def end_match(connection, match_id, source="api", reason=None, ended_early=None, match_duration_seconds=None):
    engine, _ = _resolve_engine_for_match_id(connection, match_id)
    if engine is None:
        return None
    return engine.end_match(
        connection,
        match_id,
        source=source,
        reason=reason,
        ended_early=ended_early,
        match_duration_seconds=match_duration_seconds,
    )


def is_personal_tenant(connection, tenant_id):
    return squash_logic.is_personal_tenant(connection, tenant_id)


def websocket_payload(match):
    return squash_logic.websocket_payload(match)
