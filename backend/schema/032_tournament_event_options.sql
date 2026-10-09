ALTER TABLE tournament_events
    ADD COLUMN IF NOT EXISTS audience text NOT NULL DEFAULT 'internal',
    ADD COLUMN IF NOT EXISTS graded_enabled boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS draw_size_limit integer;

ALTER TABLE tournament_events
    DROP CONSTRAINT IF EXISTS tournament_events_audience_check,
    ADD CONSTRAINT tournament_events_audience_check CHECK (
        audience IN ('internal', 'open')
    ),
    DROP CONSTRAINT IF EXISTS tournament_events_draw_size_limit_check,
    ADD CONSTRAINT tournament_events_draw_size_limit_check CHECK (
        draw_size_limit IS NULL OR draw_size_limit >= 2
    );

ALTER TABLE tournament_entries
    ADD COLUMN IF NOT EXISTS ability_level integer;

ALTER TABLE tournament_entries
    DROP CONSTRAINT IF EXISTS tournament_entries_ability_level_check,
    ADD CONSTRAINT tournament_entries_ability_level_check CHECK (
        ability_level IS NULL OR ability_level BETWEEN 1 AND 4
    );

CREATE TABLE IF NOT EXISTS tournament_draws (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id uuid NOT NULL REFERENCES tournament_events(id) ON DELETE CASCADE,
    name text NOT NULL,
    grade text,
    status text NOT NULL DEFAULT 'draft',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT tournament_draws_grade_check CHECK (
        grade IS NULL OR grade IN ('A', 'B', 'C', 'D')
    ),
    CONSTRAINT tournament_draws_status_check CHECK (
        status IN ('draft', 'published', 'in_progress', 'completed')
    ),
    UNIQUE (tournament_id, name)
);

INSERT INTO tournament_draws (tournament_id, name, grade)
SELECT id, 'Open Draw', NULL
FROM tournament_events
ON CONFLICT (tournament_id, name) DO NOTHING;

COMMENT ON COLUMN tournament_events.audience IS
    'Internal tournaments accept host-club members only; open tournaments may also accept guest players.';

COMMENT ON COLUMN tournament_events.graded_enabled IS
    'When true, ability levels route entries into A, B, C and D draw groups.';

COMMENT ON COLUMN tournament_events.draw_size_limit IS
    'Optional maximum number of active entries. NULL means no entry limit.';

COMMENT ON COLUMN tournament_entries.ability_level IS
    'Organiser assessment from 1 (A grade / advanced) to 4 (D grade / new player).';

COMMENT ON TABLE tournament_draws IS
    'Top-level draw groups. Graded events receive A, B, C and D groups; ungraded events receive one Open Draw.';
