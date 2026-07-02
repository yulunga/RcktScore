ALTER TABLE matches
    ADD COLUMN IF NOT EXISTS is_archived boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS archived_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_matches_archived_status_updated
    ON matches (is_archived, status, updated_at DESC);
