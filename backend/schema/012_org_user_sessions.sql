CREATE TABLE IF NOT EXISTS org_user_sessions (
    id bigserial PRIMARY KEY,
    username text NOT NULL,
    token_hash text NOT NULL,
    login_source text NOT NULL DEFAULT 'login',
    created_at timestamptz NOT NULL DEFAULT NOW(),
    last_seen_at timestamptz NOT NULL DEFAULT NOW(),
    revoked_at timestamptz,
    revoked_reason text
);

CREATE UNIQUE INDEX IF NOT EXISTS org_user_sessions_token_hash_key
    ON org_user_sessions (token_hash);

CREATE INDEX IF NOT EXISTS org_user_sessions_active_username_idx
    ON org_user_sessions (LOWER(username))
    WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS org_user_sessions_created_at_idx
    ON org_user_sessions (created_at DESC);
