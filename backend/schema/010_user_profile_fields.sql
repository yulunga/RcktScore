ALTER TABLE "SkwshOrgUsers"
    ADD COLUMN IF NOT EXISTS first_name text,
    ADD COLUMN IF NOT EXISTS surname text,
    ADD COLUMN IF NOT EXISTS country text,
    ADD COLUMN IF NOT EXISTS city_location text;

CREATE INDEX IF NOT EXISTS skwsh_org_users_profile_lookup_idx
    ON "SkwshOrgUsers" (organization_id, LOWER(clubusername));
