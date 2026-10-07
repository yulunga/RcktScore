DO $$
DECLARE
    demo_organization_id bigint;
BEGIN
    SELECT id
    INTO demo_organization_id
    FROM "SkwshOrgSettings"
    WHERE LOWER(organization_name) = 'demo club'
      AND COALESCE(org_type, 'club') = 'club'
    ORDER BY id ASC
    LIMIT 1;

    IF demo_organization_id IS NULL THEN
        INSERT INTO "SkwshOrgSettings" (
            created_at,
            organization_name,
            org_contact,
            org_email,
            org_type,
            plan,
            enabled_sports,
            is_hidden
        )
        VALUES (
            now(),
            'Demo Club',
            'Demo User',
            'demouser@democlub.com',
            'club',
            'club_pro',
            '["squash","racketball","tennis","padel"]'::jsonb,
            false
        )
        RETURNING id INTO demo_organization_id;
    END IF;

    INSERT INTO tournament_organization_features (
        organization_id,
        web_enabled,
        enabled_by,
        enabled_at,
        updated_at
    )
    VALUES (
        demo_organization_id,
        true,
        'migration:031_tournament_demo_club',
        now(),
        now()
    )
    ON CONFLICT (organization_id) DO UPDATE
    SET web_enabled = true,
        enabled_by = EXCLUDED.enabled_by,
        enabled_at = COALESCE(tournament_organization_features.enabled_at, EXCLUDED.enabled_at),
        updated_at = EXCLUDED.updated_at;

    IF NOT EXISTS (
        SELECT 1
        FROM "SkwshOrgUsers"
        WHERE organization_id = demo_organization_id
          AND LOWER(clubusername) = 'demouser@democlub.com'
    ) THEN
        INSERT INTO "SkwshOrgUsers" (
            created_at,
            clubusername,
            password_hash,
            organization_id,
            role,
            first_name,
            surname,
            approval_status,
            approved_at
        )
        VALUES (
            now(),
            'demouser@democlub.com',
            'pbkdf2:sha256:600000$8c52c83a792cbe55$bae793dae687cb4957bd3c5d423fa62d45b9175388fcffd18a30eb5017a04f16',
            demo_organization_id,
            'admin',
            'Demo',
            'User',
            'approved',
            now()
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM "SkwshCourts"
        WHERE organization_name = demo_organization_id
    ) THEN
        INSERT INTO "SkwshCourts" (
            created_at,
            court_name,
            court_alias,
            organization_name
        )
        VALUES (
            now(),
            'Demo Court 1',
            'Court 1',
            demo_organization_id
        );
    END IF;
END $$;

COMMENT ON TABLE tournament_organization_features IS
    'Tournament Manager is disabled unless a club has an explicit web_enabled row. Demo Club is enabled by migration 031.';
