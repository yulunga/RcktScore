BEGIN;

CREATE TABLE IF NOT EXISTS public.system_notification_dismissals (
    notification_id uuid NOT NULL REFERENCES public.system_notifications(id) ON DELETE CASCADE,
    username text NOT NULL,
    dismissed_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (notification_id, username),
    CONSTRAINT system_notification_dismissals_username_check
        CHECK (BTRIM(username) <> '')
);

CREATE INDEX IF NOT EXISTS system_notification_dismissals_username_lookup_idx
    ON public.system_notification_dismissals (LOWER(username));

ALTER TABLE public.system_notification_dismissals ENABLE ROW LEVEL SECURITY;

COMMIT;
