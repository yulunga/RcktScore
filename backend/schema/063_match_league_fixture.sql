ALTER TABLE matches
    ADD COLUMN IF NOT EXISTS association_competition_type text,
    ADD COLUMN IF NOT EXISTS association_competition_name text,
    ADD COLUMN IF NOT EXISTS association_division_name text,
    ADD COLUMN IF NOT EXISTS association_fixture_date date,
    ADD COLUMN IF NOT EXISTS association_opposition text,
    ADD COLUMN IF NOT EXISTS association_venue text;

ALTER TABLE matches
    DROP CONSTRAINT IF EXISTS matches_association_fixture_check;

ALTER TABLE matches
    ADD CONSTRAINT matches_association_fixture_check
    CHECK (
        (
            association_competition_type IS NULL
            AND association_competition_name IS NULL
            AND association_division_name IS NULL
            AND association_fixture_date IS NULL
            AND association_opposition IS NULL
            AND association_venue IS NULL
        )
        OR
        (
            association_competition_type IN ('league', 'interclub')
            AND NULLIF(BTRIM(association_competition_name), '') IS NOT NULL
            AND NULLIF(BTRIM(association_division_name), '') IS NOT NULL
            AND association_fixture_date IS NOT NULL
            AND NULLIF(BTRIM(association_opposition), '') IS NOT NULL
            AND association_venue IN ('home', 'away')
        )
    );

CREATE INDEX IF NOT EXISTS idx_matches_tenant_association_fixture
    ON matches (tenant_id, association_fixture_date DESC)
    WHERE association_fixture_date IS NOT NULL;

COMMENT ON COLUMN matches.association_competition_name IS
'Optional club league or inter-club competition selected from the tenant association fixture catalog at match setup.';
