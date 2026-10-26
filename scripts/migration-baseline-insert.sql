-- One-time baseline for the current pre-release Supabase database.
-- Prepared after all migrations 001-042 passed migration-baseline-audit.sql
-- and migrations 043-044 were separately verified on 26 October 2026.
-- Do not reuse this file for another database without repeating that audit.

BEGIN;

SELECT pg_advisory_xact_lock(72658742001);

DO $$
DECLARE
    profile_column_count integer;
BEGIN
    IF to_regclass('public.schema_migrations') IS NULL THEN
        RAISE EXCEPTION 'schema_migrations is not installed';
    END IF;

    IF EXISTS (SELECT 1 FROM public.schema_migrations) THEN
        RAISE EXCEPTION 'schema_migrations is not empty; refusing to baseline';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_class
        WHERE oid = 'public.schema_migrations'::regclass
          AND relrowsecurity
    ) THEN
        RAISE EXCEPTION 'schema_migrations row-level security is not enabled';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.schema_migrations'::regclass
          AND tgname = 'schema_migrations_append_only'
          AND NOT tgisinternal
    ) OR NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.schema_migrations'::regclass
          AND tgname = 'schema_migrations_no_truncate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'schema_migrations append-only protection is incomplete';
    END IF;

    SELECT COUNT(*)
    INTO profile_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'SkwshOrgUsers'
      AND column_name IN ('first_name', 'surname', 'country', 'city_location');

    IF profile_column_count <> 4
       OR to_regclass('public.skwsh_org_users_profile_lookup_idx') IS NULL THEN
        RAISE EXCEPTION 'migration 044 profile reconciliation is incomplete';
    END IF;
END;
$$;

