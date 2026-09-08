from collections import defaultdict
from datetime import datetime, timedelta, timezone

from psycopg.errors import UndefinedTable

from common.match_logic import list_matches


PERSONAL_HISTORY_LIMITS = {
    "personal_free": 3,
}

PERSONAL_PLUS_ANALYTICS_MATCH_LIMIT = 1000


def _safe_list_matches(connection, organization_id, status, limit):
    try:
        return list_matches(
            connection,
            tenant_id=organization_id,
            status=status,
            limit=limit,
        )
    except UndefinedTable:
        connection.rollback()
        return []


def _history_limit_for_plan(org_type, plan, default_limit):
    if org_type == "personal":
        if plan == "personal_plus":
            return max(default_limit, 0)
        return PERSONAL_HISTORY_LIMITS["personal_free"]
    return default_limit


def _integer(value):
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return 0


def _percentage(numerator, denominator):
    if not denominator:
        return None
    return round((numerator / denominator) * 100, 1)


def _normalized_name(*parts):
    return " ".join(str(part or "").strip().lower() for part in parts if str(part or "").strip())


def _owner_side(match, owner_first_name, owner_surname):
    owner = _normalized_name(owner_first_name, owner_surname)
    if not owner:
        return None

    player1 = _normalized_name(match.get("player1_name"), match.get("player1_surname"))
    player2 = _normalized_name(match.get("player2_name"), match.get("player2_surname"))
    if owner == player1:
        return "player1"
    if owner == player2:
        return "player2"

    tennis_teams = ((match.get("state") or {}).get("tennis_teams") or {})
    for side in ("player1", "player2"):
        for participant in tennis_teams.get(side) or []:
            if owner == _normalized_name(participant.get("first_name"), participant.get("surname")):
                return side
    return None


def _opponent_name(match, opponent_side):
    participants = (((match.get("state") or {}).get("tennis_teams") or {}).get(opponent_side) or [])
    names = [
        " ".join(filter(None, [participant.get("first_name"), participant.get("surname")])).strip()
        for participant in participants
    ]
    names = [name for name in names if name]
    if names:
        return " / ".join(names)
    return " ".join(filter(None, [match.get(f"{opponent_side}_name"), match.get(f"{opponent_side}_surname")])).strip() or "Opponent"


def _match_datetime(match):
    value = match.get("completed_at") or match.get("updated_at") or match.get("created_at")
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if not value:
        return None
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None


def _period_summary(matches, now, period):
    if period == "week":
        start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        start -= timedelta(days=start.weekday())
    else:
        start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    selected = [item for item in matches if item["date"] and item["date"] >= start]
    wins = sum(1 for item in selected if item["won"])
    duration = sum(item["duration_seconds"] for item in selected)
    return {
        "matches_played": len(selected),
        "matches_won": wins,
        "matches_lost": len(selected) - wins,
        "win_percentage": _percentage(wins, len(selected)),
        "playing_time_seconds": duration,
    }


