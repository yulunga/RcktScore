from psycopg.errors import UndefinedTable

from common.match_logic import list_matches


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


def get_dashboard_data(connection, organization_id, active_limit=10, recent_limit=10):
    active_matches = _safe_list_matches(
        connection,
        organization_id=organization_id,
        status="active",
        limit=active_limit,
    )
    recent_matches = _safe_list_matches(
        connection,
        organization_id=organization_id,
        status="completed",
        limit=recent_limit,
    )

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id, organization_name
            FROM "SkwshOrgSettings"
            WHERE id = %(organization_id)s
            LIMIT 1
            """,
            {"organization_id": int(organization_id)},
        )
        organization_row = cursor.fetchone()

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
            "court_count": (courts_row or {}).get("court_count", 0),
            "user_count": (users_row or {}).get("user_count", 0),
            "roles": (users_row or {}).get("roles") or [],
        },
        "active_matches": active_matches,
        "recent_matches": recent_matches,
    }
