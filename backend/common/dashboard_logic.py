from collections import defaultdict
from datetime import datetime, timedelta, timezone

from psycopg.errors import UndefinedTable

from common.match_logic import list_matches
from common.plan_entitlements import PERSONAL_PLAN_ENTITLEMENTS, personal_plan_contract, personal_plan_entitlements


PERSONAL_HISTORY_LIMITS = {
    plan: values["history_limit"] for plan, values in PERSONAL_PLAN_ENTITLEMENTS.items()
}


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
        contract_limit = personal_plan_entitlements(plan)["history_limit"]
        if default_limit <= 0:
            return 0
        return min(default_limit, contract_limit)
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


def build_app_analytics(connection, organization_id, period_days=30):
    """Return organisation-wide match activity for the requested rolling period."""
    params = {
        "organization_id": int(organization_id),
        "period_days": max(0, int(period_days or 0)),
    }
    period_filter = ""
    if params["period_days"]:
        period_filter = "AND created_at >= CURRENT_TIMESTAMP - (%(period_days)s * INTERVAL '1 day')"

    try:
        with connection.cursor() as cursor:
            cursor.execute(
                f"""
                SELECT LOWER(COALESCE(sport, 'squash')) AS sport,
                       status,
                       COUNT(*) AS match_count
                FROM matches
                WHERE tenant_id = %(organization_id)s
                  AND COALESCE(is_archived, false) = false
                  {period_filter}
                GROUP BY LOWER(COALESCE(sport, 'squash')), status
                """,
                params,
            )
            rows = cursor.fetchall() or []
    except UndefinedTable:
        connection.rollback()
        rows = []

    by_sport = {sport: 0 for sport in ("squash", "racketball", "tennis", "padel")}
    total_matches = completed_matches = uncompleted_started_matches = 0
    for row in rows:
        count = _integer(row.get("match_count"))
        sport = str(row.get("sport") or "squash").lower()
        status = str(row.get("status") or "").lower()
        total_matches += count
        by_sport[sport] = by_sport.get(sport, 0) + count
        if status == "completed":
            completed_matches += count
        elif status == "active":
            uncompleted_started_matches += count

    started_matches = completed_matches + uncompleted_started_matches
    return {
        "period_days": params["period_days"],
        "matches_scored": total_matches,
        "matches_by_sport": [
            {"sport": sport, "count": by_sport.get(sport, 0)}
            for sport in ("squash", "racketball", "tennis", "padel")
        ],
        "completed_matches": completed_matches,
        "completed_match_rate": _percentage(completed_matches, total_matches),
        "uncompleted_started_matches": uncompleted_started_matches,
        "abandoned_match_rate": _percentage(uncompleted_started_matches, started_matches),
    }


def _analytics_datetime(value):
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if not value:
        return None
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None


def _analytics_name(first_name, surname=None):
    return " ".join(part for part in [str(first_name or "").strip(), str(surname or "").strip()] if part).strip()


def _fetch_analytics_records(connection, organization_id, period_days):
    params = {
        "organization_id": int(organization_id),
        "period_days": max(0, int(period_days or 0)),
    }
    period_filter = ""
    if params["period_days"]:
        period_filter = "AND matches.created_at >= CURRENT_TIMESTAMP - (%(period_days)s * INTERVAL '1 day')"
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                f"""
                SELECT matches.id,
                       matches.court_id,
                       matches.court_name,
                       matches.sport,
                       matches.player1_name,
                       matches.player1_surname,
                       matches.player2_name,
                       matches.player2_surname,
                       matches.score_type,
                       matches.best_of,
                       matches.games_to_win,
                       matches.player1_games_won,
                       matches.player2_games_won,
                       matches.handicap_enabled,
                       matches.winner_side,
                       matches.ended_early,
                       matches.match_duration_seconds,
                       matches.status,
                       matches.created_at,
                       matches.completed_at,
                       matches.updated_at,
                       COALESCE(
                           JSONB_AGG(
                               JSONB_BUILD_OBJECT(
                                   'event_type', events.event_type,
                                   'payload', events.payload,
                                   'event_source', events.event_source,
                                   'created_at', events.created_at
                               ) ORDER BY events.created_at, events.id
                           ) FILTER (WHERE events.id IS NOT NULL),
                           '[]'::jsonb
                       ) AS events
                FROM matches
                LEFT JOIN match_events AS events ON events.match_id = matches.id
                WHERE matches.tenant_id = %(organization_id)s
                  AND COALESCE(matches.is_archived, false) = false
                  {period_filter}
                GROUP BY matches.id
                ORDER BY matches.created_at ASC
                """,
                params,
            )
            return cursor.fetchall() or []
    except UndefinedTable:
        connection.rollback()
        return []


