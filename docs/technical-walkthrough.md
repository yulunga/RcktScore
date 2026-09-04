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
7. The handler creates an expiring session token in `org_user_sessions`; the default lifetime is 30 days.
8. The API returns one of:
   - `data.session`
   - `data.organizationSelection`
   - `PENDING_APPROVAL`
   - `ACTIVE_SESSION_EXISTS`
   Successful session and organisation-selection responses also include `session_expires_at`.
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
4. The backend revokes older sessions for the same root-admin account and creates an eight-hour session in `root_admin_sessions`.
5. The API returns `data.rootAdminSession` with the opaque bearer token and `expires_at`; only its SHA-256 hash is stored in the database.
6. The frontend stores the session in `sessionStorage` and sends the bearer token on every root-admin request.
7. Each root-admin handler validates the token, expiry, revocation state, and current `SkRootAdmin` identity before doing any privileged work.
8. Logout calls `POST /root_admin/logout`, which revokes the current token.

## 3. Personal Signup and Club-Enquiry Flow

### Frontend entry

- [frontend/src/pages/LoginPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/LoginPage.jsx)

### Current path

1. A visitor opens the `Want In` form on the login page.
2. The frontend submits `first_name`, `surname`, `email`, and `use_type`.
3. The honeypot field is `company`.
4. [backend/functions/register_interest/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/register_interest/handler.py):
   - validates the payload
   - writes or updates `HitnScoreInterestRequests`
   - for Personal, automatically creates or refreshes the `personal_free` organisation, owner membership, and personal court, then sends a password-setup email
   - for Club, keeps the request pending and sends confirmation/admin enquiry emails
5. Personal signup returns `201` with `data.account_created = true`; the user verifies their email and chooses a password before signing in.
6. Club enquiries return `202` with `data.account_created = false` and remain controlled by the root-admin workflow.

### Troubleshooting cues

- missing interest-request table returns `INTEREST_REQUESTS_TABLE_MISSING`
- missing `PASSWORD_RESET_BASE_URL` returns `PERSONAL_SIGNUP_CONFIGURATION_ERROR`
- personal setup email issues return `PERSONAL_SIGNUP_EMAIL_FAILED`
- club enquiry email issues return `INTEREST_EMAIL_FAILED`

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
   - `organization.enabled_sports`
4. The frontend renders:
   - organisation details
   - personal profile
   - user admin
   - court admin
   - map preview
   - persisted racket-sport visibility controls
   - scaffold-only social profile fields

### Current limitation

The organisation-level handicap setting and social-profile fields are still UI scaffolds and are not persisted/enforced.

## 7. Personal Profile Update Flow

### Frontend entry

- [frontend/src/pages/OrganisationSettingsPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/OrganisationSettingsPage.jsx)

### Current path

1. The signed-in personal user submits their profile form.
2. The frontend or iOS app calls `PUT /personal_profile/{organization_id}` with first name, surname, email, telephone, country, and optional city fields.
3. [backend/functions/update_personal_profile/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/update_personal_profile/handler.py) authorizes the presented org-user session for that organisation and uses the session username as the source of truth.
4. Shared logic updates the linked `SkwshOrgUsers` rows for that account. If the email changes, it also updates the login username and revokes active sessions so the user must sign in again.
5. The API returns updated `organizationSettings`.

## 8. Organisation User Invite / Approval Flow

### Create user

1. The organisation settings page or root-admin club page submits a new email/role and may include first-name/surname values.
2. The frontend calls:
   - `POST /organization_users`, or
   - `POST /root_admin/organization_users`
3. Shared logic in `organization_logic.py`:
   - validates role and email
   - trims and stores optional first-name/surname values for the membership row
   - allows linking the same email to multiple organisations
   - creates an approval token
   - stores `approval_status = pending`
   - sends an invitation email when email settings are configured
4. The root-admin club page can later approve that pending membership directly with `PUT /root_admin/organization_users/{user_id}/approve` if email approval is not desired.

### Edit or remove user

1. The organisation user details page submits an update or delete action.
2. The frontend calls:
   - `PUT /organization_users/{user_id}`, or
   - `DELETE /organization_users/{user_id}`
3. Shared logic in `organization_logic.py`:
   - validates updated email, role, and optional password
   - only allows password edits when the email is not shared across other organisation memberships
   - revokes active sessions when a user email or password changes, or when the membership is deleted
   - blocks demoting or deleting the last remaining admin in the organisation

