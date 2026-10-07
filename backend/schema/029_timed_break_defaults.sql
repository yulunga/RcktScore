ALTER TABLE "SkwshOrgSettings"
    ADD COLUMN IF NOT EXISTS timed_break_defaults jsonb NOT NULL DEFAULT
        '{"squash":false,"racketball":false,"tennis":false,"padel":false}'::jsonb;

UPDATE "SkwshOrgSettings"
SET timed_break_defaults = '{"squash":false,"racketball":false,"tennis":false,"padel":false}'::jsonb
WHERE timed_break_defaults IS NULL
   OR jsonb_typeof(timed_break_defaults) <> 'object';

COMMENT ON COLUMN "SkwshOrgSettings".timed_break_defaults IS
    'Per-sport defaults used to preselect optional warm-up and interval timers during match setup.';
