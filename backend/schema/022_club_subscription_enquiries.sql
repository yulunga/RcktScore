-- Capture the full club details supplied by logged-in users enquiring about a
-- Club Essentials or Club Pro subscription.
ALTER TABLE "HitnScoreInterestRequests"
    ADD COLUMN IF NOT EXISTS requested_plan text,
    ADD COLUMN IF NOT EXISTS club_address text,
    ADD COLUMN IF NOT EXISTS club_postcode text,
    ADD COLUMN IF NOT EXISTS club_email text,
    ADD COLUMN IF NOT EXISTS club_website text,
    ADD COLUMN IF NOT EXISTS club_telephone text;

ALTER TABLE "HitnScoreInterestRequests"
    DROP CONSTRAINT IF EXISTS hitnscore_interest_requests_requested_plan_check;

ALTER TABLE "HitnScoreInterestRequests"
    ADD CONSTRAINT hitnscore_interest_requests_requested_plan_check
    CHECK (requested_plan IS NULL OR requested_plan IN ('club_essentials', 'club_pro'));

-- Personal registrations remain unique by email. Club enquiries are distinct
-- by requester, club and requested plan so they cannot overwrite the personal
-- registration record associated with the same email address.
DROP INDEX IF EXISTS hitnscore_interest_requests_email_key;

CREATE UNIQUE INDEX IF NOT EXISTS hitnscore_personal_interest_email_key
    ON "HitnScoreInterestRequests" (LOWER(email))
    WHERE use_type = 'personal';

CREATE UNIQUE INDEX IF NOT EXISTS hitnscore_club_interest_request_key
    ON "HitnScoreInterestRequests" (
        LOWER(email),
        LOWER(COALESCE(club_name, '')),
        COALESCE(requested_plan, '')
    )
    WHERE use_type = 'club';

CREATE INDEX IF NOT EXISTS hitnscore_interest_requested_plan_idx
    ON "HitnScoreInterestRequests" (requested_plan)
    WHERE use_type = 'club';
