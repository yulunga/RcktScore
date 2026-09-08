ALTER TABLE matches
    ADD COLUMN IF NOT EXISTS tennis_no_ad_scoring boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS tennis_final_set_match_tiebreak boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN matches.tennis_no_ad_scoring IS
    'When true, a deciding point is played at deuce after the receiver chooses the service court.';

COMMENT ON COLUMN matches.tennis_final_set_match_tiebreak IS
    'When true, a deciding final set is replaced by a 10-point match tiebreak won by two clear points.';
