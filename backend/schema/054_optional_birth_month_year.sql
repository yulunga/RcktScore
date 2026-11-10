ALTER TABLE "SkwshOrgUsers"
    ADD COLUMN IF NOT EXISTS birth_month smallint,
    ADD COLUMN IF NOT EXISTS birth_year smallint;

ALTER TABLE "SkwshOrgUsers"
    DROP CONSTRAINT IF EXISTS skwsh_org_users_birth_month_check,
    ADD CONSTRAINT skwsh_org_users_birth_month_check
        CHECK (birth_month IS NULL OR birth_month BETWEEN 1 AND 12),
    DROP CONSTRAINT IF EXISTS skwsh_org_users_birth_year_check,
    ADD CONSTRAINT skwsh_org_users_birth_year_check
        CHECK (birth_year IS NULL OR birth_year BETWEEN 1900 AND 2100);

COMMENT ON COLUMN "SkwshOrgUsers".birth_month IS
    'Optional birth month for the shared signed-in identity profile; day of birth is deliberately not collected.';
COMMENT ON COLUMN "SkwshOrgUsers".birth_year IS
    'Optional birth year for the shared signed-in identity profile.';
