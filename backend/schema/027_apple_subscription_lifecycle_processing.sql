-- Complete App Store subscription lifecycle state, notification processing,
-- scheduled reconciliation and root-admin visibility.
-- Apply after 026_apple_purchase_verification.sql.

ALTER TABLE app_store_subscriptions
    ADD COLUMN IF NOT EXISTS auto_renew_product_id text,
    ADD COLUMN IF NOT EXISTS grace_period_expires_at timestamptz,
    ADD COLUMN IF NOT EXISTS billing_retry_started_at timestamptz,
    ADD COLUMN IF NOT EXISTS expiration_intent integer,
    ADD COLUMN IF NOT EXISTS latest_renewal_info jsonb NOT NULL DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS last_status_source text,
    ADD COLUMN IF NOT EXISTS last_apple_signed_at timestamptz,
    ADD COLUMN IF NOT EXISTS last_notification_uuid text,
    ADD COLUMN IF NOT EXISTS last_notification_at timestamptz;

ALTER TABLE app_store_transactions
    ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'purchase',
    ADD COLUMN IF NOT EXISTS notification_uuid text;

ALTER TABLE app_store_subscription_events
    ADD COLUMN IF NOT EXISTS organization_id bigint,
    ADD COLUMN IF NOT EXISTS app_account_token uuid,
    ADD COLUMN IF NOT EXISTS transaction_id text,
    ADD COLUMN IF NOT EXISTS subscription_status_before text,
    ADD COLUMN IF NOT EXISTS subscription_status_after text,
    ADD COLUMN IF NOT EXISTS plan_before text,
    ADD COLUMN IF NOT EXISTS plan_after text,
    ADD COLUMN IF NOT EXISTS decoded_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS processing_attempt_count integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS next_processing_at timestamptz;

CREATE INDEX IF NOT EXISTS app_store_subscription_events_account_idx
    ON app_store_subscription_events (organization_id, verified_at DESC);

CREATE INDEX IF NOT EXISTS app_store_subscription_events_transaction_idx
    ON app_store_subscription_events (original_transaction_id, transaction_id);

CREATE INDEX IF NOT EXISTS app_store_subscription_events_retry_idx
    ON app_store_subscription_events (next_processing_at)
    WHERE processed_at IS NULL AND processing_error IS NOT NULL;

CREATE INDEX IF NOT EXISTS app_store_subscriptions_reconcile_due_idx
    ON app_store_subscriptions (next_reconciliation_at, last_reconciled_at, id)
    WHERE status IN ('active', 'billing_retry', 'grace_period', 'expired');

CREATE OR REPLACE FUNCTION reject_subscription_entitlement_audit_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'subscription_entitlement_audit is append-only';
END;
$$;

DROP TRIGGER IF EXISTS subscription_entitlement_audit_append_only
    ON subscription_entitlement_audit;

CREATE TRIGGER subscription_entitlement_audit_append_only
BEFORE UPDATE OR DELETE ON subscription_entitlement_audit
FOR EACH ROW
EXECUTE FUNCTION reject_subscription_entitlement_audit_mutation();

COMMENT ON COLUMN app_store_subscriptions.last_apple_signed_at IS
    'Ordering timestamp from the latest Apple-signed lifecycle payload applied to this subscription.';

COMMENT ON TABLE app_store_subscription_events IS
    'Verified App Store Server Notifications V2 receipt and processing history.';
