# Technical Walkthrough

## Purpose

This document describes the current end-to-end request lifecycles in `RcktScore` v2.
It is written to help developers trace product behavior through the actual web app,
Lambda handlers, and shared backend logic.

The app entry document at `frontend/index.html` and the public landing homepage use the same browser title, `HitNScore | Every Point. Every Court.`, and the same public description metadata.

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

The end-to-end entry, email, activation, login and first-match paths are shown
in [new-user-onboarding-walkthrough.md](/Users/glennrowe/Development/Projects/RcktScore/docs/new-user-onboarding-walkthrough.md).

### Frontend entry

- [frontend/src/pages/LoginPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/LoginPage.jsx)

### Current path

1. A visitor opens the `Want In` form on the login page.
   - both the standard web login and registration states omit internal package-version/build details
   - the login logo and HitnScore wordmark return to `https://www.hitnscore.com/`
   - the native form introduces personal and multi-user club accounts and links to `https://www.hitnscore.com` for further product information
2. The frontend submits `first_name`, `surname`, `email`, and `use_type`.
3. The honeypot field is `company`.
4. [backend/functions/register_interest/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/register_interest/handler.py):
   - validates the payload
   - writes or updates `HitnScoreInterestRequests`
   - for Personal, records the self-service registration, commits the pending `personal_free` organisation, owner membership, personal court, and password token, then sends a password-setup email without entering an admin approval queue; completing that link validates the email and activates login
   - for Club, keeps the request pending and sends confirmation/admin enquiry emails
   - for a logged-in native Club Essentials or Club Pro enquiry, validates the bearer session, derives the requester email from it, and stores the club name, address/postcode, club email, website, telephone, and requested plan for root-admin review
5. Personal signup returns `201` with `data.account_created = true`; the user verifies their email and chooses a password before signing in.
6. Club enquiries return `202` with `data.account_created = false` and remain controlled by the root-admin workflow.
7. In the native iOS client, a successful response replaces the submitted form with a confirmation screen. Personal registration explains that the emailed link verifies the address and sets the password; club registration explains that the team will make contact.

### Troubleshooting cues

- missing interest-request table returns `INTEREST_REQUESTS_TABLE_MISSING`
- missing `PASSWORD_RESET_BASE_URL` returns `PERSONAL_SIGNUP_CONFIGURATION_ERROR`
- personal setup email issues return `PERSONAL_SIGNUP_EMAIL_FAILED`
- club enquiry email issues return `INTEREST_EMAIL_FAILED`

## 4. Password Reset Flow

### Frontend entry

- [frontend/src/pages/HelpPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/HelpPage.jsx)

The app `/help` route is also the public Help Centre and knowledge base. Its overview contains the web and iPhone registration/sign-in guides, password recovery, troubleshooting/contact routing, and legal links. Direct links use `?section=web-access`, `ios-access`, `terms`, `privacy`, or `cookies`; password reset retains the existing `?mode=reset` and token flow. The public landing footer points to this route and its privacy/cookie sections, so `weblanding/` does not carry a separate Help page. The Help Centre footer deliberately mirrors the current public-homepage footer. Its fixed header also follows the landing page by compacting after the user scrolls, while the brand logo and wordmark link back to `https://www.hitnscore.com/`.

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
- password reset, account setup, organisation invitation, club enquiry, and feedback messages share the centred HitnScore HTML renderer in `common/notification_templates.py` while retaining plain-text alternatives; `EMAIL_LOGO_URL` selects the public logo asset

The native login `Ping Us` form posts name, email, category, message, app version/build, page identifier, and user agent to `POST /feedback`. The feedback Lambda validates the request, sends it through SES with the submitter as the reply-to address, and returns `202` when SES accepts it. The native form is then replaced by a sent confirmation and close action. SES delivery failures are mapped to `503 FEEDBACK_DELIVERY_FAILED`; the configured sender and recipient must be verified or otherwise permitted in the deployed SES account.

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
   - returns a redacted fourth history teaser for Personal Free when older matches exist
   - derives Personal Plus performance statistics from completed match state and event actions
5. The API returns `data.dashboard`.
6. The page renders screen-mode-specific views for dashboard, matches, history, or Personal Plus performance. Personal Plus navigation combines current matches and history behind the Matches action.
7. `GET /get_score/{match_id}` rejects completed Personal Free matches outside the latest-three window, preventing direct URL access from bypassing the entitlement.

