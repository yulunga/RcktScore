-- Replace the broad legacy club `user` role with explicit scorer/read-only
-- roles. Existing users retain all match-operation capabilities as scorers.
DO $$
DECLARE
    constraint_row record;
BEGIN
    FOR constraint_row IN
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = '"SkwshOrgUsers"'::regclass
          AND contype = 'c'
          AND pg_get_constraintdef(oid) ILIKE '%role%'
    LOOP
        EXECUTE format(
            'ALTER TABLE "SkwshOrgUsers" DROP CONSTRAINT IF EXISTS %I',
            constraint_row.conname
        );
    END LOOP;
END
$$;

UPDATE "SkwshOrgUsers"
SET role = 'scorer'
WHERE role IS NULL OR LOWER(BTRIM(role)) = 'user';

ALTER TABLE "SkwshOrgUsers"
    ALTER COLUMN role SET DEFAULT 'scorer',
    ALTER COLUMN role SET NOT NULL;

ALTER TABLE "SkwshOrgUsers"
    ADD CONSTRAINT skwsh_org_users_role_check
    CHECK (role IN ('admin', 'scorer', 'read_only'));

COMMENT ON COLUMN "SkwshOrgUsers".role IS
    'Club capability role: admin, scorer, or read_only. Personal workspaces retain owner-level access.';
