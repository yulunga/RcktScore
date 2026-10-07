CREATE TABLE IF NOT EXISTS tournament_organization_features (
    organization_id bigint PRIMARY KEY REFERENCES "SkwshOrgSettings"(id) ON DELETE CASCADE,
    web_enabled boolean NOT NULL DEFAULT false,
    enabled_by text,
    enabled_at timestamptz,
    updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE tournament_organization_features IS
    'Club-level Tournament Manager feature access. Missing rows and false values mean disabled.';

CREATE TABLE IF NOT EXISTS "users" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email text NOT NULL,
    email_normalized text GENERATED ALWAYS AS (LOWER(BTRIM(email))) STORED,
    first_name text NOT NULL DEFAULT '',
    surname text NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (email_normalized)
);

COMMENT ON TABLE "users" IS
    'Canonical signed-up HitNScore identities. Organisation memberships and credentials remain in SkwshOrgUsers during the compatibility migration.';

INSERT INTO "users" (email, first_name, surname, created_at, updated_at)
SELECT DISTINCT ON (LOWER(BTRIM(clubusername)))
    LOWER(BTRIM(clubusername)),
    COALESCE(first_name, ''),
    COALESCE(surname, ''),
    COALESCE(created_at, now()),
    now()
FROM "SkwshOrgUsers"
WHERE COALESCE(BTRIM(clubusername), '') <> ''
ORDER BY LOWER(BTRIM(clubusername)), id ASC
ON CONFLICT (email_normalized) DO UPDATE
SET first_name = CASE WHEN EXCLUDED.first_name <> '' THEN EXCLUDED.first_name ELSE "users".first_name END,
    surname = CASE WHEN EXCLUDED.surname <> '' THEN EXCLUDED.surname ELSE "users".surname END,
    updated_at = now();

ALTER TABLE "SkwshOrgUsers"
    ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES "users"(id) ON DELETE RESTRICT;

UPDATE "SkwshOrgUsers" AS membership
SET user_id = identity.id
FROM "users" AS identity
WHERE membership.user_id IS NULL
  AND LOWER(BTRIM(membership.clubusername)) = identity.email_normalized;

CREATE OR REPLACE FUNCTION sync_skwsh_org_user_identity()
RETURNS trigger AS $$
DECLARE
    identity_id uuid;
BEGIN
    INSERT INTO "users" (email, first_name, surname, created_at, updated_at)
    VALUES (
        LOWER(BTRIM(NEW.clubusername)),
        COALESCE(NEW.first_name, ''),
        COALESCE(NEW.surname, ''),
        COALESCE(NEW.created_at, now()),
        now()
    )
    ON CONFLICT (email_normalized) DO UPDATE
    SET first_name = CASE WHEN EXCLUDED.first_name <> '' THEN EXCLUDED.first_name ELSE "users".first_name END,
        surname = CASE WHEN EXCLUDED.surname <> '' THEN EXCLUDED.surname ELSE "users".surname END,
        updated_at = now()
    RETURNING id INTO identity_id;

    NEW.user_id = identity_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS skwsh_org_users_sync_identity ON "SkwshOrgUsers";
CREATE TRIGGER skwsh_org_users_sync_identity
BEFORE INSERT OR UPDATE OF clubusername, first_name, surname
ON "SkwshOrgUsers"
FOR EACH ROW
EXECUTE FUNCTION sync_skwsh_org_user_identity();

