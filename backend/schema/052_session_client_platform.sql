ALTER TABLE org_user_sessions
    ADD COLUMN IF NOT EXISTS client_platform text
        CHECK (client_platform IN ('ios', 'android'));
