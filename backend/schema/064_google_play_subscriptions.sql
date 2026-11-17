-- Google Play Personal Plus subscriptions.
--
-- Verified Google Play state is written directly to subscription_sources
-- (provider = 'google_play', provider_subscription_id = Play purchase token).
-- This table makes Real-time Developer Notification delivery idempotent and
-- auditable. It never stores the raw purchase token.

CREATE TABLE IF NOT EXISTS google_play_notifications (
    message_id text PRIMARY KEY,
    notification_type integer,
    voided boolean NOT NULL DEFAULT false,
    purchase_token_sha256 text,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    outcome text,
    received_at timestamptz NOT NULL DEFAULT now(),
    processed_at timestamptz
);

CREATE INDEX IF NOT EXISTS google_play_notifications_token_idx
    ON google_play_notifications (purchase_token_sha256, received_at DESC);

ALTER TABLE google_play_notifications ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS subscription_sources_google_reconcile_idx
    ON subscription_sources (last_verified_at)
    WHERE provider = 'google_play';

COMMENT ON TABLE google_play_notifications IS
    'Idempotency and audit log for Google Play RTDN Pub/Sub pushes. Entitlement is always re-read from the Play Developer API.';