CREATE TABLE IF NOT EXISTS players (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid UNIQUE REFERENCES "users"(id) ON DELETE SET NULL,
    registered_username text,
    email text,
    first_name text NOT NULL,
    surname text NOT NULL DEFAULT '',
    normalized_name text NOT NULL,
    country text,
    home_club_name text,
    claim_status text NOT NULL DEFAULT 'unclaimed',
    created_by_organization_id bigint REFERENCES "SkwshOrgSettings"(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    claimed_at timestamptz,
    CONSTRAINT players_claim_status_check CHECK (
        claim_status IN ('unclaimed', 'claimable', 'linked')
    ),
    CONSTRAINT players_name_check CHECK (length(trim(first_name)) > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS players_registered_username_key
    ON players (LOWER(registered_username))
    WHERE registered_username IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS players_email_key
    ON players (LOWER(email))
    WHERE email IS NOT NULL;

CREATE INDEX IF NOT EXISTS players_name_idx
    ON players (normalized_name);

COMMENT ON TABLE players IS
    'Product-wide reusable player identities for scoring and tournaments. A player may exist without an app login and can later be linked to a verified username.';

CREATE TABLE IF NOT EXISTS player_organization_affiliations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id uuid NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    organization_id bigint NOT NULL REFERENCES "SkwshOrgSettings"(id) ON DELETE CASCADE,
    relationship text NOT NULL DEFAULT 'guest',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT player_organization_affiliations_relationship_check CHECK (
        relationship IN ('guest', 'member')
    ),
    UNIQUE (player_id, organization_id)
);

COMMENT ON TABLE player_organization_affiliations IS
    'Non-authentication relationship between a player and a host club. Guest does not grant account access.';

CREATE TABLE IF NOT EXISTS tournament_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id bigint NOT NULL REFERENCES "SkwshOrgSettings"(id) ON DELETE CASCADE,
    name text NOT NULL,
    sport text NOT NULL,
    draw_format text NOT NULL,
    status text NOT NULL DEFAULT 'draft',
    venue_name text,
    starts_on date,
    ends_on date,
    scoring_config jsonb NOT NULL DEFAULT '{}'::jsonb,
    format_config jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_by_username text NOT NULL,
    revision integer NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT tournament_events_name_check CHECK (length(trim(name)) > 0),
    CONSTRAINT tournament_events_sport_check CHECK (
        sport IN ('squash', 'racketball', 'tennis', 'padel')
    ),
    CONSTRAINT tournament_events_draw_format_check CHECK (
        draw_format IN ('knockout', 'knockout_plate', 'round_robin', 'monrad')
    ),
    CONSTRAINT tournament_events_status_check CHECK (
        status IN ('draft', 'registration', 'draw_published', 'in_progress', 'completed', 'cancelled')
    ),
    CONSTRAINT tournament_events_date_check CHECK (
        starts_on IS NULL OR ends_on IS NULL OR ends_on >= starts_on
    )
);

CREATE INDEX IF NOT EXISTS tournament_events_organization_status_idx
    ON tournament_events (organization_id, status, starts_on DESC, created_at DESC);

CREATE TABLE IF NOT EXISTS tournament_entries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid NOT NULL REFERENCES tournament_events(id) ON DELETE CASCADE,
    player_id uuid NOT NULL REFERENCES players(id) ON DELETE RESTRICT,
    seed integer,
    entry_status text NOT NULL DEFAULT 'registered',
    first_name_snapshot text NOT NULL,
    surname_snapshot text NOT NULL DEFAULT '',
    club_snapshot text,
    country_snapshot text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT tournament_entries_seed_check CHECK (seed IS NULL OR seed > 0),
    CONSTRAINT tournament_entries_status_check CHECK (
        entry_status IN ('registered', 'waitlisted', 'withdrawn', 'active')
    ),
    UNIQUE (event_id, player_id)
);

CREATE INDEX IF NOT EXISTS tournament_entries_event_status_idx
    ON tournament_entries (event_id, entry_status, seed NULLS LAST, created_at ASC);

CREATE TABLE IF NOT EXISTS tournament_role_assignments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid NOT NULL REFERENCES tournament_events(id) ON DELETE CASCADE,
    username text NOT NULL,
    role text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT tournament_role_assignments_role_check CHECK (
        role IN ('organizer', 'scorer', 'official')
    ),
    UNIQUE (event_id, username, role)
);

CREATE TABLE IF NOT EXISTS tournament_audit_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id bigint NOT NULL REFERENCES "SkwshOrgSettings"(id) ON DELETE CASCADE,
    tournament_id uuid REFERENCES tournament_events(id) ON DELETE CASCADE,
    actor_username text NOT NULL,
    action text NOT NULL,
    entity_type text NOT NULL,
    entity_id text,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS tournament_audit_events_tournament_created_idx
    ON tournament_audit_events (tournament_id, created_at DESC);
