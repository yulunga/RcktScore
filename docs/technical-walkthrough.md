# Technical Walkthrough

## Purpose

This document describes the current end-to-end request lifecycles in `RcktScore` v2.
It is written to help developers trace product behavior through the actual web app,
Lambda handlers, and shared backend logic.

For the route inventory and security posture, see [backend-api.md](/Users/glennrowe/Development/Projects/RcktScore/docs/backend-api.md).
For operational debugging, see [troubleshooting.md](/Users/glennrowe/Development/Projects/RcktScore/docs/troubleshooting.md).

## Shared Request Pattern

Most current requests follow this path:

1. A React page or iOS view triggers an action.
2. The client calls the HTTP API through:
   - [frontend/src/services/api.js](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/services/api.js)
   - `mobile/ios/.../Services/APIClient.swift`
3. API Gateway invokes a Lambda from [backend/template.yaml](/Users/glennrowe/Development/Projects/RcktScore/backend/template.yaml).
4. The Lambda parses input with [backend/common/utils.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/utils.py).
5. Shared business logic runs in `backend/common/`.
6. Postgres reads/writes go through [backend/common/supabase_client.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/supabase_client.py).
7. The Lambda returns the shared response envelope.
8. The client updates local state and rerenders.

## Response Envelope

Success:

```json
{
  "success": true,
  "data": {},
  "error": null,
  "meta": {}
}
```

