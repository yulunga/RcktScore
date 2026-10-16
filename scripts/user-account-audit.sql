-- Read-only user and membership audit for Supabase/Postgres.
--
-- Run this in the Supabase SQL Editor or with:
--   psql "$DATABASE_URL" -f scripts/user-account-audit.sql
--
-- One person can belong to more than one club, so this intentionally returns
-- one row per organisation membership. Passwords are stored as one-way hashes;
-- only whether a usable hash exists can be reported. The original password
-- cannot be recovered from the database.

SELECT
    u.clubusername AS username,
    COALESCE(NULLIF(BTRIM(u.first_name), ''), 'Not set') AS first_name,
    COALESCE(NULLIF(BTRIM(u.surname), ''), 'Not set') AS surname,
    u.clubusername AS email_address,
    COALESCE(NULLIF(BTRIM(u.role), ''), 'user') AS role,
    o.organization_name AS club_or_account,
    CASE COALESCE(o.org_type, 'club')
        WHEN 'personal' THEN 'Personal account'
        ELSE 'Club'
    END AS account_type,
    CASE COALESCE(o.plan, 'club_essentials')
        WHEN 'personal_free' THEN 'Personal Free'
        WHEN 'personal_plus' THEN 'Personal Plus'
        WHEN 'club_essentials' THEN 'Club Essentials'
        WHEN 'club_pro' THEN 'Club Pro'
        ELSE INITCAP(REPLACE(o.plan, '_', ' '))
    END AS tier,
    COALESCE(NULLIF(BTRIM(u.approval_status), ''), 'approved') AS membership_status,
    CASE
        WHEN NULLIF(BTRIM(COALESCE(u.password_hash, '')), '') IS NULL
            THEN 'Not set'
        ELSE 'Set'
    END AS password_status
FROM "SkwshOrgUsers" AS u
INNER JOIN "SkwshOrgSettings" AS o
    ON o.id = u.organization_id
ORDER BY
    LOWER(u.clubusername),
    LOWER(o.organization_name),
    u.id;
