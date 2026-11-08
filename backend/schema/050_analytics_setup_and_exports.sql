CREATE TABLE IF NOT EXISTS match_setup_sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id bigint NOT NULL REFERENCES "SkwshOrgSettings"(id) ON DELETE CASCADE,
    actor_user_id bigint REFERENCES "SkwshOrgUsers"(id) ON DELETE SET NULL,
    client_type text NOT NULL,
    sport text NOT NULL,
    started_at timestamptz NOT NULL DEFAULT now(),
    finished_at timestamptz,
    outcome text,
    match_id uuid REFERENCES matches(id) ON DELETE SET NULL,
    CONSTRAINT match_setup_sessions_client_type_check
        CHECK (client_type IN ('web_app', 'mobile_app')),
    CONSTRAINT match_setup_sessions_outcome_check
        CHECK (outcome IS NULL OR outcome IN ('completed', 'abandoned'))
);

CREATE INDEX IF NOT EXISTS match_setup_sessions_org_started_idx
    ON match_setup_sessions (organization_id, started_at DESC);

CREATE INDEX IF NOT EXISTS match_setup_sessions_open_idx
    ON match_setup_sessions (started_at)
    WHERE outcome IS NULL;

COMMENT ON TABLE match_setup_sessions IS
    'Privacy-minimised match-setup journey telemetry used for Personal and Club completion/abandonment analytics.';