### Troubleshooting cues

- empty match lists can be valid if the `matches` tables are missing or empty
- Personal Free intentionally returns three readable history records plus an optional locked teaser; Personal Plus requests expanded history
- performance matches are attributed only when the registered first name and surname exactly match one recorded participant

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
   - `organization.timed_break_defaults`
4. The frontend renders:
   - organisation details
   - personal profile
   - user admin
   - court admin
   - map preview
   - persisted racket-sport visibility controls
   - persisted per-sport timer defaults under Game Settings
   - scaffold-only social profile fields

### Current limitation

Social-profile fields are still UI scaffolds and are not persisted/enforced. There is intentionally no organisation-level handicap setting: Squash/Racketball handicap scoring is available to Personal Free, Personal Plus, and club accounts.

## 7. Personal Profile Update Flow

### Frontend entry

- [frontend/src/pages/OrganisationSettingsPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/OrganisationSettingsPage.jsx)

### Current path

1. The signed-in personal user submits their profile form.
2. The frontend or iOS app calls `PUT /personal_profile/{organization_id}` with first name, surname, email, telephone, country, and optional city fields.
3. [backend/functions/update_personal_profile/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/update_personal_profile/handler.py) authorizes the presented org-user session for that organisation and uses the session username as the source of truth.
4. Shared logic updates the linked `SkwshOrgUsers` rows for that account. If the email changes, it also updates the login username and revokes active sessions so the user must sign in again.
5. The API returns updated `organizationSettings`.

## Tournament Manager Foundation Flow

1. Root admin opens an existing club and enables Web Tournament Manager.
2. `PUT /root_admin/organizations/{organization_id}/tournament-feature` validates
   the root-admin session and upserts `tournament_organization_features`.
3. Organisation settings return
   `organization.features.tournament_manager.web_enabled`.
4. The club Settings page shows the Tournament Manager tab only for an enabled
   club; the backend repeats the same check on every tournament request.
5. A club admin creates a draft through
   `POST /organizations/{organization_id}/tournaments`.
6. Adding an entry looks for a registered account with the supplied email, reuses
   the canonical `users` identity and an existing `players` identity when the
   email is already known, and
   otherwise creates an unclaimed or claimable player.
7. `player_organization_affiliations` records `member` when that account is an
   approved member of the host club and `guest` otherwise. Guest status grants no
   login or club permissions.
8. The tournament entry stores a name/club/country snapshot so later profile
   edits cannot rewrite the historic event entry.
9. Every tournament and entry creation writes `tournament_audit_events`.

The seeded Demo Club has the feature enabled. Its approved
`demouser@democlub.com` login is intentionally password-disabled until root admin
sets a password through the existing User Accounts control.

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

The React tennis setup mirrors the native lineup contract: singles or doubles,
four named doubles participants with individual shirt colours, Golden Point, an
optional final-set 10-point match tiebreak, and timed 90-second odd-game
changeovers plus 120-second set breaks. Before play begins, the web scorer asks
for a named opening server and receiver and submits the same participant IDs,
alternating serve order, and Deuce-court receiver map used by the native client.
These are client additions over the existing backend tennis event contract; no
new route is involved.

The same web flow now exposes enabled Padel accounts as doubles-only, omits the
tennis-only final-set match-tiebreak option, and uses the Padel adapter over the
shared tennis-style engine. At Golden Point the receiving team must choose its
Right- or Left-court partner before the deciding point is submitted.

Live tennis and Padel matches render through
`frontend/src/components/TennisScoreboard.jsx`, separately from the generic
squash/racketball `Scoreboard`. The component displays the backend engine's
tennis point labels, set games, sets won, tiebreak mode, named participant-level
server and receiver, Deuce/Ad court, completed sets, point timeline and final
result. It intentionally omits Stroke, Let and manual service-box controls.
`MatchScreen.jsx` retains shared loading, mutation, undo, match timer and network
plumbing and starts a 90-second break only after an odd completed game, or a
120-second break after a completed set, when `tennis_timed_breaks` is enabled.
Every web scoring mutation also sends a client-generated UUID through the
existing `client_action_id` contract so a retried browser request cannot apply
the same action twice.

### Frontend entry

- [frontend/src/pages/NewMatch.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/NewMatch.jsx)
- [frontend/src/context/MatchContext.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/context/MatchContext.jsx)
- [mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/StartNewMatchView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/StartNewMatchView.swift)

### Current path

