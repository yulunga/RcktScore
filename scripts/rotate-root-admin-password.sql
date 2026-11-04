-- Run as an authorised database operator in the target Supabase SQL Editor.
-- Requires migration 018_root_admin_sessions.sql.
-- List accounts first: SELECT id, rtusername FROM public."SkRootAdmin" ORDER BY id;
--
-- From the repository root, use the project's virtual environment, which
-- must have the backend's Werkzeug dependency installed.
-- This prompts for the password without echoing it.
-- .venv/bin/python -c 'from getpass import getpass; from werkzeug.security import generate_password_hash; p = getpass("New password: "); assert len(p) >= 16 and p == getpass("Confirm password: "), "Use at least 16 characters and matching entries"; print(generate_password_hash(p, method="scrypt:32768:8:1"))'
--
-- Replace all three placeholders below. Escape any single quote in the
-- username by doubling it. Paste only the generated hash into SQL.

DO $rotation$
DECLARE
    target_id bigint := NULL;
    target_username text := 'REPLACE_WITH_EXACT_USERNAME';
    new_password_hash text := 'REPLACE_WITH_GENERATED_HASH';
BEGIN
    IF target_id IS NULL THEN
        RAISE EXCEPTION 'Set the target root-admin ID';
    END IF;

    IF new_password_hash !~ '^scrypt:32768:8:1\$[A-Za-z0-9]{16}\$[0-9a-f]{128}$' THEN
        RAISE EXCEPTION 'Supply a Werkzeug scrypt password hash';
    END IF;

    UPDATE public."SkRootAdmin"
    SET password_hash = new_password_hash
    WHERE id = target_id AND rtusername = target_username;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The root-admin ID and username did not match';
    END IF;

    UPDATE public.root_admin_sessions
    SET revoked_at = CURRENT_TIMESTAMP,
        revoked_reason = 'password_rotated'
    WHERE root_admin_id = target_id AND revoked_at IS NULL;
END;
$rotation$;