def build_extended_app_analytics(records, period_days=30):
    """Derive match, format, duration, scoring and returning-use analytics."""
    sports = ("squash", "racketball", "tennis", "padel")
    by_sport = {sport: 0 for sport in sports}
    duration_buckets = {"under_30": 0, "30_60": 0, "60_90": 0, "over_90": 0}
    heatmap = {(day, hour): 0 for day in range(7) for hour in range(24)}
    month_counts = defaultdict(int)
    monthly_sport_counts = defaultdict(int)
    active_days = set()
    active_weeks = set()
    formats = defaultdict(int)
    platform_counts = {"web": 0, "ios": 0, "unattributed": 0}
    participant_counts = defaultdict(int)
    option_counts = defaultdict(int)
    sport_structures = defaultdict(lambda: {"matches": 0, "units": 0, "points": 0})
    completed = []
    longest_unit = None
    close_matches = extra_point_matches = comeback_matches = 0
    total_points = 0

    for record in records:
        sport = str(record.get("sport") or "squash").lower()
        by_sport[sport] = by_sport.get(sport, 0) + 1
        created_at = _analytics_datetime(record.get("created_at"))
        if created_at:
            heatmap[(created_at.weekday(), created_at.hour)] += 1
            month_counts[created_at.strftime("%Y-%m")] += 1
            monthly_sport_counts[(created_at.strftime("%Y-%m"), sport)] += 1
            active_days.add(created_at.date().isoformat())
            iso_year, iso_week, _ = created_at.isocalendar()
            active_weeks.add(f"{iso_year}-W{iso_week:02d}")

        formats[f"Best of {_integer(record.get('best_of')) or 1}"] += 1
        events = record.get("events") or []
        start_payload = next((event.get("payload") or {} for event in events if event.get("event_type") == "match_started"), {})
        option_counts["timed_break_eligible"] += 1
        option_counts["timed_break_used"] += int(bool(start_payload.get("tennis_timed_breaks")))
        option_counts["golden_point_eligible"] += int(sport in sports)
        option_counts["golden_point_used"] += int(bool(start_payload.get("tennis_no_ad_scoring")))
        option_counts["handicap_eligible"] += int(sport in {"squash", "racketball"})
        option_counts["handicap_used"] += int(bool(record.get("handicap_enabled")))
        option_counts["final_tiebreak_eligible"] += int(sport in {"tennis", "padel"})
        option_counts["final_tiebreak_used"] += int(bool(start_payload.get("tennis_final_set_match_tiebreak")))

        source = str(next((event.get("event_source") for event in events if event.get("event_type") == "match_started"), "") or "").lower()
        if source in {"web", "web_app", "browser"}:
            platform_counts["web"] += 1
        elif source in {"ios", "ios_app", "mobile", "mobile_app"}:
            platform_counts["ios"] += 1
        else:
            platform_counts["unattributed"] += 1

        participant_names = [
            _analytics_name(record.get("player1_name"), record.get("player1_surname")),
            _analytics_name(record.get("player2_name"), record.get("player2_surname")),
        ]
        for team in (start_payload.get("tennis_teams") or {}).values():
            for participant in team or []:
                participant_names.append(_analytics_name(participant.get("first_name"), participant.get("surname")))
        for name in {name.casefold(): name for name in participant_names if name}:
            participant_counts[name] += 1

        point_events = [event for event in events if event.get("event_type") in {"score_point", "stroke"}]
        total_points += len(point_events)
        structure = sport_structures[sport]
        structure["matches"] += 1
        structure["points"] += len(point_events)
        unit_events = []
        previous_boundary = created_at
        first_unit_winner = None
        match_has_extra_points = False
        for event in point_events:
            payload = event.get("payload") or {}
            game_result = payload.get("game_result")
            unit_completed = bool(game_result) if sport in {"squash", "racketball"} else bool(payload.get("set_completed"))
            if unit_completed:
                unit_events.append(event)
                if first_unit_winner is None and game_result:
                    first_unit_winner = game_result.get("winner_side")
                event_time = _analytics_datetime(event.get("created_at"))
                if event_time and previous_boundary:
                    unit_seconds = max(0, int((event_time - previous_boundary).total_seconds()))
                    if longest_unit is None or unit_seconds > longest_unit["duration_seconds"]:
                        longest_unit = {"duration_seconds": unit_seconds, "sport": sport, "match_id": str(record.get("id"))}
                    previous_boundary = event_time
            if sport in {"squash", "racketball"} and game_result:
                high_score = max(_integer(game_result.get("player1_score")), _integer(game_result.get("player2_score")))
                if high_score > _integer(record.get("score_type")):
                    match_has_extra_points = True
            if sport in {"tennis", "padel"}:
                high_tiebreak = max(_integer((game_result or {}).get("player1_tiebreak_score")), _integer((game_result or {}).get("player2_tiebreak_score")))
                if high_tiebreak > (10 if (game_result or {}).get("is_match_tiebreak") else 7):
                    match_has_extra_points = True
        structure["units"] += len(unit_events)
        if record.get("status") == "completed":
            duration_seconds = _integer(record.get("match_duration_seconds"))
            completed.append({"id": str(record.get("id")), "duration_seconds": duration_seconds, "sport": sport})
            if duration_seconds > 0:
                minutes = duration_seconds / 60
                if minutes < 30:
                    duration_buckets["under_30"] += 1
                elif minutes < 60:
                    duration_buckets["30_60"] += 1
                elif minutes < 90:
                    duration_buckets["60_90"] += 1
                else:
                    duration_buckets["over_90"] += 1
            if match_has_extra_points:
                extra_point_matches += 1
            final_margin = abs(_integer(record.get("player1_games_won")) - _integer(record.get("player2_games_won")))
            if final_margin <= 1:
                close_matches += 1
            if first_unit_winner and record.get("winner_side") and first_unit_winner != record.get("winner_side"):
                comeback_matches += 1

    total = len(records)
    completed_count = len(completed)
    active_uncompleted = sum(1 for record in records if record.get("status") == "active")
    valid_durations = [item for item in completed if item["duration_seconds"] > 0]
    longest_match = max(valid_durations, key=lambda item: item["duration_seconds"], default=None)
    shortest_match = min(valid_durations, key=lambda item: item["duration_seconds"], default=None)
    average_duration = round(sum(item["duration_seconds"] for item in valid_durations) / len(valid_durations)) if valid_durations else None
    repeated_entries = sum(count for count in participant_counts.values() if count > 1)
    participant_entries = sum(participant_counts.values())
    most_used_format = max(formats.items(), key=lambda item: item[1], default=(None, 0))

    def usage_rate(name):
        return _percentage(option_counts[f"{name}_used"], option_counts[f"{name}_eligible"])

    return {
        "period_days": max(0, int(period_days or 0)),
        "matches_scored": total,
        "matches_by_sport": [{"sport": sport, "count": by_sport.get(sport, 0)} for sport in sports],
        "completed_matches": completed_count,
        "completed_match_rate": _percentage(completed_count, total),
        "uncompleted_started_matches": active_uncompleted,
        "abandoned_match_rate": _percentage(active_uncompleted, completed_count + active_uncompleted),
        "average_match_duration_seconds": average_duration,
        "duration_distribution": duration_buckets,
        "longest_match": longest_match,
        "shortest_completed_match": shortest_match,
        "hourly_activity_heatmap": [
            {"day": day, "hour": hour, "count": heatmap[(day, hour)]}
            for day in range(7) for hour in range(24)
        ],
        "monthly_scoring_trend": [{"month": month, "count": month_counts[month]} for month in sorted(month_counts)],
        "monthly_sport_trend": [
            {"month": month, "sport": sport, "count": monthly_sport_counts[(month, sport)]}
            for month, sport in sorted(monthly_sport_counts)
        ],
        "active_days": len(active_days),
        "returning_usage_weeks": len(active_weeks),
        "average_matches_per_active_day": round(total / len(active_days), 1) if active_days else None,
        "average_matches_per_active_week": round(total / len(active_weeks), 1) if active_weeks else None,
        "platform_usage": {**platform_counts, "tracked": platform_counts["web"] + platform_counts["ios"] > 0},
        "setup_completion": {"tracked": False, "reason": "Setup-start telemetry is not stored yet."},
        "most_used_match_format": {"label": most_used_format[0], "count": most_used_format[1]},
        "timed_break_usage_rate": usage_rate("timed_break"),
        "golden_point_usage_rate": usage_rate("golden_point"),
        "handicap_match_usage_rate": usage_rate("handicap"),
        "final_set_tiebreak_usage_rate": usage_rate("final_tiebreak"),
        "average_units_by_sport": [
            {
                "sport": sport,
                "average": round(values["units"] / values["matches"], 1) if values["matches"] else None,
                "unit": "sets" if sport in {"tennis", "padel"} else "games",
            }
            for sport, values in sorted(sport_structures.items())
        ],
        "close_match_frequency": _percentage(close_matches, completed_count),
        "extra_points_frequency": _percentage(extra_point_matches, completed_count),
        "comeback_match_frequency": _percentage(comeback_matches, completed_count),
        "average_points_by_sport": [
            {"sport": sport, "average": round(values["points"] / values["matches"], 1) if values["matches"] else None}
            for sport, values in sorted(sport_structures.items())
        ],
        "average_points_per_unit_by_sport": [
            {"sport": sport, "average": round(values["points"] / values["units"], 1) if values["units"] else None}
            for sport, values in sorted(sport_structures.items())
        ],
        "longest_game_or_set": longest_unit,
        "unique_participant_names": len(participant_counts),
        "repeat_participant_rate": _percentage(repeated_entries, participant_entries),
        "total_points": total_points,
    }


