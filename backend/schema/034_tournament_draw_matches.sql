CREATE TABLE IF NOT EXISTS tournament_matches (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    draw_id uuid NOT NULL REFERENCES tournament_draws(id) ON DELETE CASCADE,
    round_number integer NOT NULL,
    match_number integer NOT NULL,
    player1_entry_id uuid REFERENCES tournament_entries(id) ON DELETE RESTRICT,
    player2_entry_id uuid REFERENCES tournament_entries(id) ON DELETE RESTRICT,
    winner_entry_id uuid REFERENCES tournament_entries(id) ON DELETE RESTRICT,
    status text NOT NULL DEFAULT 'pending',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT tournament_matches_round_check CHECK (round_number > 0),
    CONSTRAINT tournament_matches_number_check CHECK (match_number > 0),
    CONSTRAINT tournament_matches_status_check CHECK (
        status IN ('pending', 'bye', 'scheduled', 'in_progress', 'completed', 'walkover')
    ),
    UNIQUE (draw_id, round_number, match_number)
);

CREATE INDEX IF NOT EXISTS tournament_matches_draw_round_idx
    ON tournament_matches (draw_id, round_number, match_number);

COMMENT ON TABLE tournament_matches IS
    'Persisted Tournament Manager draw fixtures. Scoring-match linkage and result progression are added in a later stage.';

COMMENT ON COLUMN tournament_matches.status IS
    'A bye names its automatic winner. Pending fixtures have two entrants and await scheduling/results.';
