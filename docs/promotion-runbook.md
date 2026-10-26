# RcktScore Promotion Runbook

This runbook covers database migration, backend, frontend, and native-client
compatibility checks for staging and production promotion. It deliberately uses
a forward-only database model: application artifacts may be rolled back, while
an applied schema is repaired with a new migration instead of editing or
reversing recorded migration history.

The current pre-release service has one Supabase environment with daily backups.
Baseline that environment as the current pre-release database. The separate
staging and production sections below describe the required release posture;
they cannot be considered exercised until a distinct production target exists.

## Migration Files and Ledger

Migration files live in `backend/schema/` and use the unique format
`NNN_lowercase_description.sql`. The next migration number must be greater than
the current highest number. Once a migration is accepted by an environment it
must not be renamed or edited.

`schema_migrations` is created by `043_schema_migration_ledger.sql`. Each row
records the unique version and filename, the SHA-256 of the exact promoted file,
the application time, and optional operator, Git commit, duration, and notes.
Only successful migrations belong in the ledger. The table is append-only,
row-level security is enabled, and general `PUBLIC` table access is revoked;
run promotions through the database owner or a deliberately granted deployment
role rather than an application or client role.

The repository checksum manifest is `backend/schema/checksums.sha256`. Validate
it before promotion:

```bash
python3 scripts/check_migrations.py verify
```

When intentionally adding a new migration, append it to and review the manifest:

```bash
python3 scripts/check_migrations.py write-manifest
git diff -- backend/schema/checksums.sha256
python3 scripts/check_migrations.py verify
```

The write command refuses to remove or replace an existing checksum-pinned
migration; corrections require a new migration file. The manifest is a
repository integrity check. The database ledger remains the authoritative
record for a particular deployed database.

## One-Time Legacy Baseline

The first ledger rollout is not an ordinary migration run. Existing staging and
production databases received migrations before a ledger existed, so do not
insert versions `001`–`042` merely because the files exist in Git.

For the current pre-release environment, and later for each separate staging or
production environment:

1. Record the environment, current application Git commit, operator, and date.
2. Confirm a current Supabase backup or point-in-time recovery position.
3. Export the current schema or inspect the PostgreSQL catalog.
4. Run the complete read-only `scripts/migration-baseline-audit.sql` statement
   and export its result. It reports one PASS/FAIL row for each migration from
   `001` through `042`, covering material tables, columns, indexes, constraints,
   triggers, backfills, and required seed rows.
5. Resolve every missing or partially applied migration before baselining it.
6. Apply `043_schema_migration_ledger.sql`.
7. Insert ledger rows for verified legacy versions `001`–`042`, then record
   `043` itself, using the checksums from `backend/schema/checksums.sha256`.
   Use a shared baseline timestamp, the release Git commit, the operator
   identity, and a note such as `verified legacy baseline`; identify `043` as
   the ledger bootstrap rather than a legacy migration.
8. Apply `044_reconcile_user_profile_fields.sql`, or verify its columns and
   index if it was already applied during ledger bootstrap validation. This is
   the idempotent, uniquely numbered replacement for the former duplicate
   `010_user_profile_fields.sql`; record version `044` only after that check
   succeeds.
9. Compare the database ledger with the checked-in manifest and retain the
   comparison as release evidence.

Keep `010_match_shirt_colors.sql` as version `010`. Do not shift migrations
`011`–`042`. Historical databases may already contain the profile fields from
the old duplicate `010`; migration `044` safely confirms them with
`IF NOT EXISTS` operations.

## Release Record

Before promoting, record:

- release Git commit or tag
- current and target backend artifacts
- current and target frontend artifacts
- compatible iOS build range
- pending migration filenames and checksums
- operator and reviewer
- backup or recovery reference
- planned smoke-test owner

Do not include database URLs, passwords, Apple private keys, or other secrets in
the release record.

## Staging Promotion

1. Confirm staging health and backup/recovery availability.
2. Run `python3 scripts/check_migrations.py verify` from the target commit.
3. Query `schema_migrations` and compare every recorded checksum with the
   checked-in manifest. Stop on a missing historical row or checksum mismatch.
4. Review pending SQL for locks, data rewrites, destructive operations, and
   compatibility with the currently deployed backend and iOS builds.
5. Acquire a PostgreSQL advisory lock for the migration session.
6. Apply each pending migration in ascending order, one transaction per file.
   Insert its ledger row in the same transaction. Stop on the first failure.
7. Run migration-specific catalog and data assertions.
8. Deploy the backend and verify `/health` plus CloudWatch logs and alarms.
9. Deploy the frontend and clear or invalidate its hosting cache where needed.
10. Run the staging smoke checks below and retain the result.

## Production Promotion

Production promotion requires a successful staging run against the same Git
commit and migration checksums.

1. Confirm the production backup/recovery position and normal service health.
2. Re-run migration verification and compare the production ledger.
3. Apply additive database migrations before code that requires them.
4. Verify the new database objects and ledger rows.
5. Deploy the backend, then verify `/health`, API errors, latency, and alarms.
6. Deploy the frontend and run browser smoke checks.
7. Promote the compatible iOS build only after the backend contract is ready.
8. Monitor error rate, latency, database connections, and critical product
   flows through the agreed observation window.

Breaking schema changes require an expand-and-contract sequence across separate
releases: add the compatible shape, migrate callers and data, observe it, and
remove the obsolete shape only in a later migration.

## Minimum Smoke Checks

- web and iOS login, session validation, and account-context switching
- personal and club dashboard reads
- personal and club match creation
- scheduled-match creation and activation
- Squash/Racketball scoring, completion, history, and Undo
- Tennis scoring through a game boundary
- club-admin organisation, user, court, and racket-sport settings
- root-admin login and a read-only directory operation
- tournament reads and writes when tournament migrations or code changed
- Apple purchase context/verification when subscription code changed

Use disposable test matches and accounts for destructive checks.

## Failure and Rollback

If a migration fails, roll back its transaction, do not add its ledger row, and
stop the promotion. Diagnose and create a corrected forward migration; never
change a checksum already recorded by staging or production.

For an application regression, restore the previous backend/frontend artifact
while leaving compatible additive schema in place. Avoid automatic down
migrations or dropping columns during an incident. Restore a database backup
only for material corruption or destructive data loss and account for valid data
written after the recovery point.

## Promotion Evidence

Retain the following with the release record:

- ledger output before and after promotion
- checked-in migration manifest and target Git commit
- migration execution output and duration
- migration-specific verification queries
- backend deployment identifier and `/health` result
- frontend deployment identifier
- smoke-test result
- CloudWatch and Supabase observations
- operator and reviewer sign-off
