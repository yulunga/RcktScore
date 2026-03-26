def search_match_setup_lookups(connection, organization_id, query, limit=8):
    org_id = int(organization_id)
    trimmed_query = (query or "").strip()
    if not trimmed_query:
        return {"players": [], "referees": []}

    search_term = f"%{trimmed_query}%"
    row_limit = max(1, min(int(limit), 12))

    with connection.cursor() as cursor:
        cursor.execute(
            """
            WITH player_entries AS (
                SELECT
                    trim(player1_name) AS first_name,
                    trim(coalesce(player1_surname, '')) AS surname,
                    updated_at
                FROM matches
                WHERE tenant_id = %(organization_id)s
                  AND (
                    player1_name ILIKE %(query)s
                    OR coalesce(player1_surname, '') ILIKE %(query)s
                    OR concat_ws(' ', player1_name, coalesce(player1_surname, '')) ILIKE %(query)s
                  )

                UNION ALL

                SELECT
                    trim(player2_name) AS first_name,
                    trim(coalesce(player2_surname, '')) AS surname,
                    updated_at
                FROM matches
                WHERE tenant_id = %(organization_id)s
                  AND (
                    player2_name ILIKE %(query)s
                    OR coalesce(player2_surname, '') ILIKE %(query)s
                    OR concat_ws(' ', player2_name, coalesce(player2_surname, '')) ILIKE %(query)s
                  )
            )
            SELECT DISTINCT ON (lower(first_name), lower(surname))
                first_name,
                surname
            FROM player_entries
            WHERE first_name <> ''
            ORDER BY lower(first_name), lower(surname), updated_at DESC
            LIMIT %(limit)s
            """,
            {
                "organization_id": org_id,
                "query": search_term,
                "limit": row_limit,
            },
        )
        player_rows = cursor.fetchall()

        cursor.execute(
            """
            WITH referee_entries AS (
                SELECT
                    trim(referee_name) AS referee_name,
                    updated_at
                FROM matches
                WHERE tenant_id = %(organization_id)s
                  AND coalesce(trim(referee_name), '') <> ''
                  AND trim(referee_name) ILIKE %(query)s

                UNION ALL

                SELECT
                    trim(clubusername) AS referee_name,
                    created_at AS updated_at
                FROM "SkwshOrgUsers"
                WHERE organization_id = %(organization_id)s
                  AND trim(clubusername) ILIKE %(query)s
            )
            SELECT DISTINCT ON (lower(referee_name))
                referee_name
            FROM referee_entries
            WHERE referee_name <> ''
            ORDER BY lower(referee_name), updated_at DESC
            LIMIT %(limit)s
            """,
            {
                "organization_id": org_id,
                "query": search_term,
                "limit": row_limit,
            },
        )
        referee_rows = cursor.fetchall()

    return {
        "players": [
            {
                "first_name": row.get("first_name") or "",
                "surname": row.get("surname") or "",
                "display_name": " ".join(
                    value for value in [row.get("first_name") or "", row.get("surname") or ""] if value
                ),
            }
            for row in player_rows
        ],
        "referees": [row.get("referee_name") or "" for row in referee_rows],
    }
