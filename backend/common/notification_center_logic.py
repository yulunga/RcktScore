from datetime import datetime, timezone


AUDIENCES = {"all", "personal_free", "personal_plus", "club_essentials", "club_pro"}


def _utcnow():
    return datetime.now(timezone.utc)


def list_user_notifications(connection, username, plan):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT n.id, n.title, n.message, n.audience, n.created_at,
                   r.read_at
            FROM system_notifications AS n
            LEFT JOIN system_notification_reads AS r
              ON r.notification_id = n.id
             AND LOWER(r.username) = LOWER(%(username)s)
            WHERE (
                (n.recipient_username IS NULL AND n.audience IN ('all', %(plan)s))
                OR LOWER(n.recipient_username) = LOWER(%(username)s)
            )
              AND NOT EXISTS (
                  SELECT 1
                  FROM system_notification_dismissals AS d
                  WHERE d.notification_id = n.id
                    AND LOWER(d.username) = LOWER(%(username)s)
              )
            ORDER BY n.created_at DESC
            LIMIT 100
            """,
            {"username": username, "plan": plan},
        )
        rows = cursor.fetchall()
    return [_serialize(row) for row in rows]


def mark_notification_read(connection, notification_id, username, plan):
    username = str(username or "").strip().lower()
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id FROM system_notifications
            WHERE id = %(notification_id)s
              AND (
                  (recipient_username IS NULL AND audience IN ('all', %(plan)s))
                  OR LOWER(recipient_username) = LOWER(%(username)s)
              )
            LIMIT 1
            """,
            {"notification_id": notification_id, "plan": plan, "username": username},
        )
        if not cursor.fetchone():
            return False
        cursor.execute(
            """
            INSERT INTO system_notification_reads (notification_id, username, read_at)
            VALUES (%(notification_id)s, LOWER(%(username)s), %(read_at)s)
            ON CONFLICT (notification_id, username)
            DO UPDATE SET read_at = EXCLUDED.read_at
            """,
            {"notification_id": notification_id, "username": username, "read_at": _utcnow()},
        )
    connection.commit()
    return True


def dismiss_notification(connection, notification_id, username, plan):
    username = str(username or "").strip().lower()
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id FROM system_notifications
            WHERE id = %(notification_id)s
              AND (
                  (recipient_username IS NULL AND audience IN ('all', %(plan)s))
                  OR LOWER(recipient_username) = LOWER(%(username)s)
              )
            LIMIT 1
            """,
            {"notification_id": notification_id, "plan": plan, "username": username},
        )
        if not cursor.fetchone():
            return False
        cursor.execute(
            """
            INSERT INTO system_notification_dismissals (notification_id, username, dismissed_at)
            VALUES (%(notification_id)s, LOWER(%(username)s), %(dismissed_at)s)
            ON CONFLICT (notification_id, username)
            DO UPDATE SET dismissed_at = EXCLUDED.dismissed_at
            """,
            {"notification_id": notification_id, "username": username, "dismissed_at": _utcnow()},
        )
    connection.commit()
    return True


def create_notification(connection, title, message, audience, created_by):
    title = str(title or "").strip()
    message = str(message or "").strip()
    audience = str(audience or "all").strip().lower()
    if not title or not message:
        raise ValueError("title and message are required")
    if len(title) > 120:
        raise ValueError("title must be 120 characters or fewer")
    if len(message) > 4000:
        raise ValueError("message must be 4000 characters or fewer")
    if audience not in AUDIENCES:
        raise ValueError("audience is not supported")
    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO system_notifications (title, message, audience, created_by, recipient_count)
            SELECT %(title)s, %(message)s, %(audience)s, %(created_by)s,
                   COUNT(DISTINCT LOWER(BTRIM(member.clubusername)))
            FROM "SkwshOrgUsers" AS member
            JOIN "SkwshOrgSettings" AS org ON org.id = member.organization_id
            WHERE COALESCE(member.approval_status, 'approved') = 'approved'
              AND NULLIF(BTRIM(member.clubusername), '') IS NOT NULL
              AND (%(audience)s = 'all' OR org.plan = %(audience)s)
              AND NOT EXISTS (
                  SELECT 1 FROM "SkwshOrgSettings" AS personal
                  WHERE personal.org_type = 'personal'
                    AND LOWER(BTRIM(personal.owner_username)) = LOWER(BTRIM(member.clubusername))
                    AND personal.deletion_requested_at IS NOT NULL
              )
            RETURNING id, title, message, audience, created_at, NULL::timestamptz AS read_at
            """,
            {"title": title, "message": message, "audience": audience, "created_by": created_by},
        )
        row = cursor.fetchone()
    connection.commit()
    return _serialize(row)


def create_direct_notification(connection, title, message, recipient_username, created_by="system"):
    title = str(title or "").strip()
    message = str(message or "").strip()
    recipient_username = str(recipient_username or "").strip().lower()
    if not title or not message or not recipient_username:
        raise ValueError("title, message and recipient username are required")
    if len(title) > 120:
        raise ValueError("title must be 120 characters or fewer")
    if len(message) > 4000:
        raise ValueError("message must be 4000 characters or fewer")
    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO system_notifications (
                title, message, audience, created_by, recipient_count, recipient_username
            )
            VALUES (%(title)s, %(message)s, 'all', %(created_by)s, 1, %(recipient_username)s)
            RETURNING id, title, message, audience, created_at, NULL::timestamptz AS read_at
            """,
            {
                "title": title,
                "message": message,
                "created_by": created_by,
                "recipient_username": recipient_username,
            },
        )
        row = cursor.fetchone()
    connection.commit()
    return _serialize(row)


def list_admin_notifications(connection):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT n.id, n.title, n.message, n.audience, n.created_at,
                   COUNT(DISTINCT LOWER(BTRIM(r.username))) AS read_count,
                   n.recipient_count,
                   NULL::timestamptz AS read_at
            FROM system_notifications AS n
            LEFT JOIN system_notification_reads AS r ON r.notification_id = n.id
            GROUP BY n.id
            ORDER BY n.created_at DESC
            LIMIT 100
            """
        )
        rows = cursor.fetchall()
    return [{**_serialize(row), "read_count": int(row.get("read_count") or 0), "recipient_count": row["recipient_count"]} for row in rows]


def _serialize(row):
    return {
        "id": str(row["id"]),
        "title": row["title"],
        "message": row["message"],
        "audience": row["audience"],
        "created_at": row["created_at"].isoformat(),
        "read_at": row["read_at"].isoformat() if row.get("read_at") else None,
        "is_read": bool(row.get("read_at")),
    }
