DO $$
DECLARE
    demo_organization_id bigint;
    demo_player record;
BEGIN
    SELECT id
    INTO demo_organization_id
    FROM "SkwshOrgSettings"
    WHERE LOWER(organization_name) = 'demo club'
      AND COALESCE(org_type, 'club') = 'club'
    ORDER BY id ASC
    LIMIT 1;

    IF demo_organization_id IS NULL THEN
        RAISE EXCEPTION 'Demo Club must exist before migration 033 is applied';
    END IF;

    FOR demo_player IN
        SELECT * FROM (VALUES
            ('demoplayone@democlub.com',   'Demo', 'PlayOne'),
            ('demoplaytwo@democlub.com',   'Demo', 'PlayTwo'),
            ('demoplaythree@democlub.com', 'Demo', 'PlayThree'),
            ('demoplayfour@democlub.com',  'Demo', 'PlayFour'),
            ('demoplayfive@democlub.com',  'Demo', 'PlayFive'),
            ('demoplaysix@democlub.com',   'Demo', 'PlaySix'),
            ('demoplayseven@democlub.com', 'Demo', 'PlaySeven'),
            ('demoplayeight@democlub.com', 'Demo', 'PlayEight')
        ) AS seed(email, first_name, surname)
    LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM "SkwshOrgUsers"
            WHERE organization_id = demo_organization_id
              AND LOWER(clubusername) = LOWER(demo_player.email)
        ) THEN
            INSERT INTO "SkwshOrgUsers" (
                created_at, clubusername, password_hash, organization_id,
                role, first_name, surname, approval_status, approved_at
            )
            VALUES (
                now(), demo_player.email,
                'pbkdf2:sha256:600000$8c52c83a792cbe55$bae793dae687cb4957bd3c5d423fa62d45b9175388fcffd18a30eb5017a04f16',
                demo_organization_id, 'user', demo_player.first_name,
                demo_player.surname, 'approved', now()
            );
        END IF;
    END LOOP;
END $$;
