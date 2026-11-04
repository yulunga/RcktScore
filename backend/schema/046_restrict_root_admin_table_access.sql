-- Root-admin credentials are maintained through privileged SQL.
REVOKE ALL PRIVILEGES ON TABLE public."SkRootAdmin"
    FROM PUBLIC, anon, authenticated;

-- Table-level revocation does not remove separately granted column privileges.
DO $migration$
DECLARE
    columns text;
BEGIN
    SELECT string_agg(quote_ident(attname), ', ' ORDER BY attnum)
    INTO columns
    FROM pg_attribute
    WHERE attrelid = 'public."SkRootAdmin"'::regclass
      AND attnum > 0
      AND NOT attisdropped;

    EXECUTE format(
        'REVOKE ALL PRIVILEGES (%s) ON TABLE public."SkRootAdmin" FROM PUBLIC, anon, authenticated',
        columns
    );
END;
$migration$;
