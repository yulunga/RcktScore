DO $$
DECLARE
    identity_record record;
    source_membership record;
    personal_org_id bigint;
    display_name text;
BEGIN
    FOR identity_record IN
        SELECT
            identities.normalized_username,
            identities.username
        FROM (
            SELECT
                LOWER(u.clubusername) AS normalized_username,
                MIN(u.clubusername) AS username
            FROM "SkwshOrgUsers" AS u
            GROUP BY LOWER(u.clubusername)
        ) AS identities
        WHERE NOT EXISTS (
            SELECT 1
            FROM "SkwshOrgUsers" AS personal_u
            INNER JOIN "SkwshOrgSettings" AS personal_o
                ON personal_o.id = personal_u.organization_id
            WHERE LOWER(personal_u.clubusername) = identities.normalized_username
              AND personal_o.org_type = 'personal'
        )
    LOOP
        SELECT
            u.password_hash,
            u.first_name,
            u.surname,
            u.password_reset_token,
            u.password_reset_requested_at
        INTO source_membership
        FROM "SkwshOrgUsers" AS u
        WHERE LOWER(u.clubusername) = identity_record.normalized_username
        ORDER BY
            CASE WHEN u.password_hash IS NOT NULL THEN 0 ELSE 1 END,
            CASE WHEN u.approval_status = 'approved' THEN 0 ELSE 1 END,
            u.id ASC
        LIMIT 1;

        personal_org_id := nextval('hitnscore_personal_org_id_seq');
        display_name := NULLIF(
            CONCAT_WS(' ', NULLIF(source_membership.first_name, ''), NULLIF(source_membership.surname, '')),
            ''
        );

        INSERT INTO "SkwshOrgSettings" (
            id,
            created_at,
            organization_name,
            org_contact,
            org_email,
            org_type,
            plan,
            owner_username,
            is_hidden
        )
        VALUES (
            personal_org_id,
            now(),
            CONCAT(COALESCE(display_name, identity_record.username), ' Personal'),
            COALESCE(display_name, identity_record.username),
            identity_record.username,
            'personal',
            'personal_free',
            identity_record.username,
            true
        );

        INSERT INTO "SkwshOrgUsers" (
            created_at,
            clubusername,
            password_hash,
            organization_id,
            role,
            first_name,
            surname,
            approval_status,
            approved_at,
            password_reset_token,
            password_reset_requested_at
        )
        VALUES (
            now(),
            identity_record.username,
            source_membership.password_hash,
            personal_org_id,
            'admin',
            COALESCE(source_membership.first_name, ''),
            COALESCE(source_membership.surname, ''),
            'approved',
            now(),
            source_membership.password_reset_token,
            source_membership.password_reset_requested_at
        );

        INSERT INTO "SkwshCourts" (
            created_at,
            court_name,
            court_alias,
            organization_name
        )
        VALUES (
            now(),
            'Personal Court',
            'Personal Court',
            personal_org_id
        );
    END LOOP;
END $$;

COMMENT ON INDEX skwsh_org_settings_personal_owner_key IS
    'Every registered identity owns exactly one Personal Free or Personal Plus organisation; club memberships are associations on that identity.';
