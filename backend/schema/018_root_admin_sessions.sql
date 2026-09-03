CREATE TABLE IF NOT EXISTS root_admin_sessions (
    id bigserial PRIMARY KEY,
    root_admin_id bigint NOT NULL REFERENCES "SkRootAdmin" (id) ON DELETE CASCADE,
    token_hash text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT NOW(),
    expires_at timestamptz NOT NULL,
    last_seen_at timestamptz NOT NULL DEFAULT NOW(),
    revoked_at timestamptz,
    revoked_reason text
);

CREATE UNIQUE INDEX IF NOT EXISTS root_admin_sessions_token_hash_key
    ON root_admin_sessions (token_hash);

CREATE UNIQUE INDEX IF NOT EXISTS root_admin_sessions_active_admin_key
    ON root_admin_sessions (root_admin_id)
    WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS root_admin_sessions_expires_at_idx
    ON root_admin_sessions (expires_at);
