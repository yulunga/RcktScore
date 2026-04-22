from psycopg.errors import UndefinedTable

from common.match_logic import list_matches


PERSONAL_HISTORY_LIMITS = {
    "personal_free": 3,
    "personal_plus": 100,
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
        return PERSONAL_HISTORY_LIMITS.get(plan or "personal_free", 3)
    return default_limit


def get_dashboard_data(connection, organization_id, active_limit=10, recent_limit=10):
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

    active_matches = _safe_list_matches(
        connection,
        organization_id=organization_id,
        status="active",
        limit=active_limit,
    )
    scheduled_matches = []
    if org_type != "personal":
        scheduled_matches = _safe_list_matches(
            connection,
            organization_id=organization_id,
            status="scheduled",
            limit=active_limit,
        )
    recent_matches = _safe_list_matches(
        connection,
        organization_id=organization_id,
        status="completed",
        limit=history_limit,
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
            "court_count": (courts_row or {}).get("court_count", 0),
            "user_count": (users_row or {}).get("user_count", 0),
            "roles": (users_row or {}).get("roles") or [],
        },
        "active_matches": active_matches,
        "scheduled_matches": scheduled_matches,
        "recent_matches": recent_matches,
    }
