-- Personal accounts are created immediately and are no longer part of the
-- root-admin approval queue. Keep their registration record for audit/support.
UPDATE "HitnScoreInterestRequests"
SET approval_status = 'registered',
    approved_at = NULL,
    approved_by = NULL
WHERE use_type = 'personal'
  AND approval_status IS DISTINCT FROM 'registered';

CREATE INDEX IF NOT EXISTS hitnscore_club_interest_approval_idx
    ON "HitnScoreInterestRequests" (approval_status, created_at DESC)
    WHERE use_type = 'club';
