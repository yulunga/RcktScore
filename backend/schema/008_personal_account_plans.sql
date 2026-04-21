ALTER TABLE "HitnScoreInterestRequests"
    ADD COLUMN IF NOT EXISTS personal_plan text NOT NULL DEFAULT 'personal_free';

UPDATE "HitnScoreInterestRequests"
SET personal_plan = 'personal_free'
WHERE personal_plan IS NULL;

ALTER TABLE "HitnScoreInterestRequests"
    DROP CONSTRAINT IF EXISTS hitnscore_interest_requests_personal_plan_check;

ALTER TABLE "HitnScoreInterestRequests"
    ADD CONSTRAINT hitnscore_interest_requests_personal_plan_check
    CHECK (personal_plan IN ('personal_free', 'personal_plus'));

CREATE INDEX IF NOT EXISTS hitnscore_interest_requests_personal_accounts_idx
    ON "HitnScoreInterestRequests" (approval_status, use_type, personal_plan);
