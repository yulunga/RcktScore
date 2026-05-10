ALTER TABLE "SkwshCourts"
    ADD COLUMN IF NOT EXISTS display_code text,
    ADD COLUMN IF NOT EXISTS display_code_enabled boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS display_code_created_at timestamptz,
    ADD COLUMN IF NOT EXISTS display_code_last_used_at timestamptz;

CREATE UNIQUE INDEX IF NOT EXISTS idx_skwshcourts_display_code_unique
    ON "SkwshCourts" (display_code)
    WHERE display_code IS NOT NULL;

CREATE TABLE IF NOT EXISTS court_display_sessions (
    id bigserial PRIMARY KEY,
    tenant_id bigint NOT NULL REFERENCES "SkwshOrgSettings"(id) ON DELETE CASCADE,
    court_id bigint NOT NULL REFERENCES "SkwshCourts"(id) ON DELETE CASCADE,
    token_hash text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    last_seen_at timestamptz NOT NULL DEFAULT now(),
    revoked_at timestamptz
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_court_display_sessions_token_hash
    ON court_display_sessions (token_hash);

CREATE INDEX IF NOT EXISTS idx_court_display_sessions_court_active
    ON court_display_sessions (court_id, expires_at DESC)
    WHERE revoked_at IS NULL;
