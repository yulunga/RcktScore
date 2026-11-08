-- Run the entire script in the intended Supabase SQL Editor.
-- First run is read-only. List reviewed versions in versions_to_record to append passing rows.
-- Set confirmed_048_cutover only with evidence that both original UPDATEs ran.
-- Compare the reported checks with the checked-in files and your SQL history.

WITH options AS (
    SELECT ARRAY[]::integer[] AS versions_to_record, false AS confirmed_048_cutover
),
expected(version, filename, checksum) AS (
    VALUES
        (44, '044_reconcile_user_profile_fields.sql', '4226c00df9ae02aef0ce3109884027ce34e6a5c068e8fc71d051eabdddb44e93'),
        (45, '045_club_least_privilege_roles.sql', 'afe6f2976948ff238c1327b0296305acefa0ee86c85ec8d3943c0fbf6bcc6803'),
        (46, '046_restrict_root_admin_table_access.sql', 'bb445f061d849998db8ae3c74e2a78155089057c3abfcdc2ccb5be8f0393a80d'),
        (47, '047_personal_account_for_every_identity.sql', 'e440a1d6278b6fcaebc78839314614d0839a5fb3a13a6502c0fc27abc003d5bb'),
        (48, '048_browser_cookie_csrf_sessions.sql', '15e8e31b3f634e28c704abaa8bcb49e815d05cf41968a3b61125233fd13cebc2'),
        (49, '049_personal_account_deletion_retention.sql', '21d03b2e9e8321b74f62f6750627f9a6733ae803313f1ee194f2f9ed5fa80dea'),
        (50, '050_analytics_setup_and_exports.sql', '29f30ba1fd6da8f57d08e7ce2ed49783ebd62f6302d403869a8c49b34aa3ad19')
),
columns AS (
    SELECT * FROM information_schema.columns WHERE table_schema = 'public'
),
indexes AS (
    SELECT * FROM pg_indexes WHERE schemaname = 'public'
),
checks(version, passed, evidence) AS (
    SELECT 44, (
        SELECT count(*) = 4 FROM columns WHERE table_name = 'SkwshOrgUsers'
          AND column_name IN ('first_name', 'surname', 'country', 'city_location')
          AND data_type = 'text'
    ) AND EXISTS (
        SELECT 1 FROM indexes WHERE indexname = 'skwsh_org_users_profile_lookup_idx'
          AND tablename = 'SkwshOrgUsers' AND indexdef LIKE '%(organization_id, lower(%clubusername%'
    ), 'Four text profile columns and lookup index'
    UNION ALL
    SELECT 45, EXISTS (
        SELECT 1 FROM columns WHERE table_name = 'SkwshOrgUsers' AND column_name = 'role'
          AND is_nullable = 'NO' AND column_default LIKE '''scorer''%'
    ) AND EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public."SkwshOrgUsers"'::regclass
          AND conname = 'skwsh_org_users_role_check' AND convalidated
          AND pg_get_constraintdef(oid) LIKE '%''admin''%''scorer''%''read_only''%'
    ) AND NOT EXISTS (
        SELECT 1 FROM public."SkwshOrgUsers"
        WHERE role IS NULL OR role NOT IN ('admin', 'scorer', 'read_only')
    ), 'Role default, validated constraint and existing values'
    UNION ALL
    SELECT 46, to_regclass('public."SkRootAdmin"') IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM pg_class c
        CROSS JOIN LATERAL aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) acl
        WHERE c.oid = to_regclass('public."SkRootAdmin"')
          AND (acl.grantee = 0 OR acl.grantee IN (
              SELECT oid FROM pg_roles WHERE rolname IN ('anon', 'authenticated')
          ))
        UNION ALL
        SELECT 1 FROM pg_attribute a CROSS JOIN LATERAL aclexplode(a.attacl) acl
        WHERE a.attrelid = to_regclass('public."SkRootAdmin"') AND a.attnum > 0 AND NOT a.attisdropped
          AND (acl.grantee = 0 OR acl.grantee IN (
              SELECT oid FROM pg_roles WHERE rolname IN ('anon', 'authenticated')
          ))
    ), 'No direct table or column grants to PUBLIC, anon or authenticated'
    UNION ALL
    SELECT 47, EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgrelid = 'public."SkwshOrgUsers"'::regclass
          AND tgname = 'skwsh_org_users_require_personal_account'
          AND tgenabled IN ('O', 'A') AND tgdeferrable AND tginitdeferred
          AND tgfoid = to_regprocedure('public.enforce_personal_account_for_identity()')
          AND tgtype = 29
    ) AND NOT EXISTS (
        SELECT 1 FROM public."SkwshOrgUsers" u
        LEFT JOIN public."SkwshOrgSettings" o ON o.id = u.organization_id
        GROUP BY lower(u.clubusername)
        HAVING count(DISTINCT o.id) FILTER (WHERE o.org_type = 'personal') <> 1
    ), 'Enabled deferred trigger and exactly one Personal workspace per identity'
    UNION ALL
    SELECT 48, (SELECT confirmed_048_cutover FROM options) AND (
        SELECT count(*) = 2 FROM columns
        WHERE table_name IN ('org_user_sessions', 'root_admin_sessions')
          AND column_name = 'csrf_token' AND data_type = 'text'
    ), 'Two CSRF columns plus operator confirmation of original session revocations'
    UNION ALL
    SELECT 49, (
        SELECT count(*) = 2 FROM columns WHERE table_name = 'SkwshOrgSettings'
          AND column_name IN ('deletion_requested_at', 'deletion_purge_after')
          AND data_type = 'timestamp with time zone'
    ) AND EXISTS (
        SELECT 1 FROM indexes WHERE tablename = 'SkwshOrgSettings'
          AND indexname = 'skwsh_org_settings_deletion_purge_due_idx'
          AND indexdef LIKE '%(deletion_purge_after)%WHERE%org_type%''personal''%deletion_requested_at IS NOT NULL%'
    ), 'Both deletion timestamps and the expected partial index'
    UNION ALL
    SELECT 50, (
        SELECT count(*) = 9 FROM columns c
        JOIN (VALUES
            ('id', 'uuid', 'NO'), ('organization_id', 'bigint', 'NO'),
            ('actor_user_id', 'bigint', 'YES'), ('client_type', 'text', 'NO'),
            ('sport', 'text', 'NO'), ('started_at', 'timestamp with time zone', 'NO'),
            ('finished_at', 'timestamp with time zone', 'YES'), ('outcome', 'text', 'YES'),
            ('match_id', 'uuid', 'YES')
        ) AS e(name, kind, nullable)
          ON (c.column_name, c.data_type, c.is_nullable) = (e.name, e.kind, e.nullable)
        WHERE c.table_name = 'match_setup_sessions'
    ) AND (
        SELECT count(*) = 2 FROM columns
        WHERE table_name = 'match_setup_sessions'
          AND ((column_name = 'id' AND column_default = 'gen_random_uuid()')
            OR (column_name = 'started_at' AND column_default = 'now()'))
    ) AND (
        SELECT count(*) = 6 FROM pg_constraint
        WHERE conrelid = to_regclass('public.match_setup_sessions') AND convalidated
          AND (pg_get_constraintdef(oid) = 'PRIMARY KEY (id)'
            OR pg_get_constraintdef(oid) LIKE 'FOREIGN KEY (organization_id) REFERENCES %"SkwshOrgSettings"(id) ON DELETE CASCADE'
            OR pg_get_constraintdef(oid) LIKE 'FOREIGN KEY (actor_user_id) REFERENCES %"SkwshOrgUsers"(id) ON DELETE SET NULL'
            OR pg_get_constraintdef(oid) LIKE 'FOREIGN KEY (match_id) REFERENCES %matches(id) ON DELETE SET NULL'
            OR (conname = 'match_setup_sessions_client_type_check'
                AND pg_get_constraintdef(oid) LIKE 'CHECK%client_type%''web_app''%''mobile_app''%')
            OR (conname = 'match_setup_sessions_outcome_check'
                AND pg_get_constraintdef(oid) LIKE 'CHECK%outcome IS NULL%''completed''%''abandoned''%'))
    ) AND (
        SELECT count(*) = 2 FROM indexes WHERE tablename = 'match_setup_sessions'
          AND ((indexname = 'match_setup_sessions_org_started_idx' AND indexdef LIKE '%(organization_id, started_at DESC)')
            OR (indexname = 'match_setup_sessions_open_idx' AND indexdef LIKE '%(started_at) WHERE (outcome IS NULL)'))
    ), 'Analytics columns, defaults, six constraints and two indexes'
),
audit AS (
    SELECT e.*, c.passed, c.evidence,
           CASE WHEN l.version IS NULL THEN 'missing'
                WHEN (l.filename, l.checksum_sha256) = (e.filename, e.checksum) THEN 'matches'
                ELSE 'conflict' END AS ledger_status
    FROM expected e JOIN checks c USING (version)
    LEFT JOIN public.schema_migrations l USING (version)
),
recorded AS (
    INSERT INTO public.schema_migrations (version, filename, checksum_sha256, applied_by, notes)
    SELECT version, filename, checksum, current_user, 'Reconciled after manual Supabase SQL Editor execution'
    FROM audit
    WHERE version = ANY ((SELECT versions_to_record FROM options)::integer[])
      AND passed AND ledger_status = 'missing'
      AND NOT EXISTS (SELECT 1 FROM audit WHERE ledger_status = 'conflict')
    RETURNING version
)
SELECT a.version, a.filename, a.passed AS checks_passed, a.evidence,
       a.ledger_status AS ledger_before, r.version IS NOT NULL AS recorded_now
FROM audit a LEFT JOIN recorded r USING (version)
ORDER BY a.version;

