-- Run the entire file in the Supabase SQL Editor. Review the preview,
-- then set apply_changes to true and run the entire file again to apply.
BEGIN;
SET LOCAL lock_timeout = '5s';

DROP TABLE IF EXISTS pg_temp.racket_sport_report;
CREATE TEMP TABLE racket_sport_report (
    mode text,
    workspace_updates bigint,
    membership_overrides_cleared bigint,
    platform_update boolean,
    full_access_workspaces jsonb
);

DO $sports$
DECLARE
    apply_changes constant boolean := false;
    restricted_sports constant jsonb := '["squash", "racketball"]';
    implemented_ids constant text[] := ARRAY['squash', 'racketball', 'tennis', 'padel'];
    implemented_sports constant jsonb := to_jsonb(implemented_ids);
    workspace_changes bigint;
    membership_changes bigint;
    platform_needs_update boolean;
BEGIN
    IF apply_changes THEN
        LOCK TABLE platform_settings, "SkwshOrgSettings", "SkwshOrgUsers"
            IN SHARE ROW EXCLUSIVE MODE;
    END IF;

    CREATE TEMP TABLE racket_sport_targets ON COMMIT DROP AS
    SELECT org.id, org.org_type, org.organization_name, org.owner_username,
        CASE
            WHEN org.org_type = 'personal' THEN
                COALESCE(lower(btrim(org.owner_username)) = 'yulunga@gmail.com'
                    OR lower(btrim(org.owner_username)) LIKE 'demoplay%', false)
            ELSE lower(btrim(org.organization_name)) IN ('demo club', 'skwshclub')
        END AS full_access
    FROM "SkwshOrgSettings" AS org
    WHERE COALESCE(org.org_type, 'club') IN ('club', 'personal');

    SELECT count(*) INTO workspace_changes
    FROM "SkwshOrgSettings" AS org
    JOIN racket_sport_targets AS target ON target.id = org.id
    WHERE org.enabled_sports IS DISTINCT FROM
        CASE WHEN target.full_access THEN implemented_sports ELSE restricted_sports END;

    SELECT count(*) INTO membership_changes
    FROM "SkwshOrgUsers" AS member
    JOIN racket_sport_targets AS target ON target.id = member.organization_id
    WHERE target.full_access
      AND (member.enabled_sports_web IS NOT NULL OR member.enabled_sports_ios IS NOT NULL);

    SELECT NOT EXISTS (
        SELECT 1 FROM platform_settings
        WHERE id = 'default'
          AND enabled_sports @> implemented_sports
          AND enabled_sports_web @> implemented_sports
          AND enabled_sports_ios @> implemented_sports
    ) INTO platform_needs_update;

    INSERT INTO racket_sport_report
    SELECT
        CASE WHEN apply_changes THEN 'applied' ELSE 'preview' END,
        workspace_changes,
        membership_changes,
        platform_needs_update,
        COALESCE(jsonb_agg(jsonb_build_object(
            'workspace_id', id,
            'workspace', CASE WHEN org_type = 'personal' THEN owner_username ELSE organization_name END
        ) ORDER BY id), '[]'::jsonb)
    FROM racket_sport_targets
    WHERE full_access;

    IF NOT apply_changes THEN
        RETURN;
    END IF;

    -- The platform is an upper limit. Workspace settings enforce the restrictions.
    INSERT INTO platform_settings AS platform (
        id, enabled_sports, enabled_sports_web, enabled_sports_ios, updated_at
    )
    VALUES ('default', implemented_sports, implemented_sports, implemented_sports, now())
    ON CONFLICT (id) DO UPDATE
    SET enabled_sports = implemented_sports || (platform.enabled_sports - implemented_ids),
        enabled_sports_web = implemented_sports || (platform.enabled_sports_web - implemented_ids),
        enabled_sports_ios = implemented_sports || (platform.enabled_sports_ios - implemented_ids),
        updated_at = now()
    WHERE NOT (
        platform.enabled_sports @> implemented_sports
        AND platform.enabled_sports_web @> implemented_sports
        AND platform.enabled_sports_ios @> implemented_sports
    );

    UPDATE "SkwshOrgSettings" AS org
    SET enabled_sports = CASE WHEN target.full_access THEN implemented_sports ELSE restricted_sports END
    FROM racket_sport_targets AS target
    WHERE target.id = org.id
      AND org.enabled_sports IS DISTINCT FROM
          CASE WHEN target.full_access THEN implemented_sports ELSE restricted_sports END;

    -- NULL inherits the workspace list on that client. Other members keep
    -- any narrower permissions, with access capped by their workspace.
    UPDATE "SkwshOrgUsers" AS member
    SET enabled_sports_web = NULL, enabled_sports_ios = NULL
    FROM racket_sport_targets AS target
    WHERE target.id = member.organization_id
      AND target.full_access
      AND (member.enabled_sports_web IS NOT NULL OR member.enabled_sports_ios IS NOT NULL);
END;
$sports$;

COMMIT;

SELECT * FROM pg_temp.racket_sport_report;
