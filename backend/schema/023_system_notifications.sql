CREATE TABLE IF NOT EXISTS system_notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title text NOT NULL,
    message text NOT NULL,
    audience text NOT NULL DEFAULT 'all',
    created_by text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT system_notifications_audience_check CHECK (
        audience IN ('all', 'personal_free', 'personal_plus', 'club_essentials', 'club_pro')
    )
);

CREATE TABLE IF NOT EXISTS system_notification_reads (
    notification_id uuid NOT NULL REFERENCES system_notifications(id) ON DELETE CASCADE,
    username text NOT NULL,
    read_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (notification_id, username)
);

CREATE INDEX IF NOT EXISTS idx_system_notifications_created
    ON system_notifications (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_system_notification_reads_username
    ON system_notification_reads (LOWER(username), read_at DESC);

INSERT INTO system_notifications (title, message, audience, created_by)
SELECT
    'Welcome to Hit n Score',
    'Welcome to Hit n Score. Your notifications about account updates, new features and service information will appear here.',
    'all',
    'system'
WHERE NOT EXISTS (
    SELECT 1 FROM system_notifications WHERE title = 'Welcome to Hit n Score' AND created_by = 'system'
);
