# Scoreboard V1 Implementation Spec

## Goal

Ship a first-testable public scoreboard flow for a single court without requiring a user login.

The v1 flow is:

1. An admin or root admin creates or rotates a 12-character display code for a court.
2. A user opens `https://app.hitnscore.com/scoreboard`.
3. The user enters only that 12-character code.
4. The backend resolves the court and tenant, issues a read-only display session, and returns the current active match for the court.
5. The screen polls for updates and supports manual refresh.

Realtime fan-out is intentionally deferred until the polling-based testing flow is proven.

## Scope

Included in v1:

- public scoreboard route at `/scoreboard`
- court-scoped 12-character display codes
- read-only display sessions for the public scoreboard
- polling fallback every 5 seconds
- manual refresh button
- court-code generation and rotation from organisation settings and root-admin club management

Deferred until after testing:

- Supabase Realtime / WebSocket fan-out
- hashed-only court code storage
- code expiry rules
- code rate limiting and lockout policy
- multi-screen device management

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

- if a display session is not present, show a single code-entry form
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
3. Enter the court display code.
4. Confirm the current match appears.
5. Score points from the scorer app.
6. Confirm the scoreboard updates on the next polling cycle or with manual refresh.
7. End the match.
8. Confirm the scoreboard transitions to the empty-court state.

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
