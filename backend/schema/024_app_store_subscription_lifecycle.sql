-- Persistence foundation for verified StoreKit / App Store Server subscription events.
-- Do not grant entitlements from an unverified device payload.
CREATE TABLE IF NOT EXISTS app_store_subscriptions (
    id bigserial PRIMARY KEY,
    organization_id bigint NOT NULL REFERENCES "SkwshOrgSettings"(id) ON DELETE CASCADE,
    username text NOT NULL,
    app_account_token uuid NOT NULL UNIQUE,
    original_transaction_id text NOT NULL UNIQUE,
    latest_transaction_id text,
    product_id text NOT NULL,
    environment text NOT NULL CHECK (environment IN ('Sandbox', 'Production')),
    status text NOT NULL CHECK (status IN ('active', 'expired', 'revoked', 'billing_retry', 'grace_period')),
    purchased_at timestamptz,
    expires_at timestamptz,
    revoked_at timestamptz,
    auto_renew_enabled boolean,
    last_verified_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app_store_subscription_events (
    id bigserial PRIMARY KEY,
    notification_uuid text UNIQUE,
    original_transaction_id text,
    notification_type text NOT NULL,
    subtype text,
    environment text,
    signed_payload text NOT NULL,
    verified_at timestamptz NOT NULL DEFAULT now(),
    processed_at timestamptz,
    processing_error text
);

CREATE INDEX IF NOT EXISTS idx_app_store_subscriptions_account
    ON app_store_subscriptions (organization_id, LOWER(username), status);

CREATE INDEX IF NOT EXISTS idx_app_store_subscriptions_expiry
    ON app_store_subscriptions (status, expires_at);
