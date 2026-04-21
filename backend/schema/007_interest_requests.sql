CREATE TABLE IF NOT EXISTS "HitnScoreInterestRequests" (
    id bigserial PRIMARY KEY,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    first_name text NOT NULL,
    surname text NOT NULL,
    email text NOT NULL,
    use_type text NOT NULL DEFAULT 'personal',
    club_name text,
    personal_plan text NOT NULL DEFAULT 'personal_free',
    approval_status text NOT NULL DEFAULT 'pending',
    email_validated boolean NOT NULL DEFAULT false,
    email_validated_at timestamptz,
    approved_at timestamptz,
    approved_by text,
    page_url text,
    user_agent text
);

CREATE UNIQUE INDEX IF NOT EXISTS hitnscore_interest_requests_email_key
    ON "HitnScoreInterestRequests" (LOWER(email));

CREATE INDEX IF NOT EXISTS hitnscore_interest_requests_approval_status_idx
    ON "HitnScoreInterestRequests" (approval_status);

ALTER TABLE "HitnScoreInterestRequests"
    DROP CONSTRAINT IF EXISTS hitnscore_interest_requests_personal_plan_check;

ALTER TABLE "HitnScoreInterestRequests"
    ADD CONSTRAINT hitnscore_interest_requests_personal_plan_check
    CHECK (personal_plan IN ('personal_free', 'personal_plus'));
