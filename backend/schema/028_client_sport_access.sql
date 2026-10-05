ALTER TABLE platform_settings
    ADD COLUMN IF NOT EXISTS enabled_sports_web jsonb,
    ADD COLUMN IF NOT EXISTS enabled_sports_ios jsonb;

UPDATE platform_settings
SET enabled_sports_web = COALESCE(enabled_sports_web, enabled_sports),
    enabled_sports_ios = COALESCE(enabled_sports_ios, enabled_sports)
WHERE id = 'default';

ALTER TABLE platform_settings
    ALTER COLUMN enabled_sports_web SET DEFAULT '["squash","racketball","tennis"]'::jsonb,
    ALTER COLUMN enabled_sports_ios SET DEFAULT '["squash","racketball","tennis"]'::jsonb,
    ALTER COLUMN enabled_sports_web SET NOT NULL,
    ALTER COLUMN enabled_sports_ios SET NOT NULL;

ALTER TABLE "SkwshOrgUsers"
    ADD COLUMN IF NOT EXISTS enabled_sports_web jsonb,
    ADD COLUMN IF NOT EXISTS enabled_sports_ios jsonb;

COMMENT ON COLUMN "SkwshOrgUsers".enabled_sports_web IS
    'Per-membership web scoring access, capped by platform and organisation sport settings.';

COMMENT ON COLUMN "SkwshOrgUsers".enabled_sports_ios IS
    'Per-membership iOS scoring access, capped by platform and organisation sport settings.';
