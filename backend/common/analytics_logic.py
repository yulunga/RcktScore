import csv
import io
from datetime import datetime, timedelta, timezone

from psycopg.errors import UndefinedTable


SETUP_STALE_AFTER_HOURS = 2
VALID_SETUP_OUTCOMES = {"completed", "abandoned"}


def begin_match_setup(connection, organization_id, actor_user_id, client_type, sport):
    normalized_client = "mobile_app" if client_type == "mobile_app" else "web_app"
    normalized_sport = str(sport or "").strip().lower()
    if not normalized_sport:
        raise ValueError("sport is required")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO match_setup_sessions (
                organization_id,
                actor_user_id,
                client_type,
                sport
            )
            VALUES (
                %(organization_id)s,
                %(actor_user_id)s,
                %(client_type)s,
                %(sport)s
            )
            RETURNING id, started_at
            """,
            {
                "organization_id": int(organization_id),
                "actor_user_id": actor_user_id,
                "client_type": normalized_client,
                "sport": normalized_sport,
            },
        )
        row = cursor.fetchone()
    connection.commit()
    return {
        "id": str(row["id"]),
        "started_at": row["started_at"].isoformat(),
    }


def finish_match_setup(connection, setup_id, organization_id, actor_user_id, outcome, match_id=None):
    normalized_outcome = str(outcome or "").strip().lower()
    if normalized_outcome not in VALID_SETUP_OUTCOMES:
        raise ValueError("outcome must be completed or abandoned")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE match_setup_sessions
            SET outcome = %(outcome)s,
                finished_at = CURRENT_TIMESTAMP,
                match_id = CASE
                    WHEN %(outcome)s = 'completed' THEN %(match_id)s::uuid
                    ELSE NULL
                END
            WHERE id = %(setup_id)s::uuid
              AND organization_id = %(organization_id)s
              AND actor_user_id = %(actor_user_id)s
              AND outcome IS NULL
            RETURNING id, outcome, finished_at, match_id
            """,
            {
                "setup_id": setup_id,
                "organization_id": int(organization_id),
                "actor_user_id": actor_user_id,
                "outcome": normalized_outcome,
                "match_id": match_id,
            },
        )
        row = cursor.fetchone()

        if not row:
            cursor.execute(
                """
                SELECT id, outcome, finished_at, match_id
                FROM match_setup_sessions
                WHERE id = %(setup_id)s::uuid
                  AND organization_id = %(organization_id)s
                  AND actor_user_id = %(actor_user_id)s
                LIMIT 1
                """,
                {
                    "setup_id": setup_id,
                    "organization_id": int(organization_id),
                    "actor_user_id": actor_user_id,
                },
            )
            row = cursor.fetchone()

    if not row:
        connection.rollback()
        return None
    connection.commit()
    return {
        "id": str(row["id"]),
        "outcome": row.get("outcome"),
        "finished_at": row["finished_at"].isoformat() if row.get("finished_at") else None,
        "match_id": str(row["match_id"]) if row.get("match_id") else None,
    }


def get_match_setup_analytics(connection, organization_id, period_days=30, now=None):
    current_time = now or datetime.now(timezone.utc)
    stale_before = current_time - timedelta(hours=SETUP_STALE_AFTER_HOURS)
    params = {
        "organization_id": int(organization_id),
        "period_days": max(0, int(period_days or 0)),
        "stale_before": stale_before,
    }
    period_filter = ""
    if params["period_days"]:
        period_filter = "AND started_at >= CURRENT_TIMESTAMP - (%(period_days)s * INTERVAL '1 day')"

    try:
        with connection.cursor() as cursor:
            cursor.execute(
                f"""
                SELECT
                    COUNT(*) FILTER (WHERE outcome = 'completed') AS completed,
                    COUNT(*) FILTER (
                        WHERE outcome = 'abandoned'
                           OR (outcome IS NULL AND started_at <= %(stale_before)s)
                    ) AS abandoned,
                    COUNT(*) FILTER (
                        WHERE outcome IS NULL AND started_at > %(stale_before)s
                    ) AS open,
                    COUNT(*) FILTER (WHERE client_type = 'web_app') AS web,
                    COUNT(*) FILTER (WHERE client_type = 'mobile_app') AS mobile,
                    COUNT(DISTINCT actor_user_id) AS active_users
                FROM match_setup_sessions
                WHERE organization_id = %(organization_id)s
                  {period_filter}
                """,
                params,
            )
            row = cursor.fetchone() or {}
    except UndefinedTable:
        connection.rollback()
        return {"tracked": False, "reason": "Match setup telemetry is not deployed yet."}

    completed = int(row.get("completed") or 0)
    abandoned = int(row.get("abandoned") or 0)
    denominator = completed + abandoned
    return {
        "tracked": True,
        "started": completed + abandoned + int(row.get("open") or 0),
        "completed": completed,
        "abandoned": abandoned,
        "open": int(row.get("open") or 0),
        "rate": round((completed / denominator) * 100, 1) if denominator else None,
        "abandonment_rate": round((abandoned / denominator) * 100, 1) if denominator else None,
        "client_usage": {
            "web": int(row.get("web") or 0),
            "mobile": int(row.get("mobile") or 0),
        },
        "active_users": int(row.get("active_users") or 0),
    }


