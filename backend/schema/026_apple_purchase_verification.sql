-- Verified device transaction ledger and reconciliation metadata.
-- Apply after 024_app_store_subscription_lifecycle.sql and
-- 025_apple_subscription_account_identity.sql.

ALTER TABLE app_store_subscriptions
    ADD COLUMN IF NOT EXISTS bundle_id text,
    ADD COLUMN IF NOT EXISTS app_apple_id bigint,
    ADD COLUMN IF NOT EXISTS app_transaction_id text,
    ADD COLUMN IF NOT EXISTS last_signed_transaction_sha256 text,
    ADD COLUMN IF NOT EXISTS last_reconciled_at timestamptz,
    ADD COLUMN IF NOT EXISTS reconciliation_error text,
    ADD COLUMN IF NOT EXISTS reconciliation_retry_count integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS next_reconciliation_at timestamptz;

CREATE UNIQUE INDEX IF NOT EXISTS app_store_subscriptions_latest_transaction_key
    ON app_store_subscriptions (latest_transaction_id)
    WHERE latest_transaction_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS app_store_subscriptions_stale_reconciliation_idx
    ON app_store_subscriptions (next_reconciliation_at, last_reconciled_at)
    WHERE status IN ('active', 'billing_retry', 'grace_period');

CREATE TABLE IF NOT EXISTS app_store_transactions (
    transaction_id text PRIMARY KEY,
    original_transaction_id text NOT NULL,
    organization_id bigint NOT NULL
        REFERENCES "SkwshOrgSettings"(id) ON DELETE CASCADE,
    account_username text NOT NULL,
    app_account_token uuid NOT NULL,
    product_id text NOT NULL,
    bundle_id text NOT NULL,
    app_apple_id bigint,
    app_transaction_id text NOT NULL,
    environment text NOT NULL
        CHECK (environment IN ('Sandbox', 'Production')),
    product_type text NOT NULL,
    transaction_reason text,
    purchased_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    signed_transaction_sha256 text NOT NULL,
    signed_transaction text NOT NULL,
    decoded_payload jsonb NOT NULL,
    verified_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS app_store_transactions_original_idx
    ON app_store_transactions (original_transaction_id, purchased_at DESC);

CREATE INDEX IF NOT EXISTS app_store_transactions_account_idx
    ON app_store_transactions (organization_id, app_account_token, verified_at DESC);

CREATE INDEX IF NOT EXISTS app_store_transactions_expiry_idx
    ON app_store_transactions (expires_at DESC);

COMMENT ON TABLE app_store_transactions IS
    'Append-only ledger of Apple-signed transactions accepted by the authenticated verification endpoint.';
