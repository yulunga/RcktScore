ALTER TABLE system_notifications
    ADD COLUMN IF NOT EXISTS recipient_count bigint CHECK (recipient_count >= 0);

COMMENT ON COLUMN system_notifications.recipient_count IS
    'Distinct eligible identities at publication. NULL for notifications published before recipient counts were recorded.';
