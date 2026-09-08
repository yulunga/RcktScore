-- Run manually against a non-production database after migrations.
-- Adds ten completed demo matches without changing the user's password or plan.
DO $$
DECLARE
    target_org_id bigint;
    target_court_id bigint;
    target_first_name text;
    target_surname text;
    demo_match_id uuid;
    demo_sport text;
    demo_won boolean;
    demo_index integer;
BEGIN
    SELECT u.organization_id, COALESCE(NULLIF(u.first_name, ''), 'Test'), COALESCE(NULLIF(u.surname, ''), 'Personal')
      INTO target_org_id, target_first_name, target_surname
      FROM "SkwshOrgUsers" u
      JOIN "SkwshOrgSettings" o ON o.id = u.organization_id
     WHERE LOWER(u.clubusername) = 'testpersonal@hitnscore.com'
       AND o.org_type = 'personal'
     ORDER BY u.id
     LIMIT 1;

    IF target_org_id IS NULL THEN
        RAISE EXCEPTION 'Personal account testpersonal@hitnscore.com was not found';
    END IF;

    SELECT id INTO target_court_id FROM "SkwshCourts" WHERE organization_name = target_org_id ORDER BY id LIMIT 1;
    IF target_court_id IS NULL THEN
        INSERT INTO "SkwshCourts" (created_at, court_name, court_alias, organization_name)
        VALUES (now(), 'Personal Match', 'Personal Match', target_org_id)
        RETURNING id INTO target_court_id;
    END IF;

    DELETE FROM matches WHERE tenant_id = target_org_id AND referee_name = 'Plus Demo Data';

    FOR demo_index IN 1..10 LOOP
        demo_match_id := gen_random_uuid();
        demo_sport := (ARRAY['squash', 'racketball', 'tennis'])[((demo_index - 1) % 3) + 1];
        demo_won := demo_index % 3 <> 0;

        INSERT INTO matches (
            id, tenant_id, court_id, court_name, court_alias, sport,
            player1_name, player1_surname, player2_name, player2_surname,
            referee_name, score_type, best_of, games_to_win, current_game_number,
            player1_games_won, player2_games_won, player1_final_score, player2_final_score,
            winner_side, winner_name, match_duration_seconds, status,
            created_at, completed_at, updated_at
        ) VALUES (
            demo_match_id, target_org_id, target_court_id, 'Personal Match', 'Personal Match', demo_sport,
            target_first_name, target_surname, 'Demo Opponent ' || demo_index, 'Player',
            'Plus Demo Data', CASE WHEN demo_sport = 'tennis' THEN 6 ELSE 11 END,
            CASE WHEN demo_index % 2 = 0 THEN 5 ELSE 3 END,
            CASE WHEN demo_index % 2 = 0 THEN 3 ELSE 2 END, 4,
            CASE WHEN demo_won THEN 3 ELSE 1 END, CASE WHEN demo_won THEN 1 ELSE 3 END,
            CASE WHEN demo_won THEN 11 ELSE 8 END, CASE WHEN demo_won THEN 8 ELSE 11 END,
            CASE WHEN demo_won THEN 'player1' ELSE 'player2' END,
            CASE WHEN demo_won THEN target_first_name ELSE 'Demo Opponent ' || demo_index END,
            1200 + (demo_index * 240), 'completed',
            now() - make_interval(days => demo_index * 3 + 1),
            now() - make_interval(days => demo_index * 3),
            now() - make_interval(days => demo_index * 3)
        );

        INSERT INTO match_events (id, match_id, tenant_id, event_type, payload, event_source, created_at)
        VALUES (
            gen_random_uuid(), demo_match_id, target_org_id, 'match_started',
            jsonb_build_object('current_server_side', 'player1', 'best_of', CASE WHEN demo_index % 2 = 0 THEN 5 ELSE 3 END),
            'test_fixture', now() - make_interval(days => demo_index * 3) - interval '30 minutes'
        );

        INSERT INTO match_events (id, match_id, tenant_id, event_type, payload, event_source, created_at)
        SELECT gen_random_uuid(), demo_match_id, target_org_id, 'score_point',
               jsonb_build_object(
                   'scorer', CASE WHEN (point_no <= 7 AND demo_won) OR (point_no > 7 AND NOT demo_won) THEN 'player1' ELSE 'player2' END,
                   'current_server_side', CASE WHEN point_no % 2 = 0 THEN 'player1' ELSE 'player2' END
               ),
               'test_fixture', now() - make_interval(days => demo_index * 3) - interval '20 minutes' + make_interval(secs => point_no)
          FROM generate_series(1, 12) AS point_no;
    END LOOP;
END $$;