def build_player_usage_analytics(records, first_name, surname):
    identity = _analytics_name(first_name, surname).casefold()
    if not identity:
        return None
    played = won = points = duration_seconds = 0
    opponents = defaultdict(int)
    sports = defaultdict(int)
    for record in records:
        player1 = _analytics_name(record.get("player1_name"), record.get("player1_surname"))
        player2 = _analytics_name(record.get("player2_name"), record.get("player2_surname"))
        side = "player1" if player1.casefold() == identity else ("player2" if player2.casefold() == identity else None)
        if not side:
            start_payload = next((event.get("payload") or {} for event in (record.get("events") or []) if event.get("event_type") == "match_started"), {})
            for team_side, team in (start_payload.get("tennis_teams") or {}).items():
                if any(_analytics_name(item.get("first_name"), item.get("surname")).casefold() == identity for item in team or []):
                    side = team_side
                    break
        if not side:
            continue
        if record.get("status") != "completed":
            continue
        played += 1
        won += int(record.get("winner_side") == side)
        duration_seconds += _integer(record.get("match_duration_seconds"))
        sports[str(record.get("sport") or "squash").lower()] += 1
        opponents[player2 if side == "player1" else player1] += 1
        points += sum(
            1 for event in (record.get("events") or [])
            if event.get("event_type") in {"score_point", "stroke"}
            and ((event.get("payload") or {}).get("scorer") or (event.get("payload") or {}).get("player_side")) == side
        )
    return {
        "matches_played": played,
        "matches_won": won,
        "matches_lost": max(0, played - won),
        "win_percentage": _percentage(won, played),
        "points_won": points,
        "playing_time_seconds": duration_seconds,
        "average_match_duration_seconds": round(duration_seconds / played) if played else None,
        "sports": [{"sport": sport, "matches": count} for sport, count in sorted(sports.items())],
        "opponents": [{"name": name or "Opponent", "matches": count} for name, count in sorted(opponents.items(), key=lambda item: (-item[1], item[0]))],
    }


