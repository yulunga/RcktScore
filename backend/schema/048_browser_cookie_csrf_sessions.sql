ALTER TABLE org_user_sessions
    ADD COLUMN IF NOT EXISTS csrf_token text;

ALTER TABLE root_admin_sessions
    ADD COLUMN IF NOT EXISTS csrf_token text;

-- Existing browser credentials were exposed to JavaScript storage. Force web
-- and root-admin users through the new cookie login flow after deployment while
-- leaving native bearer sessions untouched.
UPDATE org_user_sessions
SET revoked_at = COALESCE(revoked_at, NOW()),
    revoked_reason = COALESCE(revoked_reason, 'web_cookie_security_upgrade')
WHERE login_source = 'web_app'
  AND revoked_at IS NULL;

UPDATE root_admin_sessions
SET revoked_at = COALESCE(revoked_at, NOW()),
    revoked_reason = COALESCE(revoked_reason, 'web_cookie_security_upgrade')
WHERE revoked_at IS NULL;
