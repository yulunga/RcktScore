DO $$
DECLARE
    username_attnum smallint;
    constraint_name text;
    index_name text;
BEGIN
    SELECT attnum
    INTO username_attnum
    FROM pg_attribute
    WHERE attrelid = '"SkwshOrgUsers"'::regclass
      AND attname = 'clubusername'
      AND NOT attisdropped
    LIMIT 1;

    IF username_attnum IS NULL THEN
        RAISE EXCEPTION 'clubusername column was not found on "SkwshOrgUsers"';
    END IF;

    FOR constraint_name IN
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = '"SkwshOrgUsers"'::regclass
          AND contype = 'u'
          AND array_length(conkey, 1) = 1
          AND conkey[1] = username_attnum
    LOOP
        EXECUTE format('ALTER TABLE "SkwshOrgUsers" DROP CONSTRAINT IF EXISTS %I', constraint_name);
    END LOOP;

    FOR index_name IN
        SELECT indexname
        FROM pg_indexes
        WHERE schemaname = current_schema()
          AND tablename = 'SkwshOrgUsers'
          AND indexdef ILIKE 'CREATE UNIQUE INDEX%'
          AND indexdef ILIKE '%(clubusername)%'
          AND indexdef NOT ILIKE '%organization_id%'
    LOOP
        EXECUTE format('DROP INDEX IF EXISTS %I', index_name);
    END LOOP;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS skwsh_org_users_org_username_key
    ON "SkwshOrgUsers" (organization_id, clubusername);

CREATE INDEX IF NOT EXISTS skwsh_org_users_username_lookup_idx
    ON "SkwshOrgUsers" (clubusername);