def build_club_usage_analytics(records, app_analytics, user_count):
    court_usage = defaultdict(lambda: {"matches": 0, "duration_seconds": 0, "sports": defaultdict(int)})
    intervals = []
    scheduled = []
    for record in records:
        court = record.get("court_name") or f"Court {record.get('court_id') or 'unassigned'}"
        sport = str(record.get("sport") or "squash").lower()
        court_usage[court]["matches"] += 1
        court_usage[court]["duration_seconds"] += _integer(record.get("match_duration_seconds"))
        court_usage[court]["sports"][sport] += 1
        start = _analytics_datetime(record.get("created_at"))
        end = _analytics_datetime(record.get("completed_at") or record.get("updated_at"))
        if start and end and end >= start:
            intervals.append((start, end))
        if record.get("status") == "scheduled":
            scheduled.append({
                "day": start.strftime("%A") if start else "Unknown",
                "date": start.date().isoformat() if start else None,
                "hour": start.hour if start else None,
                "sport": sport,
                "court": court,
            })
    timeline = sorted([(start, 1) for start, _ in intervals] + [(end, -1) for _, end in intervals], key=lambda item: (item[0], item[1]))
    current = simultaneous = 0
    for _, delta in timeline:
        current += delta
        simultaneous = max(simultaneous, current)
    hour_totals = defaultdict(int)
    for cell in app_analytics.get("hourly_activity_heatmap") or []:
        hour_totals[cell["hour"]] += cell["count"]
    peak_hours = [hour for hour, _ in sorted(hour_totals.items(), key=lambda item: (-item[1], item[0]))[:3]]
    total = app_analytics.get("matches_scored") or 0
    peak_count = sum(hour_totals[hour] for hour in peak_hours)
    return {
        "club_matches_scored": total,
        "member_activity": {"tracked": False, "user_count": user_count, "reason": "Match actions are not yet attributed to individual member accounts."},
        "club_usage_heatmap": app_analytics.get("hourly_activity_heatmap") or [],
        "peak_hours": peak_hours,
        "peak_time_concentration": _percentage(peak_count, total),
        "off_peak_matches": max(0, total - peak_count),
        "court_usage": [
            {
                "court": court,
                "matches": values["matches"],
                "duration_seconds": values["duration_seconds"],
                "sports": [{"sport": sport, "count": count} for sport, count in sorted(values["sports"].items())],
            }
            for court, values in sorted(court_usage.items())
        ],
        "simultaneous_court_activity": simultaneous,
        "sport_popularity_trend": app_analytics.get("monthly_sport_trend") or [],
        "scheduled_match_demand": scheduled,
        "premium_digest": (
            f"{total} matches were recorded across {len(court_usage)} courts. "
            f"The busiest hours were {', '.join(f'{hour:02d}:00' for hour in peak_hours) or 'not yet available'}, "
            f"with {app_analytics.get('returning_usage_weeks') or 0} active weeks in this period."
        ),
    }


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