WITH baseline(version, filename, checksum_sha256, notes) AS (
    VALUES
        (1, '001_match_storage.sql', '9d694663bfeb67969ee2e9ccb5b0a468fb4f182fb7388b2ce0f60b0008bb25d7', 'verified legacy baseline'),
        (2, '002_org_postcode.sql', '37eb3e35a58d81847613d8aaae963668c49fef2ee3675115d1fa5ce8cc9e4249', 'verified legacy baseline'),
        (3, '003_match_handedness.sql', 'e649f86a96581c977a52695548580bef3af6dd8efae3bb7930db61f663fa595e', 'verified legacy baseline'),
        (4, '004_multi_org_user_membership.sql', '1c921342821b6bb03dee83e9539743f9aa1b39454954770d42a89fc9c01a31b9', 'verified legacy baseline'),
        (5, '005_org_user_email_invites.sql', 'fa995b4b26ab7729fd26d129943c39bc76170918b9f5d77428e3538ae8c6b3e5', 'verified legacy baseline'),
        (6, '006_password_reset.sql', '0797dfdb284b9756d57ecdd3789f2da6079c6486f769106d759eea18e17a5956', 'verified legacy baseline'),
        (7, '007_interest_requests.sql', 'd3dab642ae26a7409449a38a1dffe4307140be399523959da4b58c7135913c37', 'verified legacy baseline'),
        (8, '008_personal_account_plans.sql', '64b2678ba3274b8b7b9dc7938981b77639d636f595703d41a1c898a9c5c978cc', 'verified legacy baseline'),
        (9, '009_personal_organizations.sql', '521c279bb390bb24f3e1a0e9b99c32a17e39191e6173bff4c524216c8e6be244', 'verified legacy baseline'),
        (10, '010_match_shirt_colors.sql', 'bf9df2937d8f6f42c68418d9dd720d6d68f5c369f2b9c065c61efd3b1b2d6ce3', 'verified legacy baseline'),
        (11, '011_match_duration.sql', '15d35f36a2f0e772f2e5d45c19f3248551bf678d00feef6f4c0758d0764d6578', 'verified legacy baseline'),
        (12, '012_org_user_sessions.sql', 'f183e70bbda19ab70adcc99ff986d38aa064dad490a743ef607498364306a38b', 'verified legacy baseline'),
        (13, '013_scoreboard_display_access.sql', 'e71a343df80f2c81a1fc6faf5631af6790cc5fd1f62b3680e9aaf8a1264a4cfd', 'verified legacy baseline'),
        (14, '014_enabled_sports.sql', '9d5614312ebce2053034acc35c9031a0d7e27c95dbccb5f1d7075e61e13d9863', 'verified legacy baseline'),
        (15, '015_user_profile_contact_fields.sql', '4060a90de1304364916b0be3523faa9789c5be9ed184add42031b959677f39d9', 'verified legacy baseline'),
        (16, '016_match_archive.sql', 'b046a1a2a80d107f4637606f9aa7ac041ed1d0e06a060645ac5529f95a0d2e06', 'verified legacy baseline'),
        (17, '017_platform_enabled_sports.sql', '2186aa7911983d2bc9b116aedbba3d3f1a5894d458d015fa431aef72ee6aac48', 'verified legacy baseline'),
        (18, '018_root_admin_sessions.sql', 'a19156b6ee9c9408b2f5590939d883406c6c983904a6b5243a84dd3eaa5b02ab', 'verified legacy baseline'),
        (19, '019_offline_scoring_support.sql', '8d03ab69456ff5e5ee81a24c982bad3a73161484d7cfae4b58bf8b113b717766', 'verified legacy baseline'),
        (20, '020_personal_registration_status.sql', '291b2bdbc04ccf9dd6e2f9b46fe46dfd7ab3737cf02e5a66965b6caf23a2773e', 'verified legacy baseline'),
        (21, '021_tennis_scoring_formats.sql', 'e0b6bd4738338b4eb19ce101ea5dbbbef6ad26682489598e0dbf20c91c600df6', 'verified legacy baseline'),
        (22, '022_club_subscription_enquiries.sql', '08faf4c93aa84b7b17458334a2609868117fa5d4a5f996d8bdaa1cb4900bf7e5', 'verified legacy baseline'),
        (23, '023_system_notifications.sql', '770eab8e07cd74ad98bf5cb2abfac6ad9c591223debf1b139577b89daacbedf7', 'verified legacy baseline'),
        (24, '024_app_store_subscription_lifecycle.sql', '191bde2ed2baf74fbed5d6a5cadedbb98f55782ebd017aacdf48c81c90e31db4', 'verified legacy baseline'),
        (25, '025_apple_subscription_account_identity.sql', '6326cf6ab0fd06467a196b03b181e77be56d41e3103d031745925827feaff189', 'verified legacy baseline'),
        (26, '026_apple_purchase_verification.sql', '87ea05a92db9c3f58126a795c44df0b1ab06f63e6a0a0c11d78ffacab343cb85', 'verified legacy baseline'),
        (27, '027_apple_subscription_lifecycle_processing.sql', '6695153c970033c7e56aae04c64000d5ea0079c6eb9bfb818ca54db2623a2952', 'verified legacy baseline'),
        (28, '028_client_sport_access.sql', 'd166db367f93f3681fb4df840234119518314d92b4b7e1cc0c5466becb920c21', 'verified legacy baseline'),
        (29, '029_timed_break_defaults.sql', 'a64ee59744ee50d3e92e36134c38d46528ddad09a5bd2c96bd620baf4fd085d4', 'verified legacy baseline'),
        (30, '030_tournament_foundation.sql', '62a6c243450abce99b4a0bd52a7440fd0ab4dce06730875fe96a78cf55ade17e', 'verified legacy baseline'),
        (31, '031_tournament_demo_club.sql', '1638e136103099ef0ec781a0210afb9855945fd731cf7caadaa056d1c508f2a3', 'verified legacy baseline'),
        (32, '032_tournament_event_options.sql', '4ac7da17ea205cfcdea83fa4e4bfca0703a7c43e5f5f24c4f276febafbe7d837', 'verified legacy baseline'),
        (33, '033_demo_club_players.sql', 'e126fb4058cdbbb22711cae66c99f2ecb6d19090ba699d02dccb573e1deba039', 'verified legacy baseline'),
        (34, '034_tournament_draw_matches.sql', '187e2e8c03baa18347d987a8e9bbb18a76d1c8def525ea95cf34e091f7d0b442', 'verified legacy baseline'),
        (35, '035_tournament_draw_publication.sql', 'dc56f80161f6cd3110494f386017846a3fe3355573aba122a139af73d6a15222', 'verified legacy baseline'),
        (36, '036_tournament_match_results.sql', '183b0b942a3868c874fb8ae3e50d16142cb55336fb9f8f44940b423fb079505d', 'verified legacy baseline'),
        (37, '037_court_sports.sql', '374af982643f7f3595fd096a2264e9e0eb4dd8c57549509b7db733c65b6dbba7', 'verified legacy baseline'),
        (38, '038_personal_plus_match_watch.sql', 'a1ac1c91ca5ffa71874f8f805bffb703f34436d4d9a92f08f2153b010ef659ab', 'verified legacy baseline'),
        (39, '039_match_timed_breaks.sql', 'cbd660cd6ea509fa76120dca899e3d31b30f413c4f621818e5a608f9bec8c967', 'verified legacy baseline'),
        (40, '040_association_competitions.sql', 'a9b962aea04facc5d279e64a01d466609ffdf1a0233c654023e6d4c8b76a14d0', 'verified legacy baseline'),
        (41, '041_tournament_match_outcomes.sql', '2b75c54176efe968aec08bea5662f2a971530654c1d4020a45cd4471c7b0d862', 'verified legacy baseline'),
        (42, '042_append_only_match_events.sql', '2424fa71ccc9617fdd7071870a4d32c88c8d91f32d1d618256e17fd66d6423f9', 'verified legacy baseline'),
        (43, '043_schema_migration_ledger.sql', '577f6f74cd8845ed626db68dd1573a7bb2d53f83096f59e46d36c307ae7cd0c7', 'ledger bootstrap verified'),
        (44, '044_reconcile_user_profile_fields.sql', '4226c00df9ae02aef0ce3109884027ce34e6a5c068e8fc71d051eabdddb44e93', 'profile reconciliation verified')
)
INSERT INTO public.schema_migrations (
    version,
    filename,
    checksum_sha256,
    applied_at,
    applied_by,
    git_commit,
    execution_ms,
    notes
)
SELECT
    version,
    filename,
    checksum_sha256,
    statement_timestamp(),
    current_user,
    'c825c8c2560a1c82066d2c9aca1fa537b9002061',
    NULL,
    notes
FROM baseline
ORDER BY version;

DO $$
BEGIN
    IF (SELECT COUNT(*) FROM public.schema_migrations) <> 44 THEN
        RAISE EXCEPTION 'baseline did not produce exactly 44 ledger rows';
    END IF;
END;
$$;

COMMIT;

SELECT
    COUNT(*) AS ledger_rows,
    MIN(version) AS first_version,
    MAX(version) AS latest_version,
    COUNT(DISTINCT checksum_sha256) AS distinct_checksums,
    BOOL_AND(git_commit = 'c825c8c2560a1c82066d2c9aca1fa537b9002061') AS commit_matches
FROM public.schema_migrations;
