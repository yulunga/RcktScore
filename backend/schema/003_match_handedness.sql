ALTER TABLE matches
    ADD COLUMN IF NOT EXISTS player1_handedness text NOT NULL DEFAULT 'right',
    ADD COLUMN IF NOT EXISTS player2_handedness text NOT NULL DEFAULT 'right';