def personal_can_access_completed_match(connection, organization_id, match_id, plan):
    """Prevent a known match URL from bypassing the current personal history limit."""
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
                "history_limit": personal_plan_entitlements(plan)["history_limit"],
            },
        )
        return bool((cursor.fetchone() or {}).get("is_available"))


def personal_free_can_access_completed_match(connection, organization_id, match_id):
    """Compatibility wrapper for existing callers and tests."""
    return personal_can_access_completed_match(connection, organization_id, match_id, "personal_free")


def get_dashboard_data(
    connection,
    organization_id,
    active_limit=12,
    recent_limit=12,
    analytics_period_days=30,
    actor_first_name="",
    actor_surname="",
    include_club_analytics=False,
    include_extended_analytics=False,
):
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
    if (org_type != "personal" or plan == "personal_plus") and active_limit and active_limit > 0:
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
            limit=PERSONAL_HISTORY_LIMITS["personal_plus"],
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

    analytics_records = []
    if include_extended_analytics:
        analytics_records = _fetch_analytics_records(connection, organization_id, analytics_period_days)
        app_analytics = build_extended_app_analytics(analytics_records, analytics_period_days)
    else:
        app_analytics = build_app_analytics(connection, organization_id, analytics_period_days)
    player_analytics = None
    if include_extended_analytics and (org_type != "personal" or plan == "personal_plus"):
        player_analytics = build_player_usage_analytics(
            analytics_records,
            actor_first_name,
            actor_surname,
        )
    club_analytics = None
    if include_extended_analytics and org_type == "club" and include_club_analytics:
        club_analytics = build_club_usage_analytics(
            analytics_records,
            app_analytics,
            _integer((users_row or {}).get("user_count")),
        )

    return {
        "organization": {
            "id": int(organization_id),
            "name": (organization_row or {}).get("organization_name"),
            "type": org_type,
            "plan": plan,
            "history_limit": history_limit,
            "completed_match_count": completed_match_count,
            "locked_history_count": max(0, completed_match_count - history_limit) if plan == "personal_free" else 0,
            "entitlements": personal_plan_entitlements(plan) if org_type == "personal" else None,
            "available_plan_entitlements": personal_plan_contract() if org_type == "personal" else None,
            "court_count": (courts_row or {}).get("court_count", 0),
            "user_count": (users_row or {}).get("user_count", 0),
            "roles": (users_row or {}).get("roles") or [],
        },
        "active_matches": active_matches,
        "scheduled_matches": scheduled_matches,
        "recent_matches": recent_matches,
        "app_analytics": app_analytics,
        "player_analytics": player_analytics,
        "club_analytics": club_analytics,
        "performance": performance,
    }