1. The operator submits player, court, referee, sport, score type, best-of, optional handicap data, Golden Point, and the per-match timing choice. Both clients initialise timing from `organization.timed_break_defaults` for the selected sport, but the operator may override it before starting.
2. The frontend calls `POST /start_match`.
3. [backend/functions/create_match/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/create_match/handler.py) authorizes the org-user session.
4. [backend/common/match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/match_logic.py):
   - normalizes the requested sport
   - rejects sports outside the session membership's client-effective list, which intersects platform, organisation, and per-membership web/iOS access
   - dispatches match creation to the correct sport engine
   - allows live match creation today for squash, racketball, tennis, and doubles Padel
   - fails safely for sport engines that are wired but not yet implemented
   - blocks personal accounts from having more than one active match
   - can auto-schedule a club match if the chosen court already has an active match
   - writes a `matches` row
   - writes a `match_started` event
5. The API returns `data.match` and `data.broadcast`.
6. The frontend navigates to the match screen unless the match is left as scheduled.

For Personal Plus, web and iOS expose an explicit schedule option. A scheduled
match does not consume the personal account's one-active-match allowance, so it
can be prepared while another match is live. The dashboard/Matches view lists
it and calls `POST /start_scheduled_match` later. Activation is disabled in the
web UI and rejected server-side with `ACTIVE_MATCH_EXISTS` until the current
personal match has ended.

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
8. The web frontend updates local match state from the returned `data.match`. Native iOS caches the last server match, applies queued actions locally, and adopts each ordered server response during synchronisation. The queue re-reads its latest snapshot around every request so a timer or scoring action added during an in-flight request cannot be overwritten.

Current live sport engines:

- squash and racketball share [backend/common/squash_match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/squash_match_logic.py), including Golden Point and handicap offsets for Personal Free, Personal Plus, and club accounts without a plan entitlement gate
- tennis uses [backend/common/tennis_match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/tennis_match_logic.py)
- tennis supports normal advantage scoring or Golden Point scoring from the automatic 40-40/Right service side, regular seven-point tiebreaks at 6-6, an optional deciding-set replacement played as a 10-point match tiebreak, and optional timed breaks with no break after game 1, 90-second changeovers after later odd-numbered games, and 120 seconds between sets; all tiebreaks require a two-point margin
- padel uses [backend/common/padel_match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/padel_match_logic.py) as a doubles-only adapter over the same set-scoring engine, with four named participants, games to six, a seven-point tiebreak at 6-6, and optional Golden Point where the receiving team selects which partner receives before the deciding point
- table tennis, badminton, and pickleball engine files exist but are not live scoring paths yet

### Supported event actions

- `let`
- `stroke`
- `server`
- `serve_side`
- `match_settings`
- `timer`
- padel uses `receiver_choice` at Golden Point to select the receiving partner; tennis Golden Point does not require this action, and neither court-scoring sport accepts squash-only `let`, `stroke`, or `serve_side` actions

### Troubleshooting cues

- undo removes the last non-`match_started` event
- `stroke` is score-aware and can end a game or match
- shirt-colour changes are accepted for personal-free, personal-plus, and club accounts

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
- [frontend/src/pages/RootAdminUserAccountsPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/RootAdminUserAccountsPage.jsx)
- [frontend/src/pages/RootAdminUserProfilePage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/RootAdminUserProfilePage.jsx)

### Current path

1. The root-admin UI loads dashboard, club, club-enquiry, and unified user-account data from root-admin routes.
2. Every root-admin route validates the bearer token against `root_admin_sessions`.
3. Club-detail calls to shared organisation endpoints accept root access only after the same session validation succeeds.
4. The platform dashboard now also links to a root-admin match directory that calls `GET /root_admin/matches` and can archive or delete matches across the system.
5. Match archive is implemented as a flag on `matches`, so archived matches drop out of standard dashboard/history lists without deleting the underlying row.
6. The platform dashboard links to a root-admin `RacketSports` page that manages separate web and iOS availability lists. Its primary save changes only the platform gate and does not grant the sport to organisations or users. `POST /root_admin/platform_sports/preview` lists every user and membership that the separate optional bulk action would affect without writing data; that bulk action requires confirmation and signs out active users. User Account profiles assign either client independently, and personal-account assignments maintain their personal organisation umbrella automatically; club users remain capped by club settings.
7. `GET /root_admin/users` groups membership rows by username and supports Personal Free, Personal Plus, club, and unverified-user filters plus username/name search. It also reports email-verification state so pending users are counted in a top-level card and highlighted in the directory.
8. `GET /root_admin/users/{user_id}` returns registration details, email-verification state, last session activity, personal and club associations, per-client enabled sports, and attributable scoring activity. The Settings tab calls `PUT /root_admin/users/{user_id}/memberships/{membership_id}/sport-access` for independent web/iOS access. Updating access revokes the user's active sessions. Email verification, password replacement, subscription changes, club invitations, and association removal remain separate actions.
9. Personal registrations do not appear in `GET /root_admin/interest_requests`; that queue now contains club enquiries only.

