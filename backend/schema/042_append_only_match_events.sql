CREATE SEQUENCE IF NOT EXISTS match_events_event_sequence_seq AS bigint;

ALTER TABLE match_events
    ADD COLUMN IF NOT EXISTS event_sequence bigint,
    ADD COLUMN IF NOT EXISTS actor_username text;

WITH existing_sequence AS (
    SELECT COALESCE(MAX(event_sequence), 0) AS maximum_sequence
    FROM match_events
),
ranked_events AS (
    SELECT
        id,
        (SELECT maximum_sequence FROM existing_sequence)
            + ROW_NUMBER() OVER (ORDER BY created_at ASC, id ASC) AS event_sequence
    FROM match_events
    WHERE event_sequence IS NULL
)
UPDATE match_events AS event
SET event_sequence = ranked.event_sequence
FROM ranked_events AS ranked
WHERE event.id = ranked.id;

SELECT setval(
    'match_events_event_sequence_seq',
    COALESCE((SELECT MAX(event_sequence) FROM match_events), 1),
    EXISTS(SELECT 1 FROM match_events)
);

ALTER SEQUENCE match_events_event_sequence_seq OWNED BY match_events.event_sequence;

ALTER TABLE match_events
    ALTER COLUMN event_sequence SET DEFAULT nextval('match_events_event_sequence_seq'),
    ALTER COLUMN event_sequence SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS match_events_event_sequence_unique
    ON match_events (event_sequence);

CREATE INDEX IF NOT EXISTS match_events_match_sequence_idx
    ON match_events (match_id, event_sequence ASC);

CREATE UNIQUE INDEX IF NOT EXISTS match_events_id_match_unique
    ON match_events (id, match_id);

CREATE TABLE IF NOT EXISTS match_event_compensations (
    undo_event_id uuid NOT NULL,
    target_event_id uuid NOT NULL,
    match_id uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    compensation_reason text NOT NULL DEFAULT 'undo',
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (undo_event_id, target_event_id),
    UNIQUE (target_event_id),
    CONSTRAINT match_event_compensations_undo_match_fk
        FOREIGN KEY (undo_event_id, match_id)
        REFERENCES match_events(id, match_id) ON DELETE CASCADE,
    CONSTRAINT match_event_compensations_target_match_fk
        FOREIGN KEY (target_event_id, match_id)
        REFERENCES match_events(id, match_id) ON DELETE CASCADE,
    CONSTRAINT match_event_compensations_distinct_events_check
        CHECK (undo_event_id <> target_event_id)
);

CREATE INDEX IF NOT EXISTS match_event_compensations_match_idx
    ON match_event_compensations (match_id, created_at ASC);

COMMENT ON COLUMN match_events.event_sequence IS
    'Database-authored canonical event order. Timestamps remain descriptive and are not used as the replay tie-breaker.';

COMMENT ON COLUMN match_events.actor_username IS
    'Authenticated account that caused an auditable mutation when available.';

COMMENT ON TABLE match_event_compensations IS
    'Immutable links from an undo event to scoring or derived timer events excluded from effective match replay.';
