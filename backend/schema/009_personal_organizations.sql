CREATE SEQUENCE IF NOT EXISTS hitnscore_personal_org_id_seq
    START WITH 50000
    MINVALUE 50000
    INCREMENT BY 1;

SELECT setval(
    'hitnscore_personal_org_id_seq',
    GREATEST(
        COALESCE((SELECT MAX(id) FROM "SkwshOrgSettings" WHERE id >= 50000), 50000),
        50000
    ),
    COALESCE((SELECT MAX(id) FROM "SkwshOrgSettings" WHERE id >= 50000), 0) >= 50000
);

ALTER TABLE "SkwshOrgSettings"
    ADD COLUMN IF NOT EXISTS org_type text NOT NULL DEFAULT 'club',
    ADD COLUMN IF NOT EXISTS plan text NOT NULL DEFAULT 'club_essentials',
    ADD COLUMN IF NOT EXISTS owner_username text,
    ADD COLUMN IF NOT EXISTS interest_request_id bigint REFERENCES "HitnScoreInterestRequests"(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS is_hidden boolean NOT NULL DEFAULT false;

UPDATE "SkwshOrgSettings"
SET org_type = 'club'
WHERE org_type IS NULL;

UPDATE "SkwshOrgSettings"
SET plan = 'club_essentials'
WHERE plan IS NULL;

ALTER TABLE "SkwshOrgSettings"
    DROP CONSTRAINT IF EXISTS skwsh_org_settings_org_type_check;

ALTER TABLE "SkwshOrgSettings"
    ADD CONSTRAINT skwsh_org_settings_org_type_check
    CHECK (org_type IN ('club', 'personal'));

ALTER TABLE "SkwshOrgSettings"
    DROP CONSTRAINT IF EXISTS skwsh_org_settings_plan_check;

ALTER TABLE "SkwshOrgSettings"
    ADD CONSTRAINT skwsh_org_settings_plan_check
    CHECK (plan IN ('personal_free', 'personal_plus', 'club_essentials', 'club_pro'));

CREATE UNIQUE INDEX IF NOT EXISTS skwsh_org_settings_personal_owner_key
    ON "SkwshOrgSettings" (LOWER(owner_username))
    WHERE org_type = 'personal' AND owner_username IS NOT NULL;

CREATE INDEX IF NOT EXISTS skwsh_org_settings_org_type_idx
    ON "SkwshOrgSettings" (org_type);

CREATE INDEX IF NOT EXISTS skwsh_org_settings_plan_idx
    ON "SkwshOrgSettings" (plan);