Error:

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message"
  },
  "meta": {}
}
```

## 1. Organisation Login Flow

### Frontend entry

- [frontend/src/pages/LoginPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/LoginPage.jsx)
- [frontend/src/context/AuthContext.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/context/AuthContext.jsx)

### Current path

1. The user submits `username` and `password`.
2. `AuthContext.login(...)` calls `POST /login`.
3. [backend/functions/login/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/login/handler.py) validates the body.
4. The handler calls [authenticate_org_user_memberships(...)](/Users/glennrowe/Development/Projects/RcktScore/backend/common/auth_logic.py).
5. Matching approved memberships are loaded from `SkwshOrgUsers` joined with `SkwshOrgSettings`.
6. The handler checks for an already-active session for the same client type.
7. The handler creates a session token in `org_user_sessions`.
8. The API returns one of:
   - `data.session`
   - `data.organizationSelection`
   - `PENDING_APPROVAL`
   - `ACTIVE_SESSION_EXISTS`
9. The frontend stores the result in `sessionStorage`.

### Troubleshooting cues

- `401 INVALID_CREDENTIALS` means no approved membership matched the password.
- `403 PENDING_APPROVAL` means the email invitation exists but has not been accepted.
- `409 ACTIVE_SESSION_EXISTS` means the same account is already signed in on the same client type.

## 2. Root-Admin Login Flow

### Frontend entry

- [frontend/src/pages/RootAdminLoginPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/RootAdminLoginPage.jsx)
- [frontend/src/context/RootAdminContext.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/context/RootAdminContext.jsx)

### Current path

1. The root admin submits username and password plus the client-side human-check.
2. The frontend calls `POST /root_admin/login`.
3. [backend/functions/root_admin_login/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/root_admin_login/handler.py) verifies credentials against `SkRootAdmin`.
4. The API returns `data.rootAdminSession`.
5. The frontend stores that object in `sessionStorage`.

### Important current limitation

This is not backed by a proper backend root-admin session/token model yet.
Some root-admin routes still have no real server-side authorization layer.

## 3. Register-Interest Flow

### Frontend entry

- [frontend/src/pages/LoginPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/LoginPage.jsx)

### Current path

1. A visitor opens the interest form on the login page.
2. The frontend submits `first_name`, `surname`, `email`, and `use_type`.
3. The honeypot field is `company`.
4. [backend/functions/register_interest/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/register_interest/handler.py):
   - validates the payload
   - writes or updates `HitnScoreInterestRequests`
   - sends confirmation/admin emails through SES
5. The API returns `202` with `data.accepted = true`.

### Troubleshooting cues

- missing interest-request table returns `INTEREST_REQUESTS_TABLE_MISSING`
- SES issues return `INTEREST_EMAIL_FAILED`

## 4. Password Reset Flow

### Frontend entry

- [frontend/src/pages/HelpPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/HelpPage.jsx)

### Current path

1. A signed-out user opens `/help`.
2. The request form calls `POST /password_reset/request`.
3. [backend/functions/password_reset_request/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/password_reset_request/handler.py) delegates to `password_reset_logic.py`.
4. The reset link base URL comes from:
   - `PASSWORD_RESET_BASE_URL`, then
   - request `Origin`
5. The emailed link returns to `/help?mode=reset&token=...`.
6. The confirm form calls `POST /password_reset/confirm`.

### Troubleshooting cues

- if reset emails are not arriving, check SES sender configuration and `PASSWORD_RESET_FROM_EMAIL`
- if links point to the wrong frontend host, check `PASSWORD_RESET_BASE_URL` and request `Origin`

## 5. Dashboard Flow

### Frontend entry

- [frontend/src/pages/DashboardPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/DashboardPage.jsx)

### Current path

1. The signed-in user lands on:
   - `/dashboard`
   - `/matches`
   - `/history`
2. The frontend calls `GET /dashboard/{organization_id}` with optional:
   - `active_limit`
   - `recent_limit`
3. [backend/functions/get_dashboard/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/get_dashboard/handler.py) authorizes the org-user session.
4. [backend/common/dashboard_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/dashboard_logic.py):
   - loads organisation summary
   - loads active matches
   - loads scheduled matches for clubs
   - loads completed match history
   - applies personal-plan history limits
5. The API returns `data.dashboard`.
6. The page renders screen-mode-specific views for dashboard, matches, or history.

### Troubleshooting cues

- empty match lists can be valid if the `matches` tables are missing or empty
- personal accounts intentionally return reduced history lists

## 6. Organisation Settings Flow

### Frontend entry

- [frontend/src/pages/OrganisationSettingsPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/OrganisationSettingsPage.jsx)

### Current path

1. The page calls `GET /organization_settings/{organization_id}`.
2. [backend/functions/get_organization_settings/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/get_organization_settings/handler.py) authorizes the org-user session.
3. [backend/common/organization_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/organization_logic.py) returns:
   - `organization`
   - `users`
   - `courts`
4. The frontend renders:
   - organisation details
   - personal profile
   - user admin
   - court admin
   - map preview
   - scaffold-only game settings
   - scaffold-only social profile fields

### Current limitation

The organisation-level handicap setting and social-profile fields are still UI scaffolds and are not persisted/enforced.

## 7. Personal Profile Update Flow

### Frontend entry

- [frontend/src/pages/OrganisationSettingsPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/OrganisationSettingsPage.jsx)

### Current path

1. The signed-in personal user submits their profile form.
2. The frontend calls `PUT /personal_profile/{organization_id}` with `username`.
3. [backend/functions/update_personal_profile/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/update_personal_profile/handler.py) authorizes that the signed-in user matches the payload username.
4. Shared logic updates the corresponding `SkwshOrgUsers` row.
5. The API returns updated `organizationSettings`.

## 8. Organisation User Invite / Approval Flow

### Create user

1. The organisation settings page or root-admin club page submits a new email/role.
2. The frontend calls:
   - `POST /organization_users`, or
   - `POST /root_admin/organization_users`
3. Shared logic in `organization_logic.py`:
   - validates role and email
   - allows linking the same email to multiple organisations
   - creates an approval token
   - stores `approval_status = pending`
   - sends an invitation email when email settings are configured

### Approve invite

1. The invited user opens the email link.
2. `GET /organization_users/approve?token=...` runs.
3. The Lambda updates the membership to approved and returns an HTML page.

### Troubleshooting cues

- a user may exist in multiple organisations with one password hash
- login remains blocked until approval is accepted
- the approval route returns HTML, not JSON

## 9. Court Flow

### Current path

1. The frontend creates, updates, or deletes a court.
2. The backend authorizes the user as an org admin for normal club use.
3. Shared logic inserts, updates, or deletes rows from `SkwshCourts`.
4. The API returns `data.court` or `data.deleted`.

### Root-admin note

The root-admin club page performs some of these mutations using `rootAdminRequest: true`, which becomes `x-root-admin-request: true` in the client.

## 10. Match Setup Lookup Flow

### Frontend entry

- [frontend/src/pages/NewMatch.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/NewMatch.jsx)

### Current path

1. The user types player or referee text during match setup.
2. The frontend calls `GET /match_setup_lookup/{organization_id}?q=...`.
3. [backend/common/match_setup_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/match_setup_logic.py):
   - searches prior match player names
   - searches current org-user usernames for referee suggestions
4. The API returns `data.lookups`.

## 11. Match Creation Flow

### Frontend entry

- [frontend/src/pages/NewMatch.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/NewMatch.jsx)
- [frontend/src/context/MatchContext.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/context/MatchContext.jsx)

### Current path

1. The operator submits player, court, referee, score type, best-of, and optional handicap data.
2. The frontend calls `POST /start_match`.
3. [backend/functions/create_match/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/create_match/handler.py) authorizes the org-user session.
4. [backend/common/match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/match_logic.py):
   - blocks personal accounts from having more than one active match
   - can auto-schedule a club match if the chosen court already has an active match
   - writes a `matches` row
   - writes a `match_started` event
5. The API returns `data.match` and `data.broadcast`.
6. The frontend navigates to the match screen unless the match is left as scheduled.

## 12. Match Load and Scoring Flow

### Frontend entry

- [frontend/src/pages/MatchScreen.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/MatchScreen.jsx)
- [frontend/src/components/MatchControls.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/components/MatchControls.jsx)

### Current path

1. The page loads `GET /get_score/{match_id}`.
2. The backend authorizes access to the match tenant.
3. Shared logic loads `matches` plus `match_events`.
4. Live state is rebuilt from the event stream.
5. Operator actions call:
   - `POST /score_point`
   - `POST /event_action`
   - `POST /undo_action`
   - `POST /end_match`
6. Shared logic updates event history and match summary columns.
7. The frontend updates local match state from the returned `data.match`.

### Supported event actions

- `let`
- `stroke`
- `server`
- `serve_side`
- `match_settings`
- `timer`

### Troubleshooting cues

- undo removes the last non-`match_started` event
- `stroke` is score-aware and can end a game or match
- shirt-colour changes are plan-aware

## 13. Display Screen Flow

### Frontend entry

- [frontend/src/pages/DisplayScreen.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/DisplayScreen.jsx)

### Current path

1. The display page opens with `?match=<id>`.
2. It loads the same match payload as the operator screen.
3. It attempts a WebSocket connection through [frontend/src/services/websocket.js](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/services/websocket.js).
4. It renders a read-only scoreboard and optional event timeline.

### Important current limitation

WebSocket client code exists, but subscriber registration/persistence infrastructure is not finished. Treat the display experience as fetch-driven with partial realtime support.

## 14. Root-Admin Operations Flow

### Frontend entry

- [frontend/src/pages/RootAdminDashboardPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/RootAdminDashboardPage.jsx)
- [frontend/src/pages/RootAdminClubPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/RootAdminClubPage.jsx)
- [frontend/src/pages/RootAdminInterestRequestsPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/RootAdminInterestRequestsPage.jsx)
- [frontend/src/pages/RootAdminPersonalAccountsPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/RootAdminPersonalAccountsPage.jsx)

### Current path

1. The root-admin UI loads dashboard, club, interest, and personal-account data from root-admin routes.
2. Some routes call backend functions with no full server-side root-admin session validation.
3. Some club-detail routes call normal organisation endpoints with `x-root-admin-request: true`.

### Important current limitation

The root-admin frontend experience exists, but the backend trust model is not yet at launch quality.

## 15. Native iOS Flow

### Current path

1. The iOS app logs in against the same backend.
2. It loads dashboard data from `GET /dashboard/{organization_id}`.
3. It opens active or scheduled matches.
4. It uses the same match/scoring routes as the web app.

### Current native gap

The native app does not yet fully match the web scorer flow for warm-up, first-server selection, and timer behavior.

## 16. Current Cross-Cutting Gaps

- root-admin backend authorization is incomplete
- WebSocket infrastructure is incomplete
- organisation game settings persistence is incomplete
- social profile persistence is incomplete
- no automated test suite is checked into the repo

## Maintenance Rule

When request behavior, auth behavior, route ownership, or troubleshooting assumptions change:

- update this file
- update [backend-api.md](/Users/glennrowe/Development/Projects/RcktScore/docs/backend-api.md)
- update [troubleshooting.md](/Users/glennrowe/Development/Projects/RcktScore/docs/troubleshooting.md)
