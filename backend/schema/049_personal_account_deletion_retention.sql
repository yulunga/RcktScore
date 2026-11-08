ALTER TABLE "SkwshOrgSettings"
    ADD COLUMN IF NOT EXISTS deletion_requested_at timestamptz,
    ADD COLUMN IF NOT EXISTS deletion_purge_after timestamptz;

CREATE INDEX IF NOT EXISTS skwsh_org_settings_deletion_purge_due_idx
    ON "SkwshOrgSettings" (deletion_purge_after)
    WHERE org_type = 'personal'
      AND deletion_requested_at IS NOT NULL;

COMMENT ON COLUMN "SkwshOrgSettings".deletion_requested_at IS
    'When the Personal owner requested account deletion. Access is revoked immediately while data remains visible to Root Admin.';

COMMENT ON COLUMN "SkwshOrgSettings".deletion_purge_after IS
    'Earliest time the scheduled clearing job may permanently remove the Personal tenant and its owned match data.';
