ALTER TABLE "SkwshOrgUsers"
    ADD COLUMN IF NOT EXISTS approval_status text NOT NULL DEFAULT 'approved',
    ADD COLUMN IF NOT EXISTS approval_token text,
    ADD COLUMN IF NOT EXISTS invitation_sent_at timestamptz,
    ADD COLUMN IF NOT EXISTS approved_at timestamptz;

UPDATE "SkwshOrgUsers"
SET
    approval_status = 'approved',
    approved_at = COALESCE(approved_at, created_at)
WHERE approval_status IS DISTINCT FROM 'approved'
  AND approval_status IS DISTINCT FROM 'pending';

CREATE UNIQUE INDEX IF NOT EXISTS skwsh_org_users_approval_token_key
    ON "SkwshOrgUsers" (approval_token)
    WHERE approval_token IS NOT NULL;
