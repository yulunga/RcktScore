from datetime import datetime, timezone


class TournamentAccessError(Exception):
    pass


def _utcnow():
    return datetime.now(timezone.utc)


def get_tournament_feature(connection, organization_id):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                o.id AS organization_id,
                COALESCE(o.org_type, 'club') AS organization_type,
                COALESCE(feature.web_enabled, false) AS web_enabled,
                feature.enabled_by,
                feature.enabled_at,
                feature.updated_at
            FROM "SkwshOrgSettings" AS o
            LEFT JOIN tournament_organization_features AS feature
                ON feature.organization_id = o.id
            WHERE o.id = %(organization_id)s
            LIMIT 1
            """,
            {"organization_id": int(organization_id)},
        )
        row = cursor.fetchone()

    if not row:
        return None

    return {
        "key": "tournament_manager",
        "organization_id": row["organization_id"],
        "organization_type": row.get("organization_type") or "club",
        "web_enabled": bool(row.get("web_enabled")),
        "enabled_by": row.get("enabled_by") or "",
        "enabled_at": row["enabled_at"].isoformat() if row.get("enabled_at") else None,
        "updated_at": row["updated_at"].isoformat() if row.get("updated_at") else None,
    }


def require_tournament_feature(connection, organization_id):
    feature = get_tournament_feature(connection, organization_id)
    if not feature:
        raise TournamentAccessError("Organisation not found")
    if feature["organization_type"] != "club" or not feature["web_enabled"]:
        raise TournamentAccessError("Tournament Manager is not enabled for this club")
    return feature


def set_tournament_feature(connection, organization_id, enabled, actor_username):
    feature = get_tournament_feature(connection, organization_id)
    if not feature:
        raise LookupError("Organisation not found")
    if feature["organization_type"] != "club":
        raise ValueError("Tournament Manager can only be enabled for club organisations")

    now = _utcnow()
    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO tournament_organization_features (
                organization_id, web_enabled, enabled_by, enabled_at, updated_at
            )
            VALUES (
                %(organization_id)s, %(web_enabled)s, %(enabled_by)s,
                %(enabled_at)s, %(updated_at)s
            )
            ON CONFLICT (organization_id) DO UPDATE
            SET web_enabled = EXCLUDED.web_enabled,
                enabled_by = EXCLUDED.enabled_by,
                enabled_at = CASE
                    WHEN EXCLUDED.web_enabled THEN COALESCE(tournament_organization_features.enabled_at, EXCLUDED.enabled_at)
                    ELSE tournament_organization_features.enabled_at
                END,
                updated_at = EXCLUDED.updated_at
            """,
            {
                "organization_id": int(organization_id),
                "web_enabled": bool(enabled),
                "enabled_by": (actor_username or "root_admin").strip(),
                "enabled_at": now if enabled else None,
                "updated_at": now,
            },
        )
    connection.commit()
    return get_tournament_feature(connection, organization_id)

