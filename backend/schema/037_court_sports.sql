ALTER TABLE "SkwshCourts"
    ADD COLUMN IF NOT EXISTS sport text;

ALTER TABLE "SkwshCourts"
    DROP CONSTRAINT IF EXISTS skwshcourts_sport_check;

ALTER TABLE "SkwshCourts"
    ADD CONSTRAINT skwshcourts_sport_check
    CHECK (
        sport IS NULL
        OR sport IN ('squash', 'racketball', 'tennis', 'padel', 'table_tennis', 'badminton', 'pickleball')
    );

CREATE INDEX IF NOT EXISTS idx_skwshcourts_organization_sport
    ON "SkwshCourts" (organization_name, sport, court_name);

COMMENT ON COLUMN "SkwshCourts".sport IS
    'Racket sport assigned to this court. NULL preserves legacy courts as usable for every sport.';
