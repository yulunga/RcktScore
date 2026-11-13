ALTER TABLE matches
    ADD COLUMN IF NOT EXISTS scoring_owner_membership_id bigint
        REFERENCES "SkwshOrgUsers"(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS scoring_locked_at timestamptz;

CREATE INDEX IF NOT EXISTS matches_scoring_owner_membership_idx
    ON matches (scoring_owner_membership_id)
    WHERE scoring_owner_membership_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS match_scorer_lock_audit (
    id bigserial PRIMARY KEY,
    match_id uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    tenant_id bigint NOT NULL REFERENCES "SkwshOrgSettings"(id) ON DELETE CASCADE,
    previous_membership_id bigint REFERENCES "SkwshOrgUsers"(id) ON DELETE SET NULL,
    new_membership_id bigint REFERENCES "SkwshOrgUsers"(id) ON DELETE SET NULL,
    action text NOT NULL CHECK (action IN ('started', 'claimed', 'admin_takeover')),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS match_scorer_lock_audit_match_idx
    ON match_scorer_lock_audit (match_id, created_at ASC, id ASC);

ALTER TABLE match_scorer_lock_audit ENABLE ROW LEVEL SECURITY;

COMMENT ON COLUMN matches.scoring_owner_membership_id IS
    'Club membership currently authorised to operate this match; club admins may transfer ownership through the audited takeover endpoint.';
COMMENT ON TABLE match_scorer_lock_audit IS
    'Append-only audit of initial scorer assignment, legacy claim and administrator takeover for club matches.';
