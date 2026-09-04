ALTER TABLE org_user_sessions
    ADD COLUMN IF NOT EXISTS expires_at timestamptz;

UPDATE org_user_sessions
SET expires_at = created_at + INTERVAL '30 days'
WHERE expires_at IS NULL;

ALTER TABLE org_user_sessions
    ALTER COLUMN expires_at SET DEFAULT (NOW() + INTERVAL '30 days'),
    ALTER COLUMN expires_at SET NOT NULL;

CREATE INDEX IF NOT EXISTS org_user_sessions_expires_at_idx
    ON org_user_sessions (expires_at);

CREATE TABLE IF NOT EXISTS match_action_receipts (
    client_action_id uuid PRIMARY KEY,
    match_id uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    action_type text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS match_action_receipts_match_created_idx
    ON match_action_receipts (match_id, created_at ASC);
