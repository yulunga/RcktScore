-- Run the entire file in the Supabase SQL Editor. The default is a read-only
-- preview. Change apply_backfill to true after reviewing the counts.
-- Apply mode briefly blocks writes to the identity and membership tables.
-- New accounts receive Personal Free. Existing personal plans stay intact.

BEGIN;
SET LOCAL lock_timeout = '5s';

DO $backfill$
DECLARE
    apply_backfill constant boolean := false;
    candidate_count bigint;
    approved_count bigint;
    created_count bigint;
BEGIN
    IF apply_backfill THEN
        LOCK TABLE "SkwshOrgSettings", "SkwshOrgUsers", "users"
            IN SHARE ROW EXCLUSIVE MODE;
    END IF;

    CREATE TEMP TABLE personal_backfill_candidates ON COMMIT DROP AS
    SELECT
        identity.email_normalized AS username,
        identity.first_name,
        identity.surname,
        COALESCE(
            NULLIF(BTRIM(CONCAT_WS(' ', identity.first_name, identity.surname)), ''),
            identity.email_normalized
        ) AS contact_name,
        credential.password_hash,
        credential.approved_at,
        COALESCE(credential.is_approved, false) AS is_approved
    FROM "users" AS identity
    LEFT JOIN LATERAL (
        SELECT
            membership.password_hash,
            membership.approved_at,
            COALESCE(membership.approval_status, 'approved') = 'approved' AS is_approved
        FROM "SkwshOrgUsers" AS membership
        WHERE LOWER(BTRIM(membership.clubusername)) = identity.email_normalized
          AND NULLIF(BTRIM(membership.password_hash), '') IS NOT NULL
        ORDER BY is_approved DESC, membership.id
        LIMIT 1
    ) AS credential ON true
    WHERE identity.email_normalized <> ''
      AND NOT EXISTS (
          SELECT 1
          FROM "SkwshOrgUsers" AS membership
          JOIN "SkwshOrgSettings" AS org ON org.id = membership.organization_id
          WHERE LOWER(BTRIM(membership.clubusername)) = identity.email_normalized
            AND org.org_type = 'personal'
      );

    SELECT COUNT(*), COUNT(*) FILTER (WHERE is_approved)
    INTO candidate_count, approved_count
    FROM personal_backfill_candidates;

    RAISE NOTICE 'Personal memberships to add: % (% approved, % pending).',
        candidate_count, approved_count, candidate_count - approved_count;

    IF NOT apply_backfill THEN
        RAISE NOTICE 'Preview complete. No accounts were changed.';
        RETURN;
    END IF;

    INSERT INTO "SkwshOrgSettings" (
        id, created_at, organization_name, org_contact, org_email,
        org_type, plan, owner_username, is_hidden, enabled_sports
    )
    SELECT
        nextval('hitnscore_personal_org_id_seq'), now(),
        candidate.contact_name || ' Personal', candidate.contact_name, candidate.username,
        'personal', 'personal_free', candidate.username, true,
        COALESCE(platform.enabled_sports, '["squash", "racketball", "tennis"]'::jsonb)
    FROM personal_backfill_candidates AS candidate
    LEFT JOIN platform_settings AS platform ON platform.id = 'default'
    WHERE NOT EXISTS (
        SELECT 1
        FROM "SkwshOrgSettings" AS org
        WHERE org.org_type = 'personal'
          AND LOWER(BTRIM(org.owner_username)) = candidate.username
    );

    INSERT INTO "SkwshOrgUsers" (
        created_at, clubusername, password_hash, organization_id,
        first_name, surname, role, approval_status, approved_at
    )
    SELECT
        now(), candidate.username, candidate.password_hash, org.id,
        candidate.first_name, candidate.surname, 'admin',
        CASE WHEN candidate.is_approved THEN 'approved' ELSE 'pending' END,
        CASE WHEN candidate.is_approved THEN candidate.approved_at END
    FROM personal_backfill_candidates AS candidate
    JOIN "SkwshOrgSettings" AS org
        ON org.org_type = 'personal' AND LOWER(BTRIM(org.owner_username)) = candidate.username;

    GET DIAGNOSTICS created_count = ROW_COUNT;
    IF created_count <> candidate_count THEN
        RAISE EXCEPTION 'Expected % personal memberships, inserted %.', candidate_count, created_count;
    END IF;

    INSERT INTO "SkwshCourts" (created_at, court_name, court_alias, organization_name)
    SELECT now(), 'Personal Court', 'Personal Court', org.id
    FROM personal_backfill_candidates AS candidate
    JOIN "SkwshOrgSettings" AS org
        ON org.org_type = 'personal' AND LOWER(BTRIM(org.owner_username)) = candidate.username
    WHERE NOT EXISTS (
        SELECT 1 FROM "SkwshCourts" AS court WHERE court.organization_name = org.id
    );

    RAISE NOTICE 'Added % personal memberships.', created_count;
END;
$backfill$;

COMMIT;
