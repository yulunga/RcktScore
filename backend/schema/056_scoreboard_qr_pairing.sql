CREATE TABLE IF NOT EXISTS scoreboard_pairing_requests (
    id bigserial PRIMARY KEY,
    token_hash text NOT NULL UNIQUE,
    request_ip_hash text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    tenant_id bigint REFERENCES "SkwshOrgSettings"(id) ON DELETE CASCADE,
    court_id bigint REFERENCES "SkwshCourts"(id) ON DELETE CASCADE,
    approved_by_membership_id bigint REFERENCES "SkwshOrgUsers"(id) ON DELETE SET NULL,
    approved_at timestamptz,
    consumed_at timestamptz,
    exchange_attempts integer NOT NULL DEFAULT 0 CHECK (exchange_attempts >= 0),
    CHECK (
        (approved_at IS NULL AND tenant_id IS NULL AND court_id IS NULL AND approved_by_membership_id IS NULL)
        OR
        (approved_at IS NOT NULL AND tenant_id IS NOT NULL AND court_id IS NOT NULL AND approved_by_membership_id IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS scoreboard_pairing_requests_expiry_idx
    ON scoreboard_pairing_requests (expires_at);

CREATE INDEX IF NOT EXISTS scoreboard_pairing_requests_ip_rate_idx
    ON scoreboard_pairing_requests (request_ip_hash, created_at DESC);

ALTER TABLE scoreboard_pairing_requests ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE scoreboard_pairing_requests IS
    'Short-lived, single-use TV-style pairing requests displayed by a public scoreboard and approved by a club administrator for one court.';
COMMENT ON COLUMN scoreboard_pairing_requests.token_hash IS
    'SHA-256 hash of the opaque QR bearer token; the plaintext token is never stored.';
COMMENT ON COLUMN scoreboard_pairing_requests.request_ip_hash IS
    'One-way source-IP hash retained only with the short-lived request for application-level creation throttling.';