### Approve invite

1. The invited user opens the email link.
2. `GET /organization_users/approve?token=...` runs.
3. The Lambda updates the membership to approved and returns an HTML page.
4. If `USER_APPROVAL_LOGIN_URL` is configured, the success page stays visible for three seconds and then redirects to sign in.

### Troubleshooting cues

- a user may exist in multiple organisations with one password hash
- login remains blocked until approval is accepted
- the approval route returns HTML, not JSON
- `USER_APPROVAL_BASE_URL` controls the branded approval-link host/path used in invitation emails

## 9. Court Flow

### Current path

1. The frontend creates, updates, or deletes a court.
2. The backend authorizes the user as an org admin for normal club use.
3. Shared logic inserts, updates, or deletes rows from `SkwshCourts`.
4. The API returns `data.court` or `data.deleted`.

### Root-admin note

The root-admin club page marks these shared calls as root-admin requests in the API client. The client sends the stored root-admin bearer token, and the backend validates it before permitting access. No caller-controlled trust header is used.

## 10. Match Setup Lookup Flow

### Frontend entry

- [frontend/src/pages/NewMatch.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/NewMatch.jsx)
- [mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/StartNewMatchView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/StartNewMatchView.swift)

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
- [mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/StartNewMatchView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/StartNewMatchView.swift)

### Current path

1. The operator submits player, court, referee, sport, score type, best-of, and optional handicap data.
2. The frontend calls `POST /start_match`.
3. [backend/functions/create_match/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/create_match/handler.py) authorizes the org-user session.
4. [backend/common/match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/match_logic.py):
   - normalizes the requested sport
   - rejects sports that are not present in the organisation or personal account `enabled_sports` list
   - dispatches match creation to the correct sport engine
   - allows live match creation today for squash, racketball, and tennis
   - fails safely for sport engines that are wired but not yet implemented
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
- [mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/MatchScoringView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/MatchScoringView.swift)

### Current path

1. The page loads `GET /get_score/{match_id}`.
2. The backend authorizes access to the match tenant.
3. Shared logic loads `matches` plus `match_events`, then dispatches serialization through the sport engine for that match.
4. Live state is rebuilt from the event stream.
5. Operator actions call:
   - `POST /score_point`
   - `POST /event_action`
   - `POST /undo_action`
   - `POST /end_match`
6. Native iOS supplies a stable `client_action_id` UUID for each queued mutation. `match_action_receipts` claims that UUID before the mutation so reconnect retries cannot duplicate a point or other action.
7. Shared logic updates event history and match summary columns using the active sport engine.
8. The web frontend updates local match state from the returned `data.match`. Native iOS caches the last server match, applies queued actions locally, and replaces its cached base state with each ordered server response during synchronisation.

Current live sport engines:

- squash and racketball share [backend/common/squash_match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/squash_match_logic.py)
- tennis uses [backend/common/tennis_match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/tennis_match_logic.py)
- padel, table tennis, badminton, and pickleball engine files exist but are not live scoring paths yet

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
2. Every root-admin route validates the bearer token against `root_admin_sessions`.
3. Club-detail calls to shared organisation endpoints accept root access only after the same session validation succeeds.
4. The platform dashboard now also links to a root-admin match directory that calls `GET /root_admin/matches` and can archive or delete matches across the system.
5. Match archive is implemented as a flag on `matches`, so archived matches drop out of standard dashboard/history lists without deleting the underlying row.
6. The platform dashboard now also links to a root-admin `RacketSports` page that calls `GET /root_admin/platform_sports` and `PUT /root_admin/platform_sports` to set the globally allowed sport list and push that same list to all clubs and personal accounts.

### Remaining hardening

The root-admin trust boundary is now enforced. Rate limiting, richer security audit events, and operational session-management tooling remain launch-hardening work.

## 15. Native iOS Flow

### Current path

