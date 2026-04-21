ALTER TABLE "SkwshOrgUsers"
    ADD COLUMN IF NOT EXISTS password_reset_token text,
    ADD COLUMN IF NOT EXISTS password_reset_requested_at timestamptz;

CREATE INDEX IF NOT EXISTS skwsh_org_users_password_reset_token_idx
    ON "SkwshOrgUsers" (password_reset_token)
    WHERE password_reset_token IS NOT NULL;
