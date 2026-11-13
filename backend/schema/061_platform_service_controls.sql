ALTER TABLE platform_settings
    ADD COLUMN IF NOT EXISTS subscriptions_enabled boolean NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS subscription_exception_emails jsonb NOT NULL DEFAULT '[]'::jsonb;

UPDATE platform_settings
SET subscriptions_enabled = COALESCE(subscriptions_enabled, true),
    subscription_exception_emails = COALESCE(subscription_exception_emails, '[]'::jsonb)
WHERE id = 'default';

COMMENT ON COLUMN platform_settings.subscriptions_enabled IS
    'Platform-wide visibility and navigation gate for subscription screens on web, iOS and Android.';

COMMENT ON COLUMN platform_settings.subscription_exception_emails IS
    'Normalized identity email addresses allowed to open subscription screens while the platform-wide gate is disabled.';
