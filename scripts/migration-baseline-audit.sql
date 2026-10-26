-- Read-only audit for baselining legacy RcktScore migrations 001-042.
-- Run the complete statement in the Supabase SQL Editor and export the result.
-- A PASS means the current database retains the material schema/data outcome
-- required by that migration; it does not assert when or how it was applied.

WITH expected_objects(version, check_name, object_kind, relation_name, object_name) AS (
    VALUES
        (1, 'matches table', 'relation', 'public.matches', NULL),
        (1, 'match_events table', 'relation', 'public.match_events', NULL),
        (1, 'matches tenant/status index', 'relation', 'public.idx_matches_tenant_status_updated', NULL),
        (1, 'match events created index', 'relation', 'public.idx_match_events_match_created', NULL),
        (2, 'organisation postcode', 'column', 'public."SkwshOrgSettings"', 'org_postcode'),
        (3, 'player 1 handedness', 'column', 'public.matches', 'player1_handedness'),
        (3, 'player 2 handedness', 'column', 'public.matches', 'player2_handedness'),
        (4, 'organisation username key', 'relation', 'public.skwsh_org_users_org_username_key', NULL),
        (4, 'username lookup index', 'relation', 'public.skwsh_org_users_username_lookup_idx', NULL),
        (5, 'approval status', 'column', 'public."SkwshOrgUsers"', 'approval_status'),
        (5, 'approval token', 'column', 'public."SkwshOrgUsers"', 'approval_token'),
        (5, 'approval token index', 'relation', 'public.skwsh_org_users_approval_token_key', NULL),
        (6, 'password reset token', 'column', 'public."SkwshOrgUsers"', 'password_reset_token'),
        (6, 'password reset index', 'relation', 'public.skwsh_org_users_password_reset_token_idx', NULL),
        (7, 'interest requests table', 'relation', 'public."HitnScoreInterestRequests"', NULL),
        (7, 'personal plan constraint', 'constraint', 'public."HitnScoreInterestRequests"', 'hitnscore_interest_requests_personal_plan_check'),
        (8, 'personal plan column', 'column', 'public."HitnScoreInterestRequests"', 'personal_plan'),
        (8, 'personal account index', 'relation', 'public.hitnscore_interest_requests_personal_accounts_idx', NULL),
        (9, 'personal organisation sequence', 'relation', 'public.hitnscore_personal_org_id_seq', NULL),
        (9, 'organisation type', 'column', 'public."SkwshOrgSettings"', 'org_type'),
        (9, 'organisation plan', 'column', 'public."SkwshOrgSettings"', 'plan'),
        (9, 'personal owner', 'column', 'public."SkwshOrgSettings"', 'owner_username'),
        (9, 'personal owner index', 'relation', 'public.skwsh_org_settings_personal_owner_key', NULL),
        (10, 'player 1 shirt colour', 'column', 'public.matches', 'player1_shirt_color'),
        (10, 'player 2 shirt colour', 'column', 'public.matches', 'player2_shirt_color'),
        (10, 'player 1 shirt constraint', 'constraint', 'public.matches', 'matches_player1_shirt_color_check'),
        (10, 'player 2 shirt constraint', 'constraint', 'public.matches', 'matches_player2_shirt_color_check'),
        (11, 'match duration', 'column', 'public.matches', 'match_duration_seconds'),
        (12, 'organisation sessions table', 'relation', 'public.org_user_sessions', NULL),
        (12, 'organisation session token index', 'relation', 'public.org_user_sessions_token_hash_key', NULL),
        (13, 'court display code', 'column', 'public."SkwshCourts"', 'display_code'),
        (13, 'court display sessions', 'relation', 'public.court_display_sessions', NULL),
        (14, 'organisation enabled sports', 'column', 'public."SkwshOrgSettings"', 'enabled_sports'),
        (15, 'user telephone', 'column', 'public."SkwshOrgUsers"', 'telephone'),
        (16, 'match archive flag', 'column', 'public.matches', 'is_archived'),
        (16, 'match archive index', 'relation', 'public.idx_matches_archived_status_updated', NULL),
        (17, 'platform settings table', 'relation', 'public.platform_settings', NULL),
        (18, 'root admin sessions', 'relation', 'public.root_admin_sessions', NULL),
        (18, 'root admin active index', 'relation', 'public.root_admin_sessions_active_admin_key', NULL),
        (19, 'session expiry', 'column', 'public.org_user_sessions', 'expires_at'),
        (19, 'action receipts table', 'relation', 'public.match_action_receipts', NULL),
        (20, 'club interest status index', 'relation', 'public.hitnscore_club_interest_approval_idx', NULL),
        (21, 'Golden Point flag', 'column', 'public.matches', 'tennis_no_ad_scoring'),
        (21, 'final-set tiebreak flag', 'column', 'public.matches', 'tennis_final_set_match_tiebreak'),
        (22, 'requested plan', 'column', 'public."HitnScoreInterestRequests"', 'requested_plan'),
        (22, 'club address', 'column', 'public."HitnScoreInterestRequests"', 'club_address'),
        (22, 'personal interest key', 'relation', 'public.hitnscore_personal_interest_email_key', NULL),
        (22, 'club interest key', 'relation', 'public.hitnscore_club_interest_request_key', NULL),
        (23, 'notifications table', 'relation', 'public.system_notifications', NULL),
        (23, 'notification reads table', 'relation', 'public.system_notification_reads', NULL),
        (24, 'App Store subscriptions', 'relation', 'public.app_store_subscriptions', NULL),
        (24, 'App Store events', 'relation', 'public.app_store_subscription_events', NULL),
        (25, 'app account token', 'column', 'public."SkwshOrgSettings"', 'app_account_token'),
        (25, 'app account token index', 'relation', 'public.skwsh_org_settings_app_account_token_key', NULL),
        (25, 'entitlement audit', 'relation', 'public.subscription_entitlement_audit', NULL),
        (25, 'account token assignment trigger', 'trigger', 'public."SkwshOrgSettings"', 'skwsh_org_settings_assign_app_account_token'),
        (26, 'subscription bundle id', 'column', 'public.app_store_subscriptions', 'bundle_id'),
        (26, 'App Store transactions', 'relation', 'public.app_store_transactions', NULL),
        (26, 'transaction account index', 'relation', 'public.app_store_transactions_account_idx', NULL),
        (27, 'renewal information', 'column', 'public.app_store_subscriptions', 'latest_renewal_info'),
        (27, 'notification retry index', 'relation', 'public.app_store_subscription_events_retry_idx', NULL),
        (27, 'entitlement append-only trigger', 'trigger', 'public.subscription_entitlement_audit', 'subscription_entitlement_audit_append_only'),
        (28, 'platform web sports', 'column', 'public.platform_settings', 'enabled_sports_web'),
        (28, 'platform iOS sports', 'column', 'public.platform_settings', 'enabled_sports_ios'),
        (28, 'membership web sports', 'column', 'public."SkwshOrgUsers"', 'enabled_sports_web'),
        (28, 'membership iOS sports', 'column', 'public."SkwshOrgUsers"', 'enabled_sports_ios'),
        (29, 'timed break defaults', 'column', 'public."SkwshOrgSettings"', 'timed_break_defaults'),
        (30, 'canonical users', 'relation', 'public.users', NULL),
        (30, 'membership identity', 'column', 'public."SkwshOrgUsers"', 'user_id'),
        (30, 'players table', 'relation', 'public.players', NULL),
        (30, 'player affiliations', 'relation', 'public.player_organization_affiliations', NULL),
        (30, 'tournament events', 'relation', 'public.tournament_events', NULL),
        (30, 'tournament entries', 'relation', 'public.tournament_entries', NULL),
        (30, 'membership identity trigger', 'trigger', 'public."SkwshOrgUsers"', 'skwsh_org_users_sync_identity'),
        (31, 'tournament organisation features', 'relation', 'public.tournament_organization_features', NULL),
        (32, 'tournament audience', 'column', 'public.tournament_events', 'audience'),
        (32, 'entry ability level', 'column', 'public.tournament_entries', 'ability_level'),
        (32, 'tournament draws', 'relation', 'public.tournament_draws', NULL),
        (33, 'Demo Club user table', 'relation', 'public."SkwshOrgUsers"', NULL),
        (34, 'tournament matches', 'relation', 'public.tournament_matches', NULL),
        (34, 'draw round index', 'relation', 'public.tournament_matches_draw_round_idx', NULL),
        (35, 'public draw key', 'column', 'public.tournament_events', 'public_draw_key'),
        (35, 'public draw key index', 'relation', 'public.tournament_events_public_draw_key_unique', NULL),
        (35, 'event seed index', 'relation', 'public.tournament_entries_event_seed_unique', NULL),
        (36, 'tournament match bracket', 'column', 'public.tournament_matches', 'bracket'),
        (36, 'scoring match link', 'column', 'public.tournament_matches', 'scoring_match_id'),
        (36, 'match tournament event', 'column', 'public.matches', 'tournament_event_id'),
        (36, 'match tournament fixture', 'column', 'public.matches', 'tournament_match_id'),
        (36, 'draw bracket index', 'relation', 'public.tournament_matches_draw_bracket_round_number_unique', NULL),
        (37, 'court sport', 'column', 'public."SkwshCourts"', 'sport'),
        (37, 'court sport constraint', 'constraint', 'public."SkwshCourts"', 'skwshcourts_sport_check'),
        (37, 'court sport index', 'relation', 'public.idx_skwshcourts_organization_sport', NULL),
        (38, 'viewer code', 'column', 'public.matches', 'viewer_code'),
        (38, 'viewed match profiles', 'relation', 'public.match_view_profiles', NULL),
        (39, 'timed match breaks', 'column', 'public.matches', 'tennis_timed_breaks'),
        (40, 'association competitions', 'column', 'public."SkwshOrgSettings"', 'association_competitions'),
        (41, 'tournament result outcome', 'column', 'public.tournament_matches', 'result_outcome'),
        (41, 'tournament result note', 'column', 'public.tournament_matches', 'result_note'),
        (41, 'result outcome constraint', 'constraint', 'public.tournament_matches', 'tournament_matches_result_outcome_check'),
        (42, 'event sequence', 'column', 'public.match_events', 'event_sequence'),
        (42, 'event actor', 'column', 'public.match_events', 'actor_username'),
        (42, 'event sequence generator', 'relation', 'public.match_events_event_sequence_seq', NULL),
        (42, 'event sequence unique index', 'relation', 'public.match_events_event_sequence_unique', NULL),
        (42, 'event compensation table', 'relation', 'public.match_event_compensations', NULL),
        (42, 'event compensation index', 'relation', 'public.match_event_compensations_match_idx', NULL)
),
object_checks AS (
    SELECT
        version,
        check_name,
        CASE object_kind
            WHEN 'relation' THEN to_regclass(relation_name) IS NOT NULL
            WHEN 'column' THEN EXISTS (
                SELECT 1
                FROM pg_attribute
                WHERE attrelid = to_regclass(relation_name)
                  AND attname = object_name
                  AND NOT attisdropped
            )
            WHEN 'constraint' THEN EXISTS (
                SELECT 1
                FROM pg_constraint
                WHERE conrelid = to_regclass(relation_name)
                  AND conname = object_name
            )
            WHEN 'trigger' THEN EXISTS (
                SELECT 1
                FROM pg_trigger
                WHERE tgrelid = to_regclass(relation_name)
                  AND tgname = object_name
                  AND NOT tgisinternal
            )
            ELSE false
        END AS passed
    FROM expected_objects
),
data_checks(version, check_name, passed) AS (
    SELECT 4, 'no obsolete username-only unique index', NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'SkwshOrgUsers'
          AND indexdef ILIKE 'CREATE UNIQUE INDEX%'
          AND indexdef ILIKE '%(clubusername)%'
          AND indexdef NOT ILIKE '%organization_id%'
    )
    UNION ALL
    SELECT 17, 'default platform row', EXISTS (
        SELECT 1 FROM platform_settings WHERE id = 'default'
    )
    UNION ALL
    SELECT 19, 'all sessions have an expiry', NOT EXISTS (
        SELECT 1 FROM org_user_sessions WHERE expires_at IS NULL
    )
    UNION ALL
    SELECT 20, 'personal registrations use registered status', NOT EXISTS (
        SELECT 1
        FROM "HitnScoreInterestRequests"
        WHERE use_type = 'personal'
          AND approval_status IS DISTINCT FROM 'registered'
    )
    UNION ALL
    SELECT 23, 'welcome notification seed', EXISTS (
        SELECT 1
        FROM system_notifications
        WHERE title = 'Welcome to Hit n Score'
          AND created_by = 'system'
    )
    UNION ALL
    SELECT 25, 'personal accounts have app account tokens', NOT EXISTS (
        SELECT 1
        FROM "SkwshOrgSettings"
        WHERE org_type = 'personal'
          AND app_account_token IS NULL
    )
    UNION ALL
    SELECT 28, 'platform client sport lists populated', NOT EXISTS (
        SELECT 1
        FROM platform_settings
        WHERE enabled_sports_web IS NULL OR enabled_sports_ios IS NULL
    )
    UNION ALL
    SELECT 29, 'timer defaults are objects', NOT EXISTS (
        SELECT 1
        FROM "SkwshOrgSettings"
        WHERE timed_break_defaults IS NULL
           OR jsonb_typeof(timed_break_defaults) <> 'object'
    )
    UNION ALL
    SELECT 30, 'memberships linked to canonical users', NOT EXISTS (
        SELECT 1
        FROM "SkwshOrgUsers"
        WHERE COALESCE(BTRIM(clubusername), '') <> ''
          AND user_id IS NULL
    )
    UNION ALL
    SELECT 31, 'Demo Club tournament feature seed', EXISTS (
        SELECT 1
        FROM tournament_organization_features feature
        JOIN "SkwshOrgSettings" organization
          ON organization.id = feature.organization_id
        WHERE LOWER(organization.organization_name) = 'demo club'
          AND feature.web_enabled = true
    )
    UNION ALL
    SELECT 32, 'every tournament has a draw group', NOT EXISTS (
        SELECT 1
        FROM tournament_events event
        WHERE NOT EXISTS (
            SELECT 1 FROM tournament_draws draw
            WHERE draw.tournament_id = event.id
        )
    )
    UNION ALL
    SELECT 33, 'eight seeded Demo Club players', (
        SELECT COUNT(DISTINCT LOWER(user_account.clubusername)) = 8
        FROM "SkwshOrgUsers" user_account
        JOIN "SkwshOrgSettings" organization
          ON organization.id = user_account.organization_id
        WHERE LOWER(organization.organization_name) = 'demo club'
          AND LOWER(user_account.clubusername) IN (
              'demoplayone@democlub.com',
              'demoplaytwo@democlub.com',
              'demoplaythree@democlub.com',
              'demoplayfour@democlub.com',
              'demoplayfive@democlub.com',
              'demoplaysix@democlub.com',
              'demoplayseven@democlub.com',
              'demoplayeight@democlub.com'
          )
    )
    UNION ALL
    SELECT 42, 'all events have canonical sequence', NOT EXISTS (
        SELECT 1 FROM match_events WHERE event_sequence IS NULL
    )
),
all_checks AS (
    SELECT * FROM object_checks
    UNION ALL
    SELECT * FROM data_checks
),
versions AS (
    SELECT generate_series(1, 42) AS version
)
SELECT
    LPAD(version.version::text, 3, '0') AS migration,
    CASE WHEN BOOL_AND(COALESCE(all_checks.passed, false)) THEN 'PASS' ELSE 'FAIL' END AS status,
    COUNT(all_checks.version) AS checks_run,
    COALESCE(
        STRING_AGG(all_checks.check_name, '; ' ORDER BY all_checks.check_name)
            FILTER (WHERE NOT all_checks.passed),
        ''
    ) AS failed_checks
FROM versions version
LEFT JOIN all_checks ON all_checks.version = version.version
GROUP BY version.version
ORDER BY version.version;