### Remaining hardening

The root-admin trust boundary is now enforced. Rate limiting, richer security audit events, and operational session-management tooling remain launch-hardening work.

## 15. Native iOS Flow

### Current path

1. [ContentView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/ContentView.swift) routes the app to `LoginView` or `DashboardView` based on the persisted `SessionStore`, but clears the saved session and requires fresh credentials once `session_expires_at` is reached.
2. [LoginView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/LoginView.swift) calls `POST /login` with `client_type = mobile_app`, handles `ACTIVE_SESSION_EXISTS`, exposes a local show/hide password control, and branches between `data.session` and `data.organizationSelection`. Multi-membership users receive a native account picker. First-time sign-in requires connectivity, and the login card displays an offline explanation when no network is available.
3. [DashboardView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/DashboardView.swift) loads `GET /dashboard/{organization_id}`. Personal Free and Personal Plus both present `Home`, `Matches`, `Analytics`, `Settings`, and `Need Help`. Matches uses a Current / Scheduled / History selector; Personal Free retains three readable history records and an upgrade-gated Scheduled view, while Personal Plus can create and list scheduled personal matches. Analytics always includes scored-match Stats and adds Personal reporting for Personal Plus. The header bell becomes an offline indicator while disconnected. Online, it loads the persisted notification inbox and glows yellow while any message is unread. A cached active match can be reopened from the active-match section.
4. The native settings flow in `DashboardView.swift` now adapts its menu by plan and account type. About, Profile, and Subscription are the first three items, followed by association, racket-sport, game-settings, reporting where entitled, and help items. The former Stats settings placeholder has been removed because performance lives in the Personal Plus dashboard tab. Each row pushes to its own detail page. Club admins also call `GET /organization_settings/{organization_id}` and `PUT /organization_details/{organization_id}` to manage organisation details, users, courts, and the persisted `enabled_sports` racket-sport visibility list.
   From Subscription, non-current Club Essentials and Club Pro cards open an authenticated club-enquiry page. A successful submission is added to the root-admin Club Account Enquiries queue and triggers confirmation to the signed-in user plus notification to the configured `INTEREST_TO_EMAIL` recipient.
