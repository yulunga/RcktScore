CREATE TABLE IF NOT EXISTS matches (
    id uuid PRIMARY KEY,
    tenant_id bigint NOT NULL REFERENCES "SkwshOrgSettings"(id),
    court_id bigint NOT NULL REFERENCES "SkwshCourts"(id),
    court_name text NOT NULL,
    court_alias text,
    sport text NOT NULL DEFAULT 'squash',
    player1_name text NOT NULL,
    player1_surname text,
    player1_country text,
    player1_handedness text NOT NULL DEFAULT 'right',
    player1_shirt_color text NOT NULL DEFAULT 'navy',
    player2_name text NOT NULL,
    player2_surname text,
    player2_country text,
    player2_handedness text NOT NULL DEFAULT 'right',
    player2_shirt_color text NOT NULL DEFAULT 'white',
    referee_name text,
    score_type integer NOT NULL,
    best_of integer NOT NULL DEFAULT 1,
    games_to_win integer NOT NULL DEFAULT 1,
    current_game_number integer NOT NULL DEFAULT 1,
    player1_games_won integer NOT NULL DEFAULT 0,
    player2_games_won integer NOT NULL DEFAULT 0,
    handicap_enabled boolean NOT NULL DEFAULT false,
    player1_band text,
    player2_band text,
    player1_offset integer NOT NULL DEFAULT 0,
    player2_offset integer NOT NULL DEFAULT 0,
    player1_final_score integer,
    player2_final_score integer,
    winner_side text,
    winner_name text,
    ended_early boolean NOT NULL DEFAULT false,
    end_reason text,
    status text NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz,
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE matches
    ADD COLUMN IF NOT EXISTS court_alias text,
    ADD COLUMN IF NOT EXISTS sport text NOT NULL DEFAULT 'squash',
    ADD COLUMN IF NOT EXISTS player1_surname text,
    ADD COLUMN IF NOT EXISTS player1_country text,
    ADD COLUMN IF NOT EXISTS player1_handedness text NOT NULL DEFAULT 'right',
    ADD COLUMN IF NOT EXISTS player1_shirt_color text NOT NULL DEFAULT 'navy',
    ADD COLUMN IF NOT EXISTS player2_surname text,
    ADD COLUMN IF NOT EXISTS player2_country text,
    ADD COLUMN IF NOT EXISTS player2_handedness text NOT NULL DEFAULT 'right',
    ADD COLUMN IF NOT EXISTS player2_shirt_color text NOT NULL DEFAULT 'white',
    ADD COLUMN IF NOT EXISTS referee_name text,
    ADD COLUMN IF NOT EXISTS best_of integer NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS games_to_win integer NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS current_game_number integer NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS player1_games_won integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS player2_games_won integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS handicap_enabled boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS player1_band text,
    ADD COLUMN IF NOT EXISTS player2_band text,
    ADD COLUMN IF NOT EXISTS player1_offset integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS player2_offset integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS player1_final_score integer,
    ADD COLUMN IF NOT EXISTS player2_final_score integer,
    ADD COLUMN IF NOT EXISTS winner_side text,
    ADD COLUMN IF NOT EXISTS winner_name text,
    ADD COLUMN IF NOT EXISTS ended_early boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS end_reason text,
    ADD COLUMN IF NOT EXISTS completed_at timestamptz;

ALTER TABLE matches
    DROP CONSTRAINT IF EXISTS matches_player1_shirt_color_check,
    DROP CONSTRAINT IF EXISTS matches_player2_shirt_color_check;

ALTER TABLE matches
    ADD CONSTRAINT matches_player1_shirt_color_check
    CHECK (player1_shirt_color IN ('navy', 'blue', 'red', 'green', 'black', 'white', 'yellow', 'orange', 'purple', 'pink')),
    ADD CONSTRAINT matches_player2_shirt_color_check
    CHECK (player2_shirt_color IN ('navy', 'blue', 'red', 'green', 'black', 'white', 'yellow', 'orange', 'purple', 'pink'));

CREATE TABLE IF NOT EXISTS match_events (
    id uuid PRIMARY KEY,
    match_id uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    tenant_id bigint NOT NULL REFERENCES "SkwshOrgSettings"(id),
    event_type text NOT NULL,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    event_source text NOT NULL DEFAULT 'api',
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_matches_tenant_status_updated
    ON matches (tenant_id, status, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_match_events_match_created
    ON match_events (match_id, created_at ASC);
