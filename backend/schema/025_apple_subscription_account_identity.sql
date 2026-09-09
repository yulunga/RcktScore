-- Stable Apple-to-Hit n Score account identity and entitlement audit.
-- Apply after 024_app_store_subscription_lifecycle.sql.

ALTER TABLE "SkwshOrgSettings"
    ADD COLUMN IF NOT EXISTS app_account_token uuid;

-- Existing personal accounts receive their permanent token during migration.
-- New personal accounts can receive it lazily from the authenticated purchase
-- context endpoint, which also covers databases restored from older backups.
UPDATE "SkwshOrgSettings"
SET app_account_token = gen_random_uuid()
WHERE org_type = 'personal'
  AND app_account_token IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS skwsh_org_settings_app_account_token_key
    ON "SkwshOrgSettings" (app_account_token)
    WHERE app_account_token IS NOT NULL;

CREATE OR REPLACE FUNCTION assign_personal_app_account_token()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.org_type = 'personal' THEN
        NEW.app_account_token := COALESCE(NEW.app_account_token, gen_random_uuid());
    ELSE
        NEW.app_account_token := NULL;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS skwsh_org_settings_assign_app_account_token
    ON "SkwshOrgSettings";

CREATE TRIGGER skwsh_org_settings_assign_app_account_token
BEFORE INSERT OR UPDATE OF org_type, app_account_token
ON "SkwshOrgSettings"
FOR EACH ROW
EXECUTE FUNCTION assign_personal_app_account_token();

CREATE TABLE IF NOT EXISTS subscription_entitlement_audit (
    id bigserial PRIMARY KEY,
    -- Deliberately retained as an identifier rather than a cascading foreign
    -- key so deleting a personal account cannot erase its entitlement audit.
    organization_id bigint NOT NULL,
    account_username text,
    previous_plan text NOT NULL,
    new_plan text NOT NULL,
    source text NOT NULL,
    reason text NOT NULL,
    effective_at timestamptz NOT NULL,
    app_account_token uuid,
    original_transaction_id text,
    transaction_id text,
    notification_uuid text,
    actor_type text NOT NULL DEFAULT 'system',
    actor_identifier text,
    request_id text,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT subscription_entitlement_audit_previous_plan_check
        CHECK (previous_plan IN ('personal_free', 'personal_plus')),
    CONSTRAINT subscription_entitlement_audit_new_plan_check
        CHECK (new_plan IN ('personal_free', 'personal_plus')),
    CONSTRAINT subscription_entitlement_audit_source_check
        CHECK (source IN ('purchase', 'notification', 'reconciliation', 'admin')),
    CONSTRAINT subscription_entitlement_audit_actor_type_check
        CHECK (actor_type IN ('system', 'user', 'root_admin')),
    CONSTRAINT subscription_entitlement_audit_changed_plan_check
        CHECK (previous_plan <> new_plan)
);

CREATE INDEX IF NOT EXISTS subscription_entitlement_audit_account_idx
    ON subscription_entitlement_audit (organization_id, created_at DESC);

CREATE INDEX IF NOT EXISTS subscription_entitlement_audit_transaction_idx
    ON subscription_entitlement_audit (original_transaction_id, transaction_id);

CREATE INDEX IF NOT EXISTS subscription_entitlement_audit_notification_idx
    ON subscription_entitlement_audit (notification_uuid)
    WHERE notification_uuid IS NOT NULL;

COMMENT ON COLUMN "SkwshOrgSettings".app_account_token IS
    'Stable server-issued UUID supplied to StoreKit for purchases belonging to this personal account.';

COMMENT ON TABLE subscription_entitlement_audit IS
    'Append-only record of every effective personal subscription entitlement change.';
