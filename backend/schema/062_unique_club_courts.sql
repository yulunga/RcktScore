DO $$
DECLARE
    duplicate_record record;
BEGIN
    SELECT duplicate_kind, organization_name, canonical_sport, duplicate_value, duplicate_count
    INTO duplicate_record
    FROM (
        SELECT
            'number'::text AS duplicate_kind,
            organization_name,
            CASE WHEN sport = 'racketball' THEN 'squash' ELSE sport END AS canonical_sport,
            REGEXP_REPLACE(
                LOWER(BTRIM(court_name)),
                '^court[- ]*0*([1-9][0-9]*)$',
                'court-\1'
            ) AS duplicate_value,
            COUNT(*) AS duplicate_count
        FROM "SkwshCourts"
        WHERE sport IS NOT NULL
        GROUP BY
            organization_name,
            CASE WHEN sport = 'racketball' THEN 'squash' ELSE sport END,
            REGEXP_REPLACE(
                LOWER(BTRIM(court_name)),
                '^court[- ]*0*([1-9][0-9]*)$',
                'court-\1'
            )
        HAVING COUNT(*) > 1

        UNION ALL

        SELECT
            'name'::text AS duplicate_kind,
            organization_name,
            CASE WHEN sport = 'racketball' THEN 'squash' ELSE sport END AS canonical_sport,
            LOWER(BTRIM(court_alias)) AS duplicate_value,
            COUNT(*) AS duplicate_count
        FROM "SkwshCourts"
        WHERE sport IS NOT NULL
          AND court_alias IS NOT NULL
          AND BTRIM(court_alias) <> ''
        GROUP BY organization_name, CASE WHEN sport = 'racketball' THEN 'squash' ELSE sport END, LOWER(BTRIM(court_alias))
        HAVING COUNT(*) > 1
    ) duplicates
    ORDER BY organization_name, canonical_sport, duplicate_kind, duplicate_value
    LIMIT 1;

    IF FOUND THEN
        RAISE EXCEPTION
            'Cannot enforce court uniqueness: club %, sport %, duplicate % "%" (% rows)',
            duplicate_record.organization_name,
            duplicate_record.canonical_sport,
            duplicate_record.duplicate_kind,
            duplicate_record.duplicate_value,
            duplicate_record.duplicate_count;
    END IF;
END
$$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_skwshcourts_org_sport_number
    ON "SkwshCourts" (
        organization_name,
        (CASE WHEN sport = 'racketball' THEN 'squash' ELSE sport END),
        (REGEXP_REPLACE(
            LOWER(BTRIM(court_name)),
            '^court[- ]*0*([1-9][0-9]*)$',
            'court-\1'
        ))
    )
    WHERE sport IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_skwshcourts_org_sport_alias
    ON "SkwshCourts" (
        organization_name,
        (CASE WHEN sport = 'racketball' THEN 'squash' ELSE sport END),
        (LOWER(BTRIM(court_alias)))
    )
    WHERE sport IS NOT NULL
      AND court_alias IS NOT NULL
      AND BTRIM(court_alias) <> '';

COMMENT ON INDEX uq_skwshcourts_org_sport_number IS
    'Prevents duplicate normalized court numbers within one club and canonical sport; Racketball shares Squash courts.';

COMMENT ON INDEX uq_skwshcourts_org_sport_alias IS
    'Prevents duplicate customer-facing court names within one club and canonical sport; Racketball shares Squash courts.';
