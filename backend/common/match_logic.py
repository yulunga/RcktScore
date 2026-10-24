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


def _lock_match_for_mutation(connection, match_id):
    """Serialize every state-derived mutation for one match.

    The lock must be acquired before an engine rebuilds state from match_events.
    Locking later in _append_event would still allow two callers to calculate
    transitions from the same stale event history.
    """
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT matches.id,
                   matches.sport,
                   matches.status,
                   (
                       matches.status = 'active'
                       AND COALESCE(
                           (
                               SELECT MAX(match_events.created_at)
                               FROM match_events
                               WHERE match_events.match_id = matches.id
                                 AND match_events.event_type = ANY(%(activity_event_types)s)
                           ),
                           matches.updated_at,
                           matches.created_at
                       ) <= (%(cutoff)s - (%(stale_hours)s * INTERVAL '1 hour'))
                   ) AS is_stale
            FROM matches
            WHERE matches.id = %(match_id)s
              AND COALESCE(matches.is_archived, false) = false
            FOR UPDATE OF matches
            """,
            {
                "match_id": match_id,
                "activity_event_types": list(squash_logic.STALE_ACTIVITY_EVENT_TYPES),
                "cutoff": squash_logic._utcnow(),
                "stale_hours": squash_logic.STALE_ACTIVE_MATCH_HOURS,
            },
        )
        return cursor.fetchone()


def _run_match_mutation(
    connection,
    match_id,
    operation,
    sync_tournament=False,
    resolve_early_tournament=False,
    auto_end_stale=True,
):
    """Run a match mutation and its derived writes in one transaction."""
    transaction_committed = False
    try:
        match_row = _lock_match_for_mutation(connection, match_id)
        if not match_row:
            connection.rollback()
            return None

        engine = resolve_engine_module(match_row.get("sport"))
        if auto_end_stale and match_row.get("is_stale"):
            stale_match = engine.end_match(
                connection,
                match_id,
                source="system",
                reason=(
                    "Automatically ended after "
                    f"{squash_logic.STALE_ACTIVE_MATCH_HOURS} hours without match activity"
                ),
                ended_early=True,
                commit=False,
            )
            if stale_match and stale_match.get("tournament_match_id"):
                from common.tournament.tournament_logic import mark_tournament_match_awaiting_resolution
                mark_tournament_match_awaiting_resolution(connection, stale_match, commit=False)
            connection.commit()
            transaction_committed = True
            raise ValueError("Match is already complete")

        match = operation(engine)
        if sync_tournament and match and match.get("status") == "completed" and match.get("tournament_match_id"):
            from common.tournament.tournament_logic import sync_tournament_scoring_result
            sync_tournament_scoring_result(
                connection,
                match,
                natural_completion=True,
                commit=False,
            )
        elif resolve_early_tournament and match and match.get("tournament_match_id"):
            from common.tournament.tournament_logic import mark_tournament_match_awaiting_resolution
            mark_tournament_match_awaiting_resolution(connection, match, commit=False)

        connection.commit()
        transaction_committed = True
        return match
    except Exception:
        if not transaction_committed:
            connection.rollback()
        raise


def _auto_end_stale_active_matches(connection, tenant_id=None, match_id=None):
    where_clauses = [
        "matches.status = 'active'",
        "COALESCE(matches.is_archived, false) = false",
    ]
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
          AND COALESCE(matches.is_archived, false) = false
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
    court_id = payload.get("court_id")
    if court_id:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, court_name, court_alias, sport
                FROM "SkwshCourts"
                WHERE id = %(court_id)s
                  AND organization_name = %(organization_id)s
                LIMIT 1
                """,
                {
                    "court_id": int(court_id),
                    "organization_id": int(payload.get("tenant_id")),
                },
            )
            court = cursor.fetchone()
        if not court:
            raise ValueError("The selected court does not belong to this account or club")
        if court.get("sport") and court["sport"] != normalized_sport:
            court_sport = SPORT_LABELS.get(court["sport"], str(court["sport"]).replace("_", " ").title())
            raise ValueError(f"The selected court is configured for {court_sport}")
        payload = {
            **payload,
            "court_name": court.get("court_name") or payload.get("court_name"),
            "court_alias": court.get("court_alias"),
        }
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
    return _run_match_mutation(
        connection,
        match_id,
        lambda engine: engine.activate_scheduled_match(connection, match_id, commit=False),
    )


def score_point(connection, match_id, scorer, source="api"):
    return _run_match_mutation(
        connection,
        match_id,
        lambda engine: engine.score_point(connection, match_id, scorer, source=source, commit=False),
        sync_tournament=True,
    )


def event_action(connection, match_id, action_type, payload, source="api"):
    return _run_match_mutation(
        connection,
        match_id,
        lambda engine: engine.event_action(
            connection,
            match_id,
            action_type,
            payload,
            source=source,
            commit=False,
        ),
        sync_tournament=action_type == "stroke",
    )


def undo_last_action(connection, match_id):
    def undo(engine):
        engine_get_match = getattr(engine, "get_match", None)
        current_match = (
            engine_get_match(connection, match_id)
            if engine_get_match
            else _serialize_match_row(connection, _fetch_match_row(connection, match_id))
        )
        if (
            current_match
            and current_match.get("tournament_match_id")
            and current_match.get("status") == "completed"
        ):
            raise ValueError(
                "A completed tournament result cannot be undone after bracket progression"
            )
        return engine.undo_last_action(connection, match_id, commit=False)

    return _run_match_mutation(
        connection,
        match_id,
        undo,
    )


def end_match(connection, match_id, source="api", reason=None, ended_early=None, match_duration_seconds=None):
    return _run_match_mutation(
        connection,
        match_id,
        lambda engine: engine.end_match(
            connection,
            match_id,
            source=source,
            reason=reason,
            ended_early=ended_early,
            match_duration_seconds=match_duration_seconds,
            commit=False,
        ),
        resolve_early_tournament=True,
        auto_end_stale=False,
    )


def is_personal_tenant(connection, tenant_id):
    return squash_logic.is_personal_tenant(connection, tenant_id)


def websocket_payload(match):
    return squash_logic.websocket_payload(match)
