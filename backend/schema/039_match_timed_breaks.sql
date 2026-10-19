ALTER TABLE matches
    ADD COLUMN IF NOT EXISTS tennis_timed_breaks boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN matches.tennis_timed_breaks IS
    'When true, the match uses timed changeovers and between-set breaks.';
