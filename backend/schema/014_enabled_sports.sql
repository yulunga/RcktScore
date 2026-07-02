ALTER TABLE "SkwshOrgSettings"
    ADD COLUMN IF NOT EXISTS enabled_sports jsonb NOT NULL DEFAULT '["squash","racketball","tennis"]'::jsonb;

UPDATE "SkwshOrgSettings"
SET enabled_sports = '["squash","racketball","tennis"]'::jsonb
WHERE enabled_sports IS NULL
   OR jsonb_typeof(enabled_sports) <> 'array'
   OR enabled_sports = '[]'::jsonb;