5. The native profile page edits first name, surname, email/username, telephone, and country through `PUT /personal_profile/{organization_id}`; the country field offers local country-name completion. Password reset and the equal-width delete control sit at the bottom. Personal-account owners can initiate permanent deletion through `DELETE /personal_account/{organization_id}` after two separate destructive confirmations. On success, the app clears its session and cached offline match. Profile photos remain local to the device and are not stored in a central shared profile service yet.
6. [SessionStore.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/State/SessionStore.swift) tracks session expiry and whether local biometric unlock is available and enabled. When the user opts in, the unexpired session is also stored in the device-bound iOS Keychain behind the current biometric enrolment. Face ID or Touch ID can unlock it at cold launch or restore it from the login screen after local sign-out, including offline. A successful authentication remains valid across brief interruptions and the app only relocks after five continuous minutes in the background; transient `.inactive` states such as system overlays and the biometric prompt do not relock it. Biometrics are not a second backend login method and an expired or server-rejected session is removed.
7. The native About page reads the installed app version and build directly from the iOS bundle metadata on device; it does not rely on a backend route.
8. The native association page now uses the locally persisted membership list from login to let multi-club users switch the active organisation without signing out. That switch refreshes dashboard and settings data against the selected membership.
9. [StartNewMatchView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/StartNewMatchView.swift) uses `GET /organization_settings/{organization_id}`, `GET /match_setup_lookup/{organization_id}`, and `POST /start_match` for the native match-setup flow. Its sport picker combines adaptive light/dark cards, brand-blue court linework, pink accents, and transparent photo-style ball assets for squash, racketball, tennis, and Padel; compact versions of those same assets appear in the Settings Racket Sports rows while retaining their existing layout and controls. Player headings update as first names are entered and shirt choice is a compact colour-dot menu. Tennis setup omits country and handedness, supports singles/doubles with one shirt colour per participant, best-of sets, Golden Point, an optional final-set 10-point match tiebreak, and timed breaks. Squash/racketball can opt into Golden Point at 10-all or 14-all, handicap scoring on Personal Free, Personal Plus, or club accounts, and timed 90-second game breaks; the warm-up uses two 120-second squash halves or two 150-second racketball halves. Padel uses the same court-scoring presentation but requires two named players on each team and defaults to best of three. Every sport's timing toggle is initially set from its saved Game Settings default. When timing is not selected, Squash/Racketball opens directly on live scoring while Tennis/Padel proceeds directly to the required opening serve/receive choice.
10. [MatchScoringView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/MatchScoringView.swift) owns common loading, timers, networking, and controls. Its squash/racketball presentation selects compact geometry from the available width as well as height, uses an adaptive vertical fallback for warm-up actions, keeps game history horizontally scrollable, and replaces the live board with a completed-match summary after the final point. [RacketPointRailReducer.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/State/RacketPointRailReducer.swift) reconciles the live serving marker with the latest point: when the server manually changes box without changing score, the existing marker is replaced (`R2` becomes `L2`) instead of duplicated. The saved `RacketServiceSideTimelineUITests` fixture starts this real screen offline at `R2`, verifies the visible replacement with `L2`, scores the next server point and verifies `R3`; `testing/automated/mobile/run-racket-service-side-ui-test.sh` runs it in an Apple Simulator and retains screenshots in the `.xcresult`. The separate opt-in `LiveRacketMatchJourneyUITests` signs into the real Personal Plus test account, creates Paul versus Mark as Best of 1 / PAR-11, checks the same side correction plus let and undo behavior, completes the match and signs out; it writes a real completed test match and therefore never runs as part of the credential-free baseline. Light shirt colours use dark foregrounds and a visible score inset, the running match timer is light green while its paused state remains slate, and the custom pink-accented action sheet names both players and keeps player selection within the same sheet. [TennisScoringPresentation.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/TennisScoringPresentation.swift) owns the tennis/padel scoreboard and an available-height scrolling score timeline with scores pulled towards the centre. Tennis Golden Point proceeds automatically from the 40-40/Right service side; padel instead presents the two receiving players by name and maps the selected partner to their established receiving court before allowing the deciding point. The visible timeline shows only point scores, labels a game-winning point as `Game` in mustard, and follows it immediately with a larger blue score-only divider. Backend and offline point events still record the actual server, receiver and Deuce/Ad court before the point as well as its score and game/set boundary for future statistics, rather than relying on the next-point serving state. When enabled, `TennisBreakRules` drives a 90-second interval after odd games from game 3 onward and a 120-second interval after a completed set. [OfflineMatchStore.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/State/OfflineMatchStore.swift) retains the ordered action queue, while [TennisScoringReducer.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/State/TennisScoringReducer.swift) mirrors backend tennis transitions offline. Reconnection replays UUID-tagged actions in order, preserves actions appended during an in-flight request, adopts each authoritative server response, and exposes the actual replay error while keeping failed actions queued.
11. [HistoricMatchView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/HistoricMatchView.swift) and [HistoricMatchPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/HistoricMatchPage.jsx) reload the same authenticated match payload and render a separate read-only experience for completed matches. Both show sport-specific game/set terminology, match start time, recorded total duration, durations derived from the first and last scoring event in each game/set, and grouped point history. Tennis and Padel retain tennis score labels and insert distinct game and set completion dividers. Web history cards navigate to `/match/{match_id}/history`; `/match/{match_id}` remains the live-scoring route.
12. [ClubPageHeader.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/components/ClubPageHeader.jsx) owns the signed-in web navigation for Home, new match, Matches, Analytics, Settings and Help. The header starts three pixels from the viewport top, stays sticky at the page-shell width and listens to vertical scroll position; after 48 pixels it reduces vertical padding, logo, wordmark and navigation controls and swaps text labels for the same SVG icon language used by the mobile navigation. The Home control is always icon-only, the new-match `+` is the only blue bordered navigation action, and Messages plus Logout remain right-aligned. Dashboard descriptions and account/club text are omitted, Start New Match remains a separate blue action immediately below the header, and `AppFooter` no longer renders version/build or duplicate help content.
13. Offline scope is deliberately limited to a match previously opened on that device. Creating matches, activating scheduled matches, loading history, changing settings, account deletion, and opening uncached matches still require connectivity.
14. Help & Feedback includes a native privacy/data page covering account, match, device, offline and biometric handling. [PrivacyInfo.xcprivacy](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/PrivacyInfo.xcprivacy) declares the app's required-reason UserDefaults access. App Store Connect privacy answers and the public policy URL must still be maintained for each release.
15. [StoreKitPurchaseService.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Services/StoreKitPurchaseService.swift) loads the authenticated purchase context and offers the yearly Personal Plus product for new purchases, displays Apple's localised price, passes `.appAccountToken`, observes updates, restores purchases, and supports Apple's manage-subscriptions sheet. Monthly transactions remain recognized for restore and server lifecycle handling so earlier purchases are not orphaned. For server-enabled purchasing it submits both the transaction JWS and signed `AppTransaction` JWS, finishes only after backend acceptance, and refreshes the server-authoritative dashboard plan. Debug local StoreKit tests remain non-authoritative while the deployment gate is off.

