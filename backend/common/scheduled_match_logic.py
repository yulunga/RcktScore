from datetime import datetime, timezone


def _utcnow():
    return datetime.now(timezone.utc)


def delete_scheduled_club_match(connection, match_id, tenant_id):
    """Soft-delete an ordinary scheduled club match under a row lock."""
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id, tenant_id, status, tournament_match_id,
                   COALESCE(is_archived, false) AS is_archived
            FROM matches
            WHERE id = %(match_id)s
            FOR UPDATE
            """,
            {"match_id": match_id},
        )
        match = cursor.fetchone()

        if not match or int(match["tenant_id"]) != int(tenant_id) or match.get("is_archived"):
            raise LookupError("Scheduled match not found")
        if match.get("status") != "scheduled":
            raise ValueError("Only a scheduled match can be deleted from the club schedule")
        if match.get("tournament_match_id"):
            raise ValueError(
                "Tournament fixtures must be resolved or removed through Tournament Manager"
            )

        now = _utcnow()
        cursor.execute(
            """
            UPDATE matches
            SET is_archived = true,
                archived_at = %(archived_at)s,
                updated_at = %(updated_at)s
            WHERE id = %(match_id)s
            RETURNING id, tenant_id, status, archived_at
            """,
            {
                "match_id": match_id,
                "archived_at": now,
                "updated_at": now,
            },
        )
        deleted = cursor.fetchone()

    connection.commit()
    return {
        "id": str(deleted["id"]),
        "organization_id": deleted["tenant_id"],
        "status": deleted["status"],
        "archived_at": deleted["archived_at"].isoformat(),
    }
