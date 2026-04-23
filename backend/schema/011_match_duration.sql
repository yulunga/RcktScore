ALTER TABLE matches
    ADD COLUMN IF NOT EXISTS match_duration_seconds integer NOT NULL DEFAULT 0;

UPDATE matches
SET match_duration_seconds = 0
WHERE match_duration_seconds IS NULL;
