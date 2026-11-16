-- Read-only audit for duplicate court numbers and customer-facing court names.
-- No returned rows means the existing sport-assigned club courts are clean.
-- Racketball is canonicalized to Squash, and Court 1 / court-1 / Court-01
-- are treated as the same numbered court.

WITH normalized_courts AS (
    SELECT
        court.id AS court_id,
        court.organization_name AS club_id,
        COALESCE(org.organization_name, 'Club ' || court.organization_name::text) AS club_name,
        CASE WHEN court.sport = 'racketball' THEN 'squash' ELSE court.sport END AS canonical_sport,
        court.court_name,
        court.court_alias,
        REGEXP_REPLACE(
            LOWER(BTRIM(court.court_name)),
            '^court[- ]*0*([1-9][0-9]*)$',
            'court-\1'
        ) AS normalized_number,
        NULLIF(LOWER(BTRIM(court.court_alias)), '') AS normalized_display_name
    FROM "SkwshCourts" AS court
    LEFT JOIN "SkwshOrgSettings" AS org
      ON org.id = court.organization_name
    WHERE court.sport IS NOT NULL
      AND COALESCE(org.org_type, 'club') = 'club'
), duplicate_numbers AS (
    SELECT
        'duplicate_number'::text AS issue_type,
        club_id,
        club_name,
        canonical_sport,
        normalized_number AS duplicate_value,
        COUNT(*) AS duplicate_count,
        ARRAY_AGG(court_id ORDER BY court_id) AS court_ids,
        ARRAY_AGG(court_name ORDER BY court_id) AS stored_numbers,
        ARRAY_AGG(court_alias ORDER BY court_id) AS stored_names
    FROM normalized_courts
    GROUP BY club_id, club_name, canonical_sport, normalized_number
    HAVING COUNT(*) > 1
), duplicate_names AS (
    SELECT
        'duplicate_name'::text AS issue_type,
        club_id,
        club_name,
        canonical_sport,
        normalized_display_name AS duplicate_value,
        COUNT(*) AS duplicate_count,
        ARRAY_AGG(court_id ORDER BY court_id) AS court_ids,
        ARRAY_AGG(court_name ORDER BY court_id) AS stored_numbers,
        ARRAY_AGG(court_alias ORDER BY court_id) AS stored_names
    FROM normalized_courts
    WHERE normalized_display_name IS NOT NULL
    GROUP BY club_id, club_name, canonical_sport, normalized_display_name
    HAVING COUNT(*) > 1
)
SELECT * FROM duplicate_numbers
UNION ALL
SELECT * FROM duplicate_names
ORDER BY club_name, canonical_sport, issue_type, duplicate_value;