def _csv_value(value):
    if value is None:
        return ""
    if isinstance(value, bool):
        return "Yes" if value else "No"
    return value


def build_analytics_export(dashboard, report_type, period_days):
    report_type = str(report_type or "").strip().lower()
    app = dashboard.get("app_analytics") or {}
    rows = [
        ("Report", "Type", "Personal Plus" if report_type == "personal" else "Club aggregate"),
        ("Report", "Period days", period_days),
        ("Usage", "Matches scored", app.get("matches_scored")),
        ("Usage", "Completed matches", app.get("completed_matches")),
        ("Usage", "Completed match rate", app.get("completed_match_rate")),
        ("Usage", "Average match duration seconds", app.get("average_match_duration_seconds")),
    ]
    setup = app.get("setup_completion") or {}
    rows.extend([
        ("Match setup", "Setups started", setup.get("started")),
        ("Match setup", "Setups completed", setup.get("completed")),
        ("Match setup", "Setups abandoned", setup.get("abandoned")),
        ("Match setup", "Completion rate", setup.get("rate")),
        ("Match setup", "Abandonment rate", setup.get("abandonment_rate")),
    ])
    for item in app.get("matches_by_sport") or []:
        rows.append(("Sport mix", str(item.get("sport") or "Unknown").title(), item.get("count")))

    if report_type == "personal":
        performance = dashboard.get("performance") or {}
        rows.extend([
            ("Player", "Matches played", performance.get("matches_played")),
            ("Player", "Matches won", performance.get("matches_won")),
            ("Player", "Win percentage", performance.get("win_percentage")),
            ("Player", "Games or sets won", performance.get("games_won")),
            ("Player", "Point win percentage", performance.get("point_win_percentage")),
            ("Player", "Serve point win percentage", performance.get("service_point_win_percentage")),
            ("Player", "Playing time seconds", performance.get("playing_time_seconds")),
            ("Player", "Current win streak", performance.get("current_win_streak")),
            ("Player", "Best win streak", performance.get("best_win_streak")),
        ])
        for sport in performance.get("sports") or []:
            rows.append(("Player sport", str(sport.get("sport") or "Unknown").title(), f"{sport.get('won', 0)}-{sport.get('lost', 0)}"))
    else:
        club = dashboard.get("club_analytics") or {}
        rows.extend([
            ("Club", "Club matches scored", club.get("club_matches_scored")),
            ("Club", "Peak-time concentration", club.get("peak_time_concentration")),
            ("Club", "Off-peak matches", club.get("off_peak_matches")),
            ("Club", "Simultaneous court activity", club.get("simultaneous_court_activity")),
            ("Club", "Active setup users", (club.get("member_activity") or {}).get("active_users")),
            ("Club", "Setup adoption rate", (club.get("member_activity") or {}).get("adoption_rate")),
        ])
        for court in club.get("court_usage") or []:
            # Court and sport demand are operational venue data; no player or
            # member identity is included in a Club export.
            rows.append(("Court usage", court.get("court") or "Unassigned", court.get("matches")))

    output = io.StringIO()
    writer = csv.writer(output, lineterminator="\n")
    writer.writerow(["Section", "Metric", "Value"])
    writer.writerows((section, metric, _csv_value(value)) for section, metric, value in rows)
    return output.getvalue()
