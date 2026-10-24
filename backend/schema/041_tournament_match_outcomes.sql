ALTER TABLE tournament_matches
    ADD COLUMN IF NOT EXISTS result_outcome text,
    ADD COLUMN IF NOT EXISTS result_note text;

ALTER TABLE tournament_matches
    DROP CONSTRAINT IF EXISTS tournament_matches_status_check,
    ADD CONSTRAINT tournament_matches_status_check CHECK (
        status IN (
            'pending',
            'bye',
            'scheduled',
            'in_progress',
            'awaiting_resolution',
            'completed',
            'walkover',
            'abandoned'
        )
    );

ALTER TABLE tournament_matches
    DROP CONSTRAINT IF EXISTS tournament_matches_result_outcome_check,
    ADD CONSTRAINT tournament_matches_result_outcome_check CHECK (
        result_outcome IS NULL
        OR result_outcome IN ('played', 'retired', 'conceded', 'walkover', 'abandoned')
    );

COMMENT ON COLUMN tournament_matches.result_outcome IS
    'Server-authored result classification. Early-ended scoring matches require an explicit administrator resolution.';

COMMENT ON COLUMN tournament_matches.result_note IS
    'Optional administrator or system context for a non-standard tournament result.';
