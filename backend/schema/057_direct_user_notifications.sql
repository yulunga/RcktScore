ALTER TABLE system_notifications
    ADD COLUMN IF NOT EXISTS recipient_username text;

CREATE INDEX IF NOT EXISTS idx_system_notifications_recipient_username
    ON system_notifications (LOWER(recipient_username), created_at DESC)
    WHERE recipient_username IS NOT NULL;

COMMENT ON COLUMN system_notifications.recipient_username IS
    'Optional normalized email identity for a private notification. NULL retains plan-audience delivery.';