def build_personal_performance(matches, owner_first_name, owner_surname, now=None):
    """Build Personal Plus statistics from the retained, authoritative event log.

    Matches where the registered account holder cannot be matched exactly to a
    participant are excluded and reported as unclassified.
    """
    now = now or datetime.now(timezone.utc)
    classified = []
    opponents = defaultdict(lambda: {"matches_played": 0, "won": 0, "lost": 0})
    sports = defaultdict(lambda: {"matches_played": 0, "won": 0, "lost": 0, "playing_time_seconds": 0})
    scorelines = defaultdict(int)
    games_won = games_lost = points_won = points_lost = 0
    close_games_played = close_games_won = 0
    service_points_won = service_points_lost = 0

    chronological = []
    for match in matches:
        owner_side = _owner_side(match, owner_first_name, owner_surname)
        if owner_side is None:
            continue
        opponent_side = "player2" if owner_side == "player1" else "player1"
        state = match.get("state") or {}
        winner_side = match.get("winner_side") or state.get("winner_side")
        won = winner_side == owner_side
        match_date = _match_datetime(match)
        duration_seconds = _integer(match.get("match_duration_seconds") or state.get("match_duration_seconds"))
        sport = str(match.get("sport") or "squash").replace("_", " ").title()
        opponent_name = _opponent_name(match, opponent_side)

        entry = {"date": match_date, "won": won, "sport": sport, "duration_seconds": duration_seconds}
        classified.append(entry)
        chronological.append(entry)
        opponents[opponent_name]["matches_played"] += 1
        opponents[opponent_name]["won" if won else "lost"] += 1
        sports[sport]["matches_played"] += 1
        sports[sport]["won" if won else "lost"] += 1
        sports[sport]["playing_time_seconds"] += duration_seconds

        game_history = state.get("game_history") or []
        if str(match.get("sport") or "").lower() == "tennis":
            owner_games = sum(_integer(game.get(f"{owner_side}_score")) for game in game_history)
            opponent_games = sum(_integer(game.get(f"{opponent_side}_score")) for game in game_history)
        else:
            owner_games = _integer(state.get(f"{owner_side}_games_won") or match.get(f"{owner_side}_games_won"))
            opponent_games = _integer(state.get(f"{opponent_side}_games_won") or match.get(f"{opponent_side}_games_won"))
        games_won += owner_games
        games_lost += opponent_games
        if won:
            scorelines[f"{owner_games}-{opponent_games}"] += 1

        for game in game_history:
            owner_score = _integer(game.get(f"{owner_side}_score"))
            opponent_score = _integer(game.get(f"{opponent_side}_score"))
            if abs(owner_score - opponent_score) <= 2:
                close_games_played += 1
                if owner_score > opponent_score:
                    close_games_won += 1

        current_server_side = "player1"
        for event in state.get("events") or []:
            payload = event.get("payload") or {}
            event_type = event.get("event_type")
            if event_type in {"match_created", "server_selected"}:
                current_server_side = payload.get("current_server_side") or current_server_side
                continue
            if event_type not in {"score_point", "stroke"}:
                if payload.get("current_server_side") in {"player1", "player2"}:
                    current_server_side = payload["current_server_side"]
                continue
            scorer = payload.get("scorer") or payload.get("player_side")
            if scorer == owner_side:
                points_won += 1
            elif scorer == opponent_side:
                points_lost += 1
            if current_server_side == owner_side:
                if scorer == owner_side:
                    service_points_won += 1
                elif scorer == opponent_side:
                    service_points_lost += 1
            current_server_side = payload.get("current_server_side") or current_server_side

    chronological.sort(key=lambda item: item["date"] or datetime.min.replace(tzinfo=timezone.utc))
    current_streak = best_streak = running_streak = 0
    for item in chronological:
        running_streak = running_streak + 1 if item["won"] else 0
        best_streak = max(best_streak, running_streak)
    if chronological:
        for item in reversed(chronological):
            if not item["won"]:
                break
            current_streak += 1

    current_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    previous_month_end = current_month - timedelta(microseconds=1)
    previous_month = previous_month_end.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    monthly_improvement = []
    for sport_name, sport_items in sorted(((name, [item for item in classified if item["sport"] == name]) for name in sports), key=lambda pair: pair[0]):
        current_items = [item for item in sport_items if item["date"] and item["date"] >= current_month]
        previous_items = [item for item in sport_items if item["date"] and previous_month <= item["date"] < current_month]
        current_rate = _percentage(sum(item["won"] for item in current_items), len(current_items))
        previous_rate = _percentage(sum(item["won"] for item in previous_items), len(previous_items))
        monthly_improvement.append({
            "sport": sport_name,
            "current_month_matches": len(current_items),
            "current_month_win_percentage": current_rate,
            "previous_month_matches": len(previous_items),
            "previous_month_win_percentage": previous_rate,
            "percentage_point_change": round(current_rate - previous_rate, 1) if current_rate is not None and previous_rate is not None else None,
        })

    matches_won = sum(1 for item in classified if item["won"])
    return {
        "classified_match_count": len(classified),
        "unclassified_match_count": max(0, len(matches) - len(classified)),
        "matches_played": len(classified),
        "matches_won": matches_won,
        "matches_lost": len(classified) - matches_won,
        "win_percentage": _percentage(matches_won, len(classified)),
        "games_won": games_won,
        "games_lost": games_lost,
        "game_win_percentage": _percentage(games_won, games_won + games_lost),
        "points_won": points_won,
        "points_lost": points_lost,
        "point_win_percentage": _percentage(points_won, points_won + points_lost),
        "playing_time_seconds": sum(item["duration_seconds"] for item in classified),
        "close_games_played": close_games_played,
        "close_games_won": close_games_won,
        "close_game_win_percentage": _percentage(close_games_won, close_games_played),
        "service_points_won": service_points_won,
        "service_points_lost": service_points_lost,
        "service_point_win_percentage": _percentage(service_points_won, service_points_won + service_points_lost),
        "current_win_streak": current_streak,
        "best_win_streak": best_streak,
        "scoreline_wins": [{"scoreline": key, "count": value} for key, value in sorted(scorelines.items())],
        "opponents": [{"name": name, **values, "win_percentage": _percentage(values["won"], values["matches_played"])} for name, values in sorted(opponents.items())],
        "sports": [{"sport": name, **values, "win_percentage": _percentage(values["won"], values["matches_played"])} for name, values in sorted(sports.items())],
        "monthly_improvement": monthly_improvement,
        "weekly_summary": _period_summary(classified, now, "week"),
        "monthly_summary": _period_summary(classified, now, "month"),
    }


def _locked_history_preview(match):
    return {
        "id": "locked-history-preview",
        "status": "locked",
        "sport": match.get("sport"),
        "player1_name": "Locked",
        "player1_surname": None,
        "player2_name": "Match",
        "player2_surname": None,
        "court_name": None,
        "best_of": None,
        "score_type": None,
        "match_duration_seconds": None,
        "winner_name": None,
        "state": None,
        "updated_at": match.get("updated_at"),
        "completed_at": match.get("completed_at"),
        "locked": True,
    }


