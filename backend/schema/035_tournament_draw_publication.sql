ALTER TABLE tournament_events
    ADD COLUMN IF NOT EXISTS public_draw_key text,
    ADD COLUMN IF NOT EXISTS public_draw_enabled boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS draw_published_at timestamptz;

CREATE UNIQUE INDEX IF NOT EXISTS tournament_events_public_draw_key_unique
    ON tournament_events (public_draw_key)
    WHERE public_draw_key IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS tournament_entries_event_seed_unique
    ON tournament_entries (event_id, seed)
    WHERE seed IS NOT NULL AND entry_status <> 'withdrawn';

COMMENT ON COLUMN tournament_events.public_draw_key IS
    'Non-authenticated read-only draw access key, enabled only while the draw is published.';

COMMENT ON COLUMN tournament_events.public_draw_enabled IS
    'Controls whether the public draw key may be used without an authenticated session.';