1. [ContentView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/ContentView.swift) routes the app to `LoginView` or `DashboardView` based on the persisted `SessionStore`, but clears the saved session and requires fresh credentials once `session_expires_at` is reached.
2. [LoginView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/LoginView.swift) calls `POST /login` with `client_type = mobile_app`, handles `ACTIVE_SESSION_EXISTS`, exposes a local show/hide password control, and branches between `data.session` and `data.organizationSelection`. Multi-membership users receive a native account picker. First-time sign-in requires connectivity, and the login card displays an offline explanation when no network is available.
3. [DashboardView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/DashboardView.swift) loads `GET /dashboard/{organization_id}` and presents `Home`, `Matches`, `History`, `Settings`, and `Need Help`. The header bell becomes an offline indicator while disconnected, and a cached active match can be reopened from the active-match section.
4. The native settings flow in `DashboardView.swift` now adapts its menu by plan and account type. Personal accounts see subscription, profile, association, racket-sport, game-settings, About, and help sections with a device-local profile photo picker and a bottom sign-out row. Personal+ additionally exposes reporting and stats menu entries, but those are still placeholder views today. Each native settings row now pushes to its own detail page rather than expanding inline on the main settings screen. Club admins also call `GET /organization_settings/{organization_id}` and `PUT /organization_details/{organization_id}` to manage organisation details, users, courts, and the persisted `enabled_sports` racket-sport visibility list.
5. The native profile page now edits first name, surname, email/username, telephone, and country through `PUT /personal_profile/{organization_id}`, and still uses the shared password-reset request route rather than a dedicated in-app password change endpoint. Profile photos remain local to the device and are not stored in a central shared profile service yet.
6. [SessionStore.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/State/SessionStore.swift) tracks session expiry and whether local biometric unlock is available and enabled. Face ID or Touch ID unlocks only an unexpired session already saved on that device; it is not a second backend login method.
7. The native About page reads the installed app version and build directly from the iOS bundle metadata on device; it does not rely on a backend route.
8. The native association page now uses the locally persisted membership list from login to let multi-club users switch the active organisation without signing out. That switch refreshes dashboard and settings data against the selected membership.
9. [StartNewMatchView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/StartNewMatchView.swift) uses `GET /organization_settings/{organization_id}`, `GET /match_setup_lookup/{organization_id}`, and `POST /start_match` for the native match-setup flow. The picker only shows sports that are both enabled for the tenant and implemented in the iOS client today. The flow now uses the same dark/light adaptive palette as the dashboard, personal-tier squash/racketball users can enable handicap setup there, and tennis setup can now switch between singles and doubles with lineup metadata sent in the create-match payload.
10. [MatchScoringView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/MatchScoringView.swift) loads and caches `GET /get_score/{match_id}`, optionally loads display access, and uses the shared scoring routes for score, event actions, undo, scheduled start, and early end. [OfflineMatchStore.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/State/OfflineMatchStore.swift) retains one active match and its ordered action queue in device storage. Squash/racketball and tennis—including tennis sets, tie-breaks, singles/doubles server order, receiver order, and local event state—continue locally without connectivity. Reconnection replays UUID-tagged actions in order and adopts each authoritative server response.
11. [HistoricMatchView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/HistoricMatchView.swift) reloads the same match payload and renders grouped historic point/event data for completed matches.
12. Offline scope is deliberately limited to a match previously opened on that device. Creating matches, activating scheduled matches, loading history, changing settings, and opening uncached matches still require connectivity.

### Current native gap

- the current iPhone scoring layout is much improved but still needs final polish
- the native notification bell does not have a live notification center behind it yet
- reporting, stats, game-settings presets, and deeper federation-style association integrations in native settings are not fully implemented
- offline history, offline match creation, and multi-match caching are not implemented; offline scoring is limited to one previously opened active match
- release pipeline, realtime sync, and final signoff coverage are still partial

## 16. Current Cross-Cutting Gaps

- public-route rate limiting and wider security audit coverage are incomplete
- WebSocket infrastructure is incomplete
- organisation game settings persistence is incomplete
- social profile persistence is incomplete
- backend pytest logic tests and Playwright public-route smoke tests now exist
  under `testing/automated/`; a lightweight native iOS UI test bundle also
  exists in `mobile/ios/RcktScoreMobile/RcktScoreMobileUITests`, including
  launch helpers that can force light or dark mode and reset local app state;
  these are early baselines and are not yet part of a documented CI pipeline

## Maintenance Rule

When request behavior, auth behavior, route ownership, or troubleshooting assumptions change:

- update this file
- update [backend-api.md](/Users/glennrowe/Development/Projects/RcktScore/docs/backend-api.md)
- update [troubleshooting.md](/Users/glennrowe/Development/Projects/RcktScore/docs/troubleshooting.md)
