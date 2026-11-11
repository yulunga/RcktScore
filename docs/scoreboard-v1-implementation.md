# Scoreboard V1 Implementation Spec

**Naming:** HitnScore is the customer-facing application. `RcktScore` is the internal project and repository code name.

## Goal

Ship a first-testable public scoreboard flow for a single court without requiring a user login.

The current flow is:

1. A scoreboard opens `https://app.hitnscore.com/scoreboard` and shows a two-minute pairing QR.
2. A signed-in club admin opens Courts in the iOS or Android client, chooses a court and scans the QR.
3. The backend binds the pending request to that tenant and court, then the scoreboard exchanges it once for a read-only display session.
4. The backend returns the current active match for the court; the screen polls for updates and supports manual refresh.
5. The existing 12-character court display code remains available as a fallback.

Realtime fan-out is intentionally deferred until the polling-based testing flow is proven.

## Scope

Included in v1:

- public scoreboard route at `/scoreboard`
- court-scoped 12-character display codes
- read-only display sessions for the public scoreboard
- polling fallback every 5 seconds
- manual refresh button
- court-code generation and rotation from organisation settings and root-admin club management
- short-lived, one-time QR pairing approved by an authenticated club admin from iOS or Android

Deferred until after testing:

- Supabase Realtime / WebSocket fan-out
- hashed-only court code storage
- code expiry rules
- code rate limiting and lockout policy
- multi-screen device management

## QR Pairing Data Model

Migration `056_scoreboard_qr_pairing.sql` adds `scoreboard_pairing_requests`. It stores a SHA-256 token hash, hashed source IP, expiry, optional approved tenant/court/admin membership, approval time and consumption time. The raw token exists only in the scoreboard response and QR. Requests expire after two minutes, can be approved and consumed once, and are removed after their short operational lifetime.

## Current Data Model

### `SkwshCourts`

Added fields:

- `display_code text`
- `display_code_enabled boolean not null default false`
- `display_code_created_at timestamptz`
- `display_code_last_used_at timestamptz`

Current v1 decision:

- the active display code is stored on the court record in plaintext for faster testing and simpler admin support
- this is acceptable only because the screen is read-only and this is an early testing slice
- before launch hardening, this should move to a hashed or separately managed access model

### `court_display_sessions`

Purpose:

- stores read-only public display sessions after a valid code is entered

Fields:

- `id`
- `tenant_id`
- `court_id`
- `token_hash`
- `created_at`
- `expires_at`
- `last_seen_at`
- `revoked_at`

TTL:

- 24 hours from creation in the current implementation

## Backend Endpoints

### `POST /scoreboard_display/pairing`

Public, source-IP-rate-limited endpoint that creates a pending request and returns its raw token, `expires_at`, and a QR value. No court access or display session is granted at this stage.

### `POST /organization_courts/{court_id}/scoreboard-pairing`

Authenticated club-admin endpoint. It accepts `organization_id` and `token`, verifies that the court belongs to that tenant, then approves the unexpired request for that court. Scorer, read-only, cross-tenant and reused approvals are rejected.

### `POST /scoreboard_display/session/qr`

Public one-time exchange. Before approval it returns `state: pending`. After approval it atomically consumes the request and returns the normal court display-session payload. An expired or already-consumed token cannot create another session.

### `POST /scoreboard_display/session`

Public endpoint.

Request:

```json
{
  "code": "ABCD2345WXYZ"
}
```

Response:

```json
{
  "display_session_token": "opaque-token",
  "court": {
    "id": 7,
    "tenant_id": 12,
    "court_name": "Court 1",
    "court_alias": "Glass Court",
    "display_code_enabled": true,
    "created_at": "2026-05-10T11:42:00+00:00",
    "display_code_created_at": "2026-05-10T12:02:00+00:00",
    "display_code_last_used_at": "2026-05-10T12:08:00+00:00"
  },
  "match": {
    "...": "standard match payload when an active court match exists"
  },
  "poll_interval_seconds": 5,
  "realtime_mode": "polling_v1"
}
```

Errors:

- `400 INVALID_INPUT` for malformed code
- `404 DISPLAY_CODE_NOT_FOUND` for an unknown or disabled code

### `GET /scoreboard_display/current`

Read-only display refresh endpoint.

Auth:

- `Authorization: Bearer <display_session_token>`

Response:

- same `court`, `match`, `poll_interval_seconds`, and `realtime_mode` structure as the session creation response

Errors:

- `401 DISPLAY_SESSION_REQUIRED`
- `401 DISPLAY_SESSION_INVALID`
- `401 DISPLAY_SESSION_EXPIRED`

### `POST /organization_courts/{court_id}/display-code`

Protected org-admin or root-admin endpoint.

Request:

```json
{
  "organization_id": 12
}
```

Behavior:

- generates or rotates a 12-character court display code
- enables scoreboard access for that court
- returns the updated court plus a refreshed organisation settings payload

## Frontend Flow

### Public scoreboard

Route:

- `/scoreboard`

Behavior:

- if a display session is not present, show QR pairing by default with manual code entry as a second tab
- if a display session exists, load the current court match immediately
- poll `GET /scoreboard_display/current` every 5 seconds
- allow manual refresh
- if the session expires or becomes invalid, clear the stored session and return to the code-entry form

Client storage:

- `sessionStorage["rcktscore.scoreboardDisplay"]`

Stored values:

- `display_session_token`
- `poll_interval_seconds`
- `court`

### Admin court management

Organisation settings and root-admin club pages now show:

- the current display code for each court
- a `Generate Display Code` action when no code exists
- a `Rotate Display Code` action when a code already exists

## Testing Path

### Setup

1. Run schema migration `backend/schema/013_scoreboard_display_access.sql`.
2. Open organisation settings or the root-admin club page.
3. Generate or rotate a display code for a court.

### Functional test

1. Start an active match on that court.
2. Open `/scoreboard`.
3. In an iOS or Android admin session, open that club's Courts section, choose the court and scan the QR.
4. Confirm the scoreboard signs in automatically and the current match appears.
5. Score points from the scorer app.
6. Confirm the scoreboard updates on the next polling cycle or with manual refresh.
7. End the match.
8. Confirm the scoreboard transitions to the empty-court state.
9. Confirm rescanning or re-exchanging the same QR is rejected, an expired QR requires refresh, a non-admin cannot approve it, and an admin cannot bind it to another tenant's court.
10. Repeat using the 12-character display code to confirm the fallback remains operational.

### Expected v1 limitations

- the public scoreboard is polling-based, not realtime yet
- updates can lag by up to the poll interval
- the display code is currently visible to admins in plain form
- session expiry currently requires re-entering the code

## Next Step After V1 Testing

Once the polling flow is stable, add Supabase Realtime for court-scoped updates:

- channel concept: `tenant:{tenant_id}:court:{court_id}`
- keep HTTP writes as the source of truth
- push court updates to viewers
- retain polling/manual refresh as fallback if Realtime drops
