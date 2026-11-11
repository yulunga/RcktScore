-- Provider-neutral subscription state for Personal and Club plans.
--
-- Apple remains the only live purchase verifier at this migration. Google Play
-- and Stripe adapters must write verified provider events here before they can
-- grant or extend an entitlement. SkwshOrgSettings.plan remains the existing
-- fast entitlement projection used by clients.

CREATE TABLE IF NOT EXISTS subscription_sources (
    id bigserial PRIMARY KEY,
    organization_id bigint NOT NULL
        REFERENCES "SkwshOrgSettings"(id) ON DELETE CASCADE,
    provider text NOT NULL
        CHECK (provider IN ('apple', 'google_play', 'stripe', 'manual')),
    provider_subscription_id text NOT NULL,
    plan text NOT NULL
        CHECK (plan IN ('personal_plus', 'club_essentials', 'club_pro')),
    product_id text,
    status text NOT NULL
        CHECK (status IN ('active', 'grace_period', 'billing_retry', 'cancelled', 'expired', 'revoked')),
    purchased_at timestamptz,
    last_renewed_at timestamptz,
    current_period_end timestamptz,
    auto_renew_enabled boolean,
    last_verified_at timestamptz NOT NULL DEFAULT now(),
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (provider, provider_subscription_id)
);

CREATE INDEX IF NOT EXISTS subscription_sources_account_idx
    ON subscription_sources (organization_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS subscription_sources_entitlement_idx
    ON subscription_sources (organization_id, status, current_period_end DESC);

ALTER TABLE subscription_sources ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE subscription_sources IS
    'Server-verified provider-neutral subscription state. Clients may display it but cannot write it.';

COMMENT ON COLUMN subscription_sources.provider IS
    'The provider that accepted and most recently verified this purchase or renewal.';

CREATE OR REPLACE FUNCTION sync_apple_subscription_source()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    renewed_at timestamptz;
BEGIN
    SELECT MAX(transaction_row.purchased_at)
    INTO renewed_at
    FROM app_store_transactions AS transaction_row
    WHERE transaction_row.original_transaction_id = NEW.original_transaction_id;

    INSERT INTO subscription_sources (
        organization_id, provider, provider_subscription_id, plan, product_id,
        status, purchased_at, last_renewed_at, current_period_end,
        auto_renew_enabled, last_verified_at, metadata, updated_at
    ) VALUES (
        NEW.organization_id, 'apple', NEW.original_transaction_id,
        'personal_plus', NEW.product_id, NEW.status, NEW.purchased_at,
        COALESCE(renewed_at, NEW.purchased_at), NEW.expires_at,
        NEW.auto_renew_enabled, NEW.last_verified_at,
        jsonb_build_object(
            'environment', NEW.environment,
            'latest_transaction_id', NEW.latest_transaction_id
        ),
        NEW.updated_at
    )
    ON CONFLICT (provider, provider_subscription_id) DO UPDATE SET
        organization_id = EXCLUDED.organization_id,
        plan = EXCLUDED.plan,
        product_id = EXCLUDED.product_id,
        status = EXCLUDED.status,
        purchased_at = EXCLUDED.purchased_at,
        last_renewed_at = EXCLUDED.last_renewed_at,
        current_period_end = EXCLUDED.current_period_end,
        auto_renew_enabled = EXCLUDED.auto_renew_enabled,
        last_verified_at = EXCLUDED.last_verified_at,
        metadata = EXCLUDED.metadata,
        updated_at = EXCLUDED.updated_at;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS app_store_subscription_source_sync
    ON app_store_subscriptions;

CREATE TRIGGER app_store_subscription_source_sync
AFTER INSERT OR UPDATE OF
    organization_id, original_transaction_id, latest_transaction_id,
    product_id, environment, status, purchased_at, expires_at,
    auto_renew_enabled, last_verified_at, updated_at
ON app_store_subscriptions
FOR EACH ROW
EXECUTE FUNCTION sync_apple_subscription_source();

INSERT INTO subscription_sources (
    organization_id, provider, provider_subscription_id, plan, product_id,
    status, purchased_at, last_renewed_at, current_period_end,
    auto_renew_enabled, last_verified_at, metadata, created_at, updated_at
)
SELECT
    subscription.organization_id,
    'apple',
    subscription.original_transaction_id,
    'personal_plus',
    subscription.product_id,
    subscription.status,
    subscription.purchased_at,
    COALESCE(MAX(transaction_row.purchased_at), subscription.purchased_at),
    subscription.expires_at,
    subscription.auto_renew_enabled,
    subscription.last_verified_at,
    jsonb_build_object(
        'environment', subscription.environment,
        'latest_transaction_id', subscription.latest_transaction_id
    ),
    subscription.created_at,
    subscription.updated_at
FROM app_store_subscriptions AS subscription
LEFT JOIN app_store_transactions AS transaction_row
    ON transaction_row.original_transaction_id = subscription.original_transaction_id
GROUP BY subscription.id
ON CONFLICT (provider, provider_subscription_id) DO UPDATE SET
    organization_id = EXCLUDED.organization_id,
    plan = EXCLUDED.plan,
    product_id = EXCLUDED.product_id,
    status = EXCLUDED.status,
    purchased_at = EXCLUDED.purchased_at,
    last_renewed_at = EXCLUDED.last_renewed_at,
    current_period_end = EXCLUDED.current_period_end,
    auto_renew_enabled = EXCLUDED.auto_renew_enabled,
    last_verified_at = EXCLUDED.last_verified_at,
    metadata = EXCLUDED.metadata,
    updated_at = EXCLUDED.updated_at;