### Current native gap

- the current iPhone scoring layout is much improved but still needs final polish
- notification inbox delivery and read state are backend-backed; APNs push delivery is not implemented
- reporting, game-settings presets, and deeper federation-style association integrations in native settings are not fully implemented
- migrations `024`–`027`, the purchase-context/verification endpoints, the public Apple-signed V2 notification receiver and scheduled reconciliation now connect the stable account UUID through StoreKit and Apple's Server API to one entitlement processor. Scheduled processing prioritises elapsed rows for Apple verification before using a 15-minute local-expiry fallback, preventing delayed renewal delivery from causing transient entitlement and audit reversals
- renewal, auto-renew cancellation, billing retry/grace, expiry, refund and revocation update subscription state and change `personal_free`/`personal_plus` only according to verified access; root admin can inspect current state, notification attempts, reconciliation failures and the immutable entitlement history
- [apple-subscription-production.md](/Users/glennrowe/Development/Projects/RcktScore/docs/apple-subscription-production.md) is the launch checklist for completing that boundary, including endpoint trust, lifecycle state rules, reconciliation, admin activity and append-only entitlement audit
- offline history, offline match creation, and multi-match caching are not implemented; offline scoring is limited to one previously opened active match
- release pipeline, realtime sync, and final signoff coverage are still partial

## 16. Production Health and Alarm Flow

1. `GET /health` invokes [backend/functions/health/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/health/handler.py).
2. The handler opens a normal Supabase pooler connection and executes `SELECT 1`.
3. Success returns the shared envelope with HTTP 200. Failure returns a generic HTTP 503 without leaking the connection error.
4. EventBridge Scheduler invokes the handler every five minutes with the fixed `rcktscore.health-schedule` source.
5. A scheduled failure raises, incrementing the Lambda `Errors` metric and activating the health-check alarm.
6. API Gateway and Apple lifecycle Lambdas have separate error, latency and missed-reconciliation alarms. Alarm and recovery actions publish to the encrypted SNS topic created by the SAM stack.
7. The address configured by `AlarmNotificationEmail` must confirm AWS's initial SNS subscription email before messages are delivered.

## 17. Current Cross-Cutting Gaps

- public-route rate limiting and wider security audit coverage are incomplete
- WebSocket infrastructure is incomplete
- organisation game settings persistence is incomplete
- social profile persistence is incomplete
- backend pytest logic tests and Playwright public-route smoke tests now exist
  under `testing/automated/`; a lightweight native iOS UI test bundle also
  exists in `mobile/ios/RcktScoreMobile/RcktScoreMobileUITests`, including
  launch helpers that can force light or dark mode and reset local app state,
  plus a credential-free saved scoring regression that runs against local
  fixture state in an Apple Simulator and an opt-in credential-backed journey
  that creates a real completed test match; these are early baselines and are
  not yet part of a documented CI pipeline

## Maintenance Rule

When request behavior, auth behavior, route ownership, or troubleshooting assumptions change:

- update this file
- update [backend-api.md](/Users/glennrowe/Development/Projects/RcktScore/docs/backend-api.md)
- update [troubleshooting.md](/Users/glennrowe/Development/Projects/RcktScore/docs/troubleshooting.md)
