CREATE TABLE IF NOT EXISTS public.schema_migrations (
    version integer PRIMARY KEY,
    filename text NOT NULL UNIQUE,
    checksum_sha256 text NOT NULL,
    applied_at timestamptz NOT NULL DEFAULT now(),
    applied_by text,
    git_commit text,
    execution_ms bigint,
    notes text,
    CONSTRAINT schema_migrations_positive_version_check
        CHECK (version > 0),
    CONSTRAINT schema_migrations_filename_check
        CHECK (filename ~ '^[0-9]{3}_[a-z0-9_]+[.]sql$'),
    CONSTRAINT schema_migrations_checksum_check
        CHECK (checksum_sha256 ~ '^[0-9a-f]{64}$'),
    CONSTRAINT schema_migrations_execution_ms_check
        CHECK (execution_ms IS NULL OR execution_ms >= 0)
);

COMMENT ON TABLE public.schema_migrations IS
    'Append-only record of schema migration files accepted by this database.';

COMMENT ON COLUMN public.schema_migrations.checksum_sha256 IS
    'SHA-256 of the exact checked-in migration file bytes at promotion time.';

COMMENT ON COLUMN public.schema_migrations.git_commit IS
    'Git commit promoted when the migration was applied or baselined.';

CREATE INDEX IF NOT EXISTS schema_migrations_applied_at_idx
    ON public.schema_migrations (applied_at DESC);

ALTER TABLE public.schema_migrations ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.schema_migrations FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.reject_schema_migration_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'schema_migrations is append-only';
END;
$$;

DROP TRIGGER IF EXISTS schema_migrations_append_only
    ON public.schema_migrations;

DROP TRIGGER IF EXISTS schema_migrations_no_truncate
    ON public.schema_migrations;

CREATE TRIGGER schema_migrations_append_only
    BEFORE UPDATE OR DELETE ON public.schema_migrations
    FOR EACH ROW
    EXECUTE FUNCTION public.reject_schema_migration_mutation();

CREATE TRIGGER schema_migrations_no_truncate
    BEFORE TRUNCATE ON public.schema_migrations
    FOR EACH STATEMENT
    EXECUTE FUNCTION public.reject_schema_migration_mutation();

REVOKE ALL ON FUNCTION public.reject_schema_migration_mutation() FROM PUBLIC;
