ALTER TABLE matches
    ADD COLUMN IF NOT EXISTS viewer_code text;

CREATE UNIQUE INDEX IF NOT EXISTS idx_matches_viewer_code_unique
    ON matches (UPPER(viewer_code))
    WHERE viewer_code IS NOT NULL;

CREATE TABLE IF NOT EXISTS match_view_profiles (
    match_id uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    viewer_organization_id bigint NOT NULL REFERENCES "SkwshOrgSettings"(id) ON DELETE CASCADE,
    added_by_username text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (match_id, viewer_organization_id)
);

CREATE INDEX IF NOT EXISTS idx_match_view_profiles_viewer_created
    ON match_view_profiles (viewer_organization_id, created_at DESC);

COMMENT ON COLUMN matches.viewer_code IS
    'Match-specific read-only code for authenticated Personal Plus remote viewing.';

COMMENT ON TABLE match_view_profiles IS
    'Matches explicitly saved to a Personal Plus account for later read-only viewing.';
