from uuid import UUID


def normalize_client_action_id(value):
    if value in (None, ""):
        return None

    try:
        return str(UUID(str(value)))
    except (TypeError, ValueError, AttributeError) as exc:
        raise ValueError("client_action_id must be a valid UUID") from exc


def claim_match_action(connection, match_id, action_type, client_action_id):
    normalized_action_id = normalize_client_action_id(client_action_id)
    if not normalized_action_id:
        return True

    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO match_action_receipts (
                client_action_id,
                match_id,
                action_type
            )
            VALUES (
                %(client_action_id)s,
                %(match_id)s,
                %(action_type)s
            )
            ON CONFLICT (client_action_id) DO NOTHING
            RETURNING client_action_id
            """,
            {
                "client_action_id": normalized_action_id,
                "match_id": match_id,
                "action_type": action_type,
            },
        )
        claimed = cursor.fetchone()
        if claimed:
            return True

        cursor.execute(
            """
            SELECT match_id, action_type
            FROM match_action_receipts
            WHERE client_action_id = %(client_action_id)s
            """,
            {"client_action_id": normalized_action_id},
        )
        existing = cursor.fetchone()

    if not existing:
        raise RuntimeError("Unable to verify the queued match action")

    if str(existing["match_id"]) != str(match_id) or existing["action_type"] != action_type:
        raise ValueError("client_action_id was already used for a different match action")

    return False
