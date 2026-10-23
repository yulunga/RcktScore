ALTER TABLE "SkwshOrgSettings"
ADD COLUMN IF NOT EXISTS association_competitions JSONB NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN "SkwshOrgSettings".association_competitions IS
'Club leagues and interclub competitions, stored as normalized name/type objects.';
