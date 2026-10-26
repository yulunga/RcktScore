-- Read-only migration-ledger status for Supabase SQL Editor.

WITH summary AS (
    SELECT
        COUNT(*) AS ledger_rows,
        MIN(version) AS first_version,
        MAX(version) AS latest_version,
        COUNT(DISTINCT checksum_sha256) AS distinct_checksums
    FROM public.schema_migrations
)
SELECT
    migration.version,
    migration.filename,
    migration.checksum_sha256,
    migration.applied_at,
    migration.applied_by,
    migration.git_commit,
    migration.notes,
    summary.ledger_rows,
    summary.first_version,
    summary.latest_version,
    summary.distinct_checksums
FROM public.schema_migrations migration
CROSS JOIN summary
ORDER BY migration.version;
