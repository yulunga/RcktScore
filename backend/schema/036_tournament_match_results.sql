ALTER TABLE tournament_matches
    ADD COLUMN IF NOT EXISTS bracket text NOT NULL DEFAULT 'championship',
    ADD COLUMN IF NOT EXISTS scoring_match_id uuid REFERENCES matches(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS score_data jsonb NOT NULL DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS score_summary text,
    ADD COLUMN IF NOT EXISTS result_entered_by text,
    ADD COLUMN IF NOT EXISTS result_entered_at timestamptz;

ALTER TABLE tournament_matches
    DROP CONSTRAINT IF EXISTS tournament_matches_bracket_check,
    ADD CONSTRAINT tournament_matches_bracket_check
    CHECK (bracket IN ('championship', 'plate'));

ALTER TABLE tournament_matches
    DROP CONSTRAINT IF EXISTS tournament_matches_draw_id_round_number_match_number_key;

CREATE UNIQUE INDEX IF NOT EXISTS tournament_matches_draw_bracket_round_number_unique
    ON tournament_matches (draw_id, bracket, round_number, match_number);

CREATE UNIQUE INDEX IF NOT EXISTS tournament_matches_scoring_match_unique
    ON tournament_matches (scoring_match_id)
    WHERE scoring_match_id IS NOT NULL;

ALTER TABLE matches
    ADD COLUMN IF NOT EXISTS tournament_event_id uuid REFERENCES tournament_events(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS tournament_match_id uuid REFERENCES tournament_matches(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS tournament_name text;

CREATE INDEX IF NOT EXISTS matches_tournament_event_idx
    ON matches (tournament_event_id, status, updated_at DESC)
    WHERE tournament_event_id IS NOT NULL;

COMMENT ON COLUMN tournament_matches.bracket IS
    'Championship is the main knockout draw; plate contains first-round championship losers.';

COMMENT ON COLUMN tournament_matches.score_data IS
    'Structured manually entered result, including game scores or a games-won summary.';

COMMENT ON COLUMN matches.tournament_name IS
    'Display snapshot used to identify tournament fixtures in normal scheduled/current/history match lists.';