def personal_free_can_access_completed_match(connection, organization_id, match_id):
    """Prevent a known match URL from bypassing the Personal Free history limit."""
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT EXISTS (
                SELECT 1
                FROM (
                    SELECT id
                    FROM matches
                    WHERE tenant_id = %(organization_id)s
                      AND status = 'completed'
                      AND COALESCE(is_archived, false) = false
                    ORDER BY COALESCE(completed_at, updated_at) DESC, updated_at DESC
                    LIMIT %(history_limit)s
                ) AS available_history
                WHERE id = %(match_id)s
            ) AS is_available
            """,
            {
                "organization_id": int(organization_id),
                "match_id": match_id,
                "history_limit": PERSONAL_HISTORY_LIMITS["personal_free"],
            },
        )
        return bool((cursor.fetchone() or {}).get("is_available"))


def get_dashboard_data(connection, organization_id, active_limit=12, recent_limit=12):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id, organization_name, org_type, plan
            FROM "SkwshOrgSettings"
            WHERE id = %(organization_id)s
            LIMIT 1
            """,
            {"organization_id": int(organization_id)},
        )
        organization_row = cursor.fetchone()

    org_type = (organization_row or {}).get("org_type") or "club"
    plan = (organization_row or {}).get("plan") or ("personal_free" if org_type == "personal" else "club_essentials")
    history_limit = _history_limit_for_plan(org_type, plan, recent_limit)

    active_matches = []
    if active_limit and active_limit > 0:
        active_matches = _safe_list_matches(
            connection,
            organization_id=organization_id,
            status="active",
            limit=active_limit,
        )
    scheduled_matches = []
    if org_type != "personal" and active_limit and active_limit > 0:
        scheduled_matches = _safe_list_matches(
            connection,
            organization_id=organization_id,
            status="scheduled",
            limit=active_limit,
        )
    completed_match_count = 0
    analytics_matches = []
    if org_type == "personal":
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT COUNT(*) AS completed_match_count
                FROM matches
                WHERE tenant_id = %(organization_id)s
                  AND status = 'completed'
                  AND COALESCE(is_archived, false) = false
                """,
                {"organization_id": int(organization_id)},
            )
            completed_match_count = (cursor.fetchone() or {}).get("completed_match_count", 0)

    recent_matches = []
    fetch_limit = history_limit
    if org_type == "personal" and plan == "personal_free" and completed_match_count > history_limit:
        fetch_limit = history_limit + 1
    if fetch_limit and fetch_limit > 0:
        recent_matches = _safe_list_matches(
            connection,
            organization_id=organization_id,
            status="completed",
            limit=fetch_limit,
        )

    if org_type == "personal" and plan == "personal_free" and len(recent_matches) > history_limit:
        recent_matches = [*recent_matches[:history_limit], _locked_history_preview(recent_matches[history_limit])]

    performance = None
    if org_type == "personal" and plan == "personal_plus":
        analytics_matches = _safe_list_matches(
            connection,
            organization_id=organization_id,
            status="completed",
            limit=PERSONAL_PLUS_ANALYTICS_MATCH_LIMIT,
        )
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT first_name, surname
                FROM "SkwshOrgUsers"
                WHERE organization_id = %(organization_id)s
                ORDER BY id ASC
                LIMIT 1
                """,
                {"organization_id": int(organization_id)},
            )
            owner_row = cursor.fetchone() or {}
        performance = build_personal_performance(
            analytics_matches,
            owner_row.get("first_name"),
            owner_row.get("surname"),
        )

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT COUNT(*) AS court_count
            FROM "SkwshCourts"
            WHERE organization_name = %(organization_id)s
            """,
            {"organization_id": int(organization_id)},
        )
        courts_row = cursor.fetchone()

        cursor.execute(
            """
            SELECT COUNT(*) AS user_count,
                   ARRAY_REMOVE(ARRAY_AGG(DISTINCT role), NULL) AS roles
            FROM "SkwshOrgUsers"
            WHERE organization_id = %(organization_id)s
            """,
            {"organization_id": int(organization_id)},
        )
        users_row = cursor.fetchone()

    return {
        "organization": {
            "id": int(organization_id),
            "name": (organization_row or {}).get("organization_name"),
            "type": org_type,
            "plan": plan,
            "history_limit": history_limit,
            "completed_match_count": completed_match_count,
            "locked_history_count": max(0, completed_match_count - history_limit) if plan == "personal_free" else 0,
            "court_count": (courts_row or {}).get("court_count", 0),
            "user_count": (users_row or {}).get("user_count", 0),
            "roles": (users_row or {}).get("roles") or [],
        },
        "active_matches": active_matches,
        "scheduled_matches": scheduled_matches,
        "recent_matches": recent_matches,
        "performance": performance,
    }
