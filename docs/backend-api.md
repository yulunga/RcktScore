# Backend API Reference

## Purpose

This document describes the `RcktScore` v2 backend as it exists in code today.

Use this file for:

- route inventory
- backend module ownership
- auth/session behavior
- data shape expectations
- current security posture

For end-to-end request paths, see [technical-walkthrough.md](/Users/glennrowe/Development/Projects/RcktScore/docs/technical-walkthrough.md).
For failure-mode guidance, see [troubleshooting.md](/Users/glennrowe/Development/Projects/RcktScore/docs/troubleshooting.md).

## Runtime Architecture

Current runtime path:

1. The React web app calls [api.js](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/services/api.js), or the iOS app calls `APIClient.swift`.
2. API Gateway HTTP API receives the request.
3. API Gateway invokes a Lambda from [backend/template.yaml](/Users/glennrowe/Development/Projects/RcktScore/backend/template.yaml).
4. The handler parses input with [common/utils.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/utils.py).
5. Shared business logic runs in `backend/common/`.
6. Database work goes through [common/supabase_client.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/supabase_client.py).
7. The handler returns a shared response envelope.

## Current Backend Modules

### Shared utilities

- [common/utils.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/utils.py)
  - JSON envelope helpers
  - body parsing
  - path/query validation helpers
- [common/supabase_client.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/supabase_client.py)
  - Postgres connection helper
  - prepared statements disabled for Supabase pooler compatibility

### Auth and session

- [common/auth_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/auth_logic.py)
  - org-user membership lookup
  - password verification
  - root-admin credential verification
- [common/session_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/session_logic.py)
  - org-user session token creation
  - duplicate-session blocking by client type
  - tenant authorization helpers for org and match routes

### Organisation and root-admin

- [common/organization_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/organization_logic.py)
  - organisation settings read/update
  - personal-profile update
  - organisation user invite/create/approve
  - organisation user role updates
  - court CRUD
- [common/root_admin_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/root_admin_logic.py)
  - root-admin dashboard aggregation
  - club creation and lookup
  - root-admin user management
  - interest request and personal-account admin flows
  - root-admin match listing, archive, and delete flows
  - root-admin platform-wide racket-sport control

### Match and dashboard

- [common/dashboard_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/dashboard_logic.py)
  - active, scheduled, and completed match aggregation
  - plan-aware history limits
- [common/plan_entitlements.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/plan_entitlements.py)
  - authoritative Personal Free/Personal Plus history and performance contract
- [common/notification_center_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/notification_center_logic.py)
  - audience-targeted notification publishing, inbox listing, and cross-device read state
- [common/match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/match_logic.py)
  - stable match facade and sport dispatcher
  - enabled-sport enforcement before match creation
  - shared match entrypoints used by Lambda handlers
- [common/squash_match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/squash_match_logic.py)
  - squash and racketball scoring rules
  - event sourcing
  - undo
  - early/manual end
  - match serialization
- [common/tennis_match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/tennis_match_logic.py)
  - tennis point, game, set, and tie-break scoring rules
  - tennis match serialization
- [common/padel_match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/padel_match_logic.py)
- [common/table_tennis_match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/table_tennis_match_logic.py)
- [common/badminton_match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/badminton_match_logic.py)
- [common/pickleball_match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/pickleball_match_logic.py)
  - these sport-engine modules are wired into the dispatcher but currently fail safely until scoring rules are implemented
- [common/match_setup_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/match_setup_logic.py)
  - player/referee lookup for match setup
- `common/tournament/`
  - per-club Tournament Manager feature enforcement
  - draft tournament creation/listing
  - reusable product-wide registered or claimable player identities
  - member/guest player affiliations and tournament entries

Migration `030_tournament_foundation.sql` also introduces a canonical `users`
identity table keyed by normalized email and links existing/future
`SkwshOrgUsers` membership rows through `user_id`. Authentication remains on
`SkwshOrgUsers` during this compatibility phase; the new identity table does not
hold passwords or independently grant access.

### Email-related logic

- [common/password_reset_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/password_reset_logic.py)
- [common/mailer.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/mailer.py)
- [common/notification_templates.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/notification_templates.py)

## Authentication and Session Model

### Organisation users

Organisation-user auth is real and backend-enforced.

Current behavior:

- `POST /login` verifies credentials against `SkwshOrgUsers`
- users may belong to multiple organisations
- a successful login creates a session token in `org_user_sessions`
- organisation-user sessions expire after 30 days by default; `OrgUserSessionTtlDays` can configure a value from one to 90 days
- successful login and multi-membership selection payloads include `session_expires_at`
- session tokens are sent in `Authorization: Bearer <token>`
- most protected organisation and match routes validate that token server-side
- session invalidation codes currently include:
  - `SESSION_REQUIRED`
  - `SESSION_INVALID`
  - `SESSION_REPLACED`
  - `SESSION_EXPIRED`
  - `SESSION_FORBIDDEN`
  - `SESSION_ADMIN_REQUIRED`

Duplicate login behavior:

- sessions are tracked per client type
- current client types normalize to `web_app` or `mobile_app`
- if an active session already exists for the same username and client type, `POST /login` can return `ACTIVE_SESSION_EXISTS`
- the frontend may retry with `force_logout_other`
- `POST /login` can also return `data.organizationSelection` for users with
  multiple approved memberships, so clients must handle both `session` and
  selection payloads
- session and membership payloads include the client-effective `enabled_sports`
  list. It is derived from the platform client list, organisation list, and the
  membership's `enabled_sports_web` or `enabled_sports_ios` override.
- migration `019_offline_scoring_support.sql` adds `org_user_sessions.expires_at` and the reconnect-idempotency receipt table

### Root-admin users

Root-admin credential checking and backend session enforcement are implemented.

Current behavior:

- `POST /root_admin/login` verifies credentials against `SkRootAdmin`
- successful login returns a 384-bit opaque session token and expiry timestamp
- only the token hash is stored in `root_admin_sessions`
- root-admin sessions expire after eight hours by default, configurable from one to 24 hours with `RootAdminSessionTtlHours`
- a new login revokes prior active sessions for that root-admin account
- every root-admin route validates the bearer token server-side
- reused organisation-management routes validate either a qualifying org-user session or a valid root-admin session
- `POST /root_admin/logout` revokes the presented root-admin session
- the former `x-root-admin-request` bypass is no longer accepted

## Current Route Inventory

Routes are defined in [backend/template.yaml](/Users/glennrowe/Development/Projects/RcktScore/backend/template.yaml).

### Public and auth-adjacent routes

- `GET /health`
- `POST /login`
- `POST /logout`
- `POST /password_reset/request`
- `POST /password_reset/confirm`
- `GET /organization_users/approve`
- `POST /root_admin/login`
- `POST /root_admin/logout`
- `POST /register_interest`
- `POST /feedback`

The public web login and `Want In` presentations omit package-version/build details. This is a client-only display rule and does not change the `POST /login` or `POST /register_interest` contracts.

The public Help Centre and knowledge-base content at `/help`, including the direct `section` query values used by the landing footer, is also client-only. Consolidating the former landing Help page into the app does not add or change an API route; password reset and feedback continue to use the endpoints listed above.

The app shell and public landing homepage use the same browser title and description metadata. This is static client markup and has no backend API effect.

The Help Centre header compacts on scroll and its brand link returns to the public landing homepage. Both behaviours are client-only and add no API contract.

The signed-in web header, the Current/Scheduled/History Matches tabs, the dashboard's 25-record/five-card pagination, the History tab's 20-card pagination, collapsed shirt-colour pickers and iOS-style setup switches are client-only presentation changes. They reuse the existing dashboard, match-creation and organisation-settings contracts and require no backend migration or endpoint change.

The public login logo and wordmark also link to the public landing homepage. This is client-only navigation and does not change authentication APIs.

### Root-admin routes

- `GET /root_admin/dashboard`
- `GET /root_admin/platform_sports`
- `POST /root_admin/platform_sports/preview`
- `PUT /root_admin/platform_sports`
- `PUT /root_admin/users/{user_id}/memberships/{membership_id}/sport-access`
- `GET /root_admin/matches`
- `PUT /root_admin/matches/{match_id}/archive`
- `DELETE /root_admin/matches/{match_id}`
- `POST /root_admin/organizations`
- `GET /root_admin/organizations/search?q=...`
- `POST /root_admin/organization_users`
- `PUT /root_admin/organization_users/{user_id}`
- `PUT /root_admin/organization_users/{user_id}/approve`
- `GET /root_admin/interest_requests`
- `PUT /root_admin/interest_requests/{request_id}`
- `GET /root_admin/personal_accounts`
- `PUT /root_admin/personal_accounts/{request_id}`
- `GET /root_admin/users?account_type=...&q=...`
- `GET /root_admin/users/{user_id}`
- `POST /root_admin/users/{user_id}/memberships`
- `DELETE /root_admin/users/{user_id}/memberships/{membership_id}`
- `PUT /root_admin/users/{user_id}/password`
- `PUT /root_admin/users/{user_id}/verify-email`
- `PUT /root_admin/organizations/{organization_id}/tournament-feature`
- `GET /root_admin/notifications`
- `POST /root_admin/notifications`
- `GET /root_admin/subscriptions?organization_id=...`

Current root-admin user-account behavior:

- the user directory deduplicates organisation membership rows by case-insensitive username, reports `email_verified` and `unverified_membership_count`, and can filter Personal Free, Personal Plus, club, or unverified users (`account_type=unverified`)
- user profiles return registration/contact details, email-verification state, latest session activity, personal and club associations, activated sports, match totals by sport, and recent attributable matches
- manual email verification is root-admin-only and idempotent; it marks a matching personal registration as validated and approves pending memberships for that username without setting or changing the user's password
- club match activity is attributed using the recorded referee username; every match in a personal tenant is attributed to that tenant's owner
- adding a club membership creates a pending invitation, preserving the club approval workflow
- deleting a membership is limited to club associations; it does not delete the user's personal account
- changing a password hashes the replacement across every membership for that username, clears outstanding reset tokens, and revokes all active sessions for the user
- `PUT /root_admin/personal_accounts/{request_id}` remains the backing route for updating a personal organisation's `personal_plan` and `enabled_sports`
- `GET /root_admin/personal_accounts` remains available for compatibility, but the web admin console now uses the unified user directory

Current root-admin match-management behavior:

- `GET /root_admin/matches` supports optional `sport` and `organization_id` query filters
- archived matches are excluded from standard club/user match views and from the root-admin match directory by default
- `PUT /root_admin/matches/{match_id}/archive` hides a match without deleting the underlying row
- `DELETE /root_admin/matches/{match_id}` permanently removes the match row and cascades `match_events`

Current root-admin Tournament Manager behavior:

- Tournament Manager is web-only and disabled for clubs without an explicit enabled record
- `PUT /root_admin/organizations/{organization_id}/tournament-feature` accepts `web_enabled` and changes access without deleting tournament data
- the root-admin club page exposes this control in a dedicated Tournament tab immediately after Game Settings
- personal organisations cannot be enabled
- migration `031_tournament_demo_club.sql` creates an enabled Demo Club and an approved, password-disabled `demouser@democlub.com`; a root administrator must set its password before login
- migration `033_demo_club_players.sql` idempotently adds approved, password-disabled Demo Club user memberships for Demo PlayOne through Demo PlayEight; they use the standard `user` role and require an administrator-set password before login

### Tournament Manager routes

- `GET /organizations/{organization_id}/tournaments`
- `POST /organizations/{organization_id}/tournaments`
- `GET /organizations/{organization_id}/tournament-players?q=...`
- `GET /tournaments/{tournament_id}?organization_id=...`
- `POST /tournaments/{tournament_id}/entries`
- `PUT /tournaments/{tournament_id}/entries/{entry_id}`
- `POST /tournaments/{tournament_id}/draw`
- `PUT /tournaments/{tournament_id}/draw/matches/{match_id}`
- `POST /tournaments/{tournament_id}/draw/publish`
- `POST /tournaments/{tournament_id}/draw/draft`
- `GET /public/tournament-draws/{access_key}` (no login)

All authenticated tournament routes require an approved membership of the owning
club and an enabled `tournament_organization_features.web_enabled` record. The
public-key route is the deliberate read-only exception and returns no email or
account identifiers. Listing and
reading tournaments are available to ordinary club members. Creating tournaments,
searching/changing entries and generating draws remain club-admin operations.
Draft events persist
an `internal` or `open` audience, optional A–D grading and an optional entry-size
limit. Internal events reject guest entries and size-limited events reject entries
after capacity is reached. Entrants store a four-level ability assessment, mapped
from level 1/A through level 4/D. Graded creation adds four `tournament_draws`
groups (A–D); ungraded creation adds one Open Draw. The search endpoint searches
canonical registered
accounts and reusable player identities before the organiser uses manual entry;
exact and prefix matches rank first and the web client displays at most four candidates.

`POST /tournaments/{tournament_id}/draw` persists a reviewable draft in
`tournament_matches`; it does not publish or lock the entrant list. Round robin
uses the circle method and produces every round. Knockout, knockout-with-plate and
Monrad currently produce the opening round; non-power-of-two knockout fields give
top seeds byes and distribute seeds into separated bracket positions. Organisers
can swap first-round players through the match endpoint, then explicitly publish.
Publishing locks entries and issues a 12-character public read-only key. Returning
to draft requires an explicit client confirmation, disables public access, and is
rejected after a fixture has started or completed. Plate population, later
knockout/Monrad progression, scheduling and scoring-match linkage remain unimplemented.
The web client labels a generated draft **Draw ready** and a published draw
**Live**; these are presentation labels over the existing draft and
`draw_published` API states.
Migrations `034_tournament_draw_matches.sql` and
`035_tournament_draw_publication.sql` are required.
Generation is idempotent after publication when fixtures exist. If an event is
already `draw_published` but has no fixture rows, the same endpoint rebuilds them
and records a `draw_rebuilt` audit event.

Tournament entry updates are club-admin-only and limited to draft/registration
events. First name, surname, ability and unique positive seed are editable. Email and home-club fields
are editable only while the reusable player is not linked to a canonical
HitNScore account; linked identities retain their account-owned email and club
data. CSV import is orchestrated by the web client over the create/update routes:
it validates required names, detects duplicates in the file, current event and
shared player directory, then requires the organiser to skip, reuse or update a
matching record.

`GET /tournaments/{tournament_id}` checks whether both `tournament_draws` and
`tournament_matches` exist before reading them. It derives temporary A–D/Open
group labels when a backend deployment briefly precedes migration `032`, and
returns draw groups without fixtures if migration `034` is pending. Event creation
and draw generation/publication still require their respective migrations.

Current root-admin platform-sport behavior:

- `GET /root_admin/platform_sports` returns the umbrella list plus separate `enabled_sports_web` and `enabled_sports_ios` lists
- `POST /root_admin/platform_sports/preview` accepts the proposed web and iOS lists and returns the users and memberships that an optional bulk apply would affect, without changing data
- `PUT /root_admin/platform_sports` saves the separate web and iOS platform-availability lists without changing organisation or membership access by default; send `apply_to_all: true` only for the explicit bulk action that updates every organisation and membership and revokes active user sessions
- for a personal membership, a User Account sport-access update also maintains that personal organisation's umbrella sport list; club memberships remain capped by the club's own enabled-sports settings
- `PUT /root_admin/users/{user_id}/memberships/{membership_id}/sport-access` sets that membership's web and iOS lists; values remain capped by platform and organisation access and the user's active sessions are revoked
- organisation-level and personal-account-level enabled-sport updates are now constrained to the currently allowed platform list

Current root-admin club-user behavior:

- `POST /root_admin/organization_users` creates a pending organisation membership and emails an approval link
- `PUT /root_admin/organization_users/{user_id}/approve` lets root admin manually approve a pending organisation user without waiting for the email link flow
- `GET /root_admin/interest_requests` now returns club enquiries only; personal registrations never enter the admin approval queue

### Organisation and dashboard routes

- `GET /dashboard/{organization_id}`
- `GET /notifications/{organization_id}`
- `POST /notifications/{notification_id}/read`
- `GET /organization_settings/{organization_id}`
- `GET /match_setup_lookup/{organization_id}?q=...`
- `PUT /organization_details/{organization_id}`
- `PUT /personal_profile/{organization_id}`
- `DELETE /personal_account/{organization_id}`
- `POST /organization_users`
- `PUT /organization_users/{user_id}`
- `DELETE /organization_users/{user_id}`
- `POST /organization_courts`
- `PUT /organization_courts/{court_id}`
- `DELETE /organization_courts/{court_id}`
- `POST /organization_courts/{court_id}/display-code`

Current organisation-settings behavior:

- `GET /organization_settings/{organization_id}` includes `organization.enabled_sports`
- `PUT /organization_details/{organization_id}` can persist `enabled_sports` alongside the existing organisation detail fields
- both the web organisation settings page and the native iOS club-admin settings screen use that same organisation-details update route for racket-sport visibility changes
- the native iOS settings profile page uses `PUT /personal_profile/{organization_id}` for first name, surname, email/username, telephone, and country updates, and still uses `POST /password_reset/request` for password-reset emails
- personal-account owners can call `DELETE /personal_account/{organization_id}` with the exact confirmation value `DELETE MY ACCOUNT`; the route requires a valid session for that organisation and independently verifies that the session username owns a personal tenant
- the native iOS `About` settings page reads the installed app version/build from the app bundle locally and does not call a backend route
- the native iOS login screen now exposes a local show/hide password toggle, but it still submits the same `POST /login` request payload as before
- the native iOS Face ID / Touch ID setting stores the existing unexpired session in the device-bound iOS Keychain and can restore it after local sign-out; it does not add a backend route or create a second server-side login method
- native iOS and the React web client can include optional tennis-style team-format and lineup metadata, per-participant `team{1|2}_player{1|2}_shirt_color` values, `tennis_no_ad_scoring`, `tennis_final_set_match_tiebreak`, and `tennis_timed_breaks`; Padel is forced to doubles and does not expose the tennis-only final-set match-tiebreak choice. Squash/racketball also use the two compatible boolean fields for Golden Point and timed game breaks. The flags are stored on the match and in the match-start event, while the `server` event path accepts opening serve/receive order metadata. Both clients establish the named opening server, opening receiver, alternating doubles `serve_order`, and each team's Deuce-court receiver through that existing event contract. At Padel Golden Point, the web client also sends `receiver_choice` with `Right` or `Left` before allowing the deciding point.
- the React route `/match/{match_id}/history` is a dedicated read-only completed-match presentation over the existing authenticated `GET /get_score/{match_id}` payload. It uses stored match/event timestamps and `match_duration_seconds`; it does not introduce a separate historic-match backend route or schema
- `GET /organization_settings/{organization_id}` returns `organization.timed_break_defaults`, and `PUT /organization_details/{organization_id}` accepts that four-key boolean map for `squash`, `racketball`, `tennis`, and `padel`. It is a setup default only: each match still persists its own `tennis_timed_breaks` choice. Migration `029_timed_break_defaults.sql` adds the JSONB setting with all sports off for existing organisations.
- Personal Free, Personal Plus, and club Squash/Racketball matches may persist `handicap_enabled`, bands, and starting offsets. Handicap scoring is not plan-gated and has no organisation-level entitlement switch. Fresh-match detection compares the live score with those offsets so a selected warm-up still starts correctly for handicap matches
- Personal Plus may create any implemented sport with `status: scheduled`, even while its single permitted active match is still running. Personal Free creation remains active-only. `POST /start_scheduled_match` returns `409 ACTIVE_MATCH_EXISTS` if a personal account tries to activate a scheduled match before ending its current active match
- Personal Plus may create and list scheduled personal matches; Personal Free remains server-restricted to immediate active matches even if a client submits `status: scheduled`.
- at a tennis Golden Point 40-40 score, the next point is accepted immediately and is played from the normal 40-40/Right service side; padel instead requires `POST /event_action` with `action_type: receiver_choice` before the point, using `side: Right` or `side: Left` to identify the selected receiving partner's court

### Match and scoring routes

- `POST /start_match`
- `POST /start_scheduled_match`
- `GET /get_score/{match_id}`
- `GET /match_display_access/{match_id}`
- `POST /score_point`
- `POST /event_action`
- `POST /undo_action`
- `POST /end_match`

### Display and WebSocket helper routes

- `POST /scoreboard_display/session`
- `GET /scoreboard_display/current`
- `backend/functions/websocket_broadcast/handler.py` exists
- the function is part of the backend codebase
- subscriber registration and routing are not fully deployed or persisted yet

## Route Behavior Notes

### Login

[functions/login/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/login/handler.py)

- returns `data.session` when there is exactly one approved membership
- returns `data.organizationSelection` when the same email belongs to multiple approved organisations
- returns `PENDING_APPROVAL` when credentials are valid but access is still pending invitation approval
- successful session payloads include the effective `enabled_sports` for the login client (`web_app` or `mobile_app`)
- successful session payloads include `session_expires_at`; clients must require a fresh login after that timestamp
- session and membership payloads now also include `country` and `telephone` when those profile fields are populated

### Logout

[functions/logout/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/logout/handler.py)

- revokes the presented org-user session token

### Password reset

- request: [functions/password_reset_request/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/password_reset_request/handler.py)
- confirm: [functions/password_reset_confirm/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/password_reset_confirm/handler.py)

Current behavior:

- request path accepts `email`
- reset link base URL comes from `PASSWORD_RESET_BASE_URL`, then falls back to the request `Origin`
- successful request always returns `202 accepted`

### Organisation membership approval

[functions/approve_org_user/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/approve_org_user/handler.py)

- email invitations create approval tokens
- the approval route returns HTML, not JSON
- the approval page can now auto-redirect to a configured sign-in URL after three seconds when `USER_APPROVAL_LOGIN_URL` is set
- invitation links can already be branded away from the raw API Gateway hostname by setting `USER_APPROVAL_BASE_URL`
- results include:
  - invalid token
  - already approved
  - approved

### Dashboard

[functions/get_dashboard/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/get_dashboard/handler.py)

- requires a valid org-user session for the organisation
- accepts optional query params:
  - `active_limit`
  - `recent_limit`
- returns:
  - `organization`
  - `active_matches`
  - `scheduled_matches`
  - `recent_matches`
  - `performance` for Personal Plus accounts
- `organization.completed_match_count` and `organization.locked_history_count` describe retained and entitlement-locked history
- `organization.entitlements` is the client-facing copy of the same server contract used to cap queries
- `organization.available_plan_entitlements` exposes both Personal plans so upgrade copy does not duplicate limit constants in clients
- Personal Free responses contain the latest three completed matches and a redacted fourth preview when more history exists
- Personal Plus responses contain at most the latest 100 completed matches and include performance data
- `GET /get_score/{match_id}` enforces the current personal plan's completed-history window, so a previously known match ID cannot bypass either the Free three-match or Plus 100-match boundary
- Personal Plus performance is computed from retained match state and event actions, including results, games/points, serve points, playing time, close games/sets, streaks, scorelines, opponents, sport splits, and weekly/monthly summaries

### Notifications

- `POST /root_admin/notifications` accepts `title`, `message`, and `audience`; supported audiences are `all`, `personal_free`, `personal_plus`, `club_essentials`, and `club_pro`
- `GET /notifications/{organization_id}` returns notifications addressed to either `all` or the authenticated membership's current plan
- `POST /notifications/{notification_id}/read` records the authenticated username's read state in Postgres, so the state follows that account across web, iPhone, and iPad
- migration `023_system_notifications.sql` creates the inbox/read tables and seeds the welcome message
- delivery is currently pull/inbox based; APNs push delivery is not yet implemented

### App Store subscription boundary

- iOS offers new Personal Plus purchases through `com.hitnscore.personalplus.yearly` only. The backend and transaction observer continue to recognize `com.hitnscore.personalplus.monthly` for restore, renewal, cancellation and expiry safety
- the native subscription screen refreshes StoreKit current entitlements when it opens, when the app returns active, after transaction updates, and after closing subscription management, but the current account tier is derived from the latest backend dashboard/settings `organization.plan`; a local StoreKit transaction is not allowed to override that server tier
- `GET /subscriptions/apple/context/{organization_id}` now requires an organisation-user bearer session, verifies that the caller is the personal-account owner, and returns that account's stable server-issued `appAccountToken`, configured monthly/yearly product IDs, current plan, and purchase-enabled flag
- `POST /subscriptions/apple/verify` requires a valid organisation-user session plus `organization_id`, `signed_transaction`, and `signed_app_transaction`; it verifies both JWS values with Apple's server library and packaged Apple PKI roots, then validates ownership, account token, bundle, numeric app ID in Production, product, environment, expiry, upgrade and revocation state
- an accepted transaction is inserted idempotently into `app_store_transactions` and upserted into `app_store_subscriptions`; the plan update and append-only entitlement audit occur in the same database transaction
- migrations `025_apple_subscription_account_identity.sql`, `026_apple_purchase_verification.sql`, and `027_apple_subscription_lifecycle_processing.sql` provide stable identity, the verified transaction ledger, lifecycle/event state, retry/reconciliation metadata and an enforced append-only entitlement audit
- `POST /subscriptions/apple/notifications` is the unauthenticated-by-session App Store Server Notifications V2 receiver. It authenticates Apple by verifying the outer `signedPayload` and nested JWS values, deduplicates `notificationUUID`, rejects out-of-order state, and applies renewals, auto-renew changes, billing retry/grace, expiry, refund and revocation through the common lifecycle processor
- an hourly EventBridge Scheduler invokes reconciliation. Elapsed active/grace/retry rows are prioritised and checked with Apple `Get All Subscription Statuses` before local expiry is applied, using an In-App Purchase key held in AWS Secrets Manager. A 15-minute delivery/reconciliation window prevents delayed renewal notifications from producing temporary Plus-to-Free-to-Plus changes; unresolved elapsed access is then removed by the bounded fallback and failures retain retry state
- `GET /root_admin/subscriptions` requires a root-admin bearer session and returns current Apple subscription state, processing/reconciliation errors, V2 event activity and entitlement audit history
- StoreKit now uses the returned account token and finishes a server-enabled purchase only after backend acceptance; local Xcode StoreKit tests remain non-authoritative while `APPLE_PURCHASES_ENABLED=false`
- production activation remains outstanding until migration/configuration deployment and Sandbox/Production lifecycle evidence pass the release checklist
- the complete production architecture, lifecycle mapping, configuration gates and test checklist are maintained in [apple-subscription-production.md](/Users/glennrowe/Development/Projects/RcktScore/docs/apple-subscription-production.md)

### Organisation settings

[functions/get_organization_settings/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/get_organization_settings/handler.py)

- org-user sessions are authorized server-side
- valid root-admin sessions may access this route, but the bearer token is checked against `root_admin_sessions` before data is returned
- response includes:
  - `organization`
  - `users`
  - `courts`
  - `organization.enabled_sports`

### Personal profile

[functions/update_personal_profile/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/update_personal_profile/handler.py)

Current personal-profile behavior:

- authorizes the presented org-user session against the requested organisation
- updates the signed-in user rather than trusting a username supplied by the client
- accepts `first_name`, `surname`, `email`, `telephone`, `country`, and `city_location`
- changing `email` updates the login username across all memberships linked to that account, updates personal-tenant ownership where applicable, and revokes existing sessions so the user must sign in again

### Personal-account deletion

[functions/delete_personal_account/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/delete_personal_account/handler.py)

Current deletion behavior:

- requires a valid org-user bearer session for the requested organisation
- requires the JSON body `{ "confirmation": "DELETE MY ACCOUNT" }`
- permits deletion only when the authenticated username is the owner of a tenant whose `org_type` is `personal`
- permanently removes the personal tenant's matches, scoring events/action receipts through cascade, court display sessions, courts, memberships, organisation settings, associated personal signup record, and all active sessions for that username
- returns `403 ACCOUNT_DELETION_FORBIDDEN` for a valid member who is not the personal-account owner

- only the signed-in user can update their own personal profile
- requires `username` in the payload
- currently updates:
  - `first_name`
  - `surname`
  - `country`
  - `city_location`

### Organisation users

- create: [functions/create_org_user/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/create_org_user/handler.py)
- update user: [functions/update_org_user/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/update_org_user/handler.py)
- delete: [functions/delete_org_user/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/delete_org_user/handler.py)

Current behavior:

- roles are currently limited to `admin` and `user`
- create path is invite-oriented
- create path accepts optional `first_name` and `surname`
- update path can change `username`, `first_name`, `surname`, and `role`
- update path can change `password` only when the user email is not shared with another organisation membership
- new or existing email addresses may be attached to multiple organisations
- membership remains `pending` until the emailed approval link is accepted
- organisation settings responses include org-user `first_name` and `surname` values when present
- delete path removes the user from the current organisation only
- the backend prevents deleting or demoting the last remaining admin in an organisation

### Courts

- create: [functions/create_court/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/create_court/handler.py)
- update: [functions/update_court/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/update_court/handler.py)
- delete: [functions/delete_court/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/delete_court/handler.py)

Current behavior:

- org-user admin access is enforced for normal club operations
- root-admin club requests use the root-admin bearer token and are validated server-side

### Match setup lookup

[functions/search_match_setup_lookup/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/search_match_setup_lookup/handler.py)

- searches prior match player names and current org-user usernames
- returns:
  - `lookups.players`
  - `lookups.referees`
- empty query returns empty lookup arrays

### Match creation and scoring

- create: [functions/create_match/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/create_match/handler.py)
- start scheduled: [functions/start_scheduled_match/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/start_scheduled_match/handler.py)
- load match: [functions/get_match/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/get_match/handler.py)
- score point: [functions/score_point/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/score_point/handler.py)
- event action: [functions/event_action/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/event_action/handler.py)
- undo: [functions/undo_action/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/undo_action/handler.py)
- end: [functions/end_match/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/end_match/handler.py)

Current behavior:

- these routes are backend-authorized against the match tenant through `authorize_match_session(...)`
- `POST /score_point`, `POST /event_action`, `POST /undo_action`, and `POST /end_match` accept an optional `client_action_id` UUID
- when a `client_action_id` is supplied, the backend records it in `match_action_receipts`; replaying the same UUID for the same match action returns current match state without applying the action again
- reuse of a UUID for a different match or action is rejected with `INVALID_INPUT`
- native iOS serialises queued scoring requests, preserves any new action appended while a previous request is in flight, and retains failed actions for a safe retry with the same UUID; the client now surfaces the returned API or network error rather than describing every failure as an offline condition
- the native scorer labels stroke choices as `Stroke Against <player>` but continues to send the opposite player as the awarded `player_side`; let choices include the selected player's name and retain the existing optional `player_side` request behavior
- personal accounts can only have one active match at a time
- clubs can auto-schedule a match if the chosen court already has an active match
- live sport engines today:
  - squash
  - racketball
  - tennis
  - padel, as a doubles-only adapter over the tennis-style set engine
- additional engine files for `table_tennis`, `badminton`, and `pickleball` are wired but currently raise a safe unsupported-sport error
- supported score types by live engine:
  - squash/racketball: `11`, `15`
  - tennis: new native matches use `6`; `4` remains readable for historical short-set matches
  - padel: `6`, with a seven-point tiebreak at 6-6
- supported best-of values:
  - `1`
  - `3`
  - `5`
- squash/racketball action types: `let`, `match_settings`, `stroke`, `server`, `serve_side`, `timer`
- squash/racketball scoring preserves the previous server while calculating the next service box: the same server alternates boxes, while a service transfer selects the receiving player's handedness-derived default. Legacy compact point events are replayed with the same rule.
- tennis/padel action types: `match_settings`, `receiver_choice`, `server`, `timer`
- new tennis point events preserve point-time fields separately from the next-point state: `point_server_side`, `point_server_participant_id`, `point_receiver_side`, `point_receiver_participant_id`, `point_service_side`, point score/labels, `tennis_game_completed`, `set_completed`, and completed-game number/score. `game_completed` now marks every completed tennis game rather than only a completed set
- migration `021_tennis_scoring_formats.sql` adds the two persisted tennis format flags

### Interest requests and feedback

- register interest: [functions/register_interest/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/register_interest/handler.py)
- feedback: [functions/send_feedback/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/send_feedback/handler.py)

Current behavior:

- register-interest writes to `HitnScoreInterestRequests`
- `use_type = personal` records the request as `registered`, creates or refreshes a hidden `personal_free` organisation, owner membership, and personal court, then emails a time-limited password-setup link
- personal signup returns `201` with `account_created = true` and does not require root-admin approval
- the pending personal organisation/user and password token are committed before SES delivery; completing the emailed password link marks the membership approved and the interest record email-validated, while a delivery failure leaves the pending record available for retry
- `use_type = club` remains a controlled enquiry, sends club confirmation/admin emails, and returns `202` with `account_created = false`
- logged-in native subscription enquiries also send `requested_plan`, club address/postcode, club email, website, and telephone; these enriched requests require a valid organisation-user bearer session and the backend derives the requester email from that session
- migration `022_club_subscription_enquiries.sql` adds the extended club fields and separates personal-registration uniqueness from club-enquiry uniqueness so a club enquiry cannot overwrite the requester’s personal registration record
- migration `020_personal_registration_status.sql` converts historical personal-interest rows from approval terminology to `registered`; club rows retain pending/approved/denied states
- personal signup requires `PASSWORD_RESET_BASE_URL` to be configured; the request origin is not used as a fallback
- honeypot field is `company`
- SES delivery must be configured correctly
- all application-generated messages use a shared responsive HitnScore HTML presentation with a plain-text alternative; `EMAIL_LOGO_URL` controls the public HTTPS logo used in the HTML and defaults to the landing-site mascot asset
- outbound SES messages use the friendly sender name `HitnScore` when the configured source is a bare email address; mailbox avatars remain controlled by the receiving provider and domain-level BIMI/profile configuration rather than the HTML body
- feedback sends email but does not persist to a database table
- feedback defaults to the verified `hello@hitnscore.com` sender and recipient; SES delivery failures return `503 FEEDBACK_DELIVERY_FAILED` in the normal API envelope instead of an unstructured Lambda error
- after successful personal/club registration or feedback responses, the native iOS client replaces the relevant form with a confirmation and next-step screen; API errors leave the form available for correction or retry

### Production health

- `GET /health` is public and performs a lightweight `SELECT 1` through the configured Supabase transaction pooler.
- a healthy response returns `200` with `data.status = "healthy"` and `data.checks.database = "healthy"`.
- an unavailable database returns a generic `503 SERVICE_UNAVAILABLE`; connection details are logged server-side and are never returned to callers.
- EventBridge Scheduler invokes the same Lambda every five minutes. Scheduled failures raise so CloudWatch records a Lambda `Errors` metric.
- CloudWatch alarms cover API 5xx responses, sustained p95 latency, health-check errors/throttles, Apple notification/verification/reconciliation errors, and a missing hourly reconciliation invocation. Alarm and recovery actions publish to the stack's encrypted SNS production-alarm topic.

## Response Contract

The backend uses one shared JSON envelope.

### Success envelope

```json
{
  "success": true,
  "data": {},
  "error": null,
  "meta": {}
}
```

### Error envelope

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

### Common status codes

- `200` successful read/update
- `201` successful create
- `202` accepted async-style request such as interest registration or password reset
- `400` validation/input error
- `401` auth/session failure
- `403` permission failure
- `404` resource not found
- `409` duplicate active session
- `500` backend failure

## Current Data Model Summary

### Core tables

- `SkwshOrgSettings`
- `SkwshOrgUsers`
- `SkwshCourts`
- `SkRootAdmin`
- `org_user_sessions`
- `root_admin_sessions`
- `matches`
- `match_events`
- `HitnScoreInterestRequests`

### Match model notes

Schema bootstrap begins in [backend/schema/001_match_storage.sql](/Users/glennrowe/Development/Projects/RcktScore/backend/schema/001_match_storage.sql).

Important current `matches` concepts:

- tenant and court identity
- player names, surnames, countries, handedness
- player shirt colours, available to personal-free, personal-plus, and club accounts
- handicap flags and offsets
- active/scheduled/completed status
- game counts and final winner summary

Important current `match_events` concepts:

- every scoring and operator action is event-based
- live state is rebuilt from the event stream
- undo removes the last non-`match_started` event and rebuilds state

## Current Security Position

What is protected today:

- org-user login is real
- org-user session tokens are real
- dashboard, settings, personal-profile, lookup, and scoring routes enforce org-user session authorization
- match routes are tenant-aware through backend authorization
- root-admin routes and reused organisation-management routes enforce expiring root-admin sessions
- the public health response exposes only a generic readiness result and never returns database identifiers, credentials, or exception messages

What is not fully protected today:

- public authentication and form routes still need production rate limiting and broader audit controls
- WebSocket infrastructure is not complete enough to describe as production-ready live transport

## Current Known Gaps

- backend pytest logic tests, Playwright public-route smoke tests, and a
  lightweight native iOS UI test bundle are checked in. The native bundle now
  includes a deterministic, credential-free Simulator regression for the
  squash/racketball `R2` to `L2` to `R3` point-rail flow; it uses local fixture
  state and deliberately makes no backend request. A separate opt-in live
  journey uses the Personal Plus test credentials to create and complete a
  real Paul-versus-Mark match through the API, then logs out; it is excluded
  from credential-free baseline runs because it writes test data. All three
  suites remain early baselines and are not wired into a documented CI pipeline
- social profile settings are UI-only scaffolds right now
- per-sport timer defaults are persisted
- WebSocket subscription persistence is not implemented
- local frontend builds may fail if the checked-in `frontend/dist/` directory cannot be cleaned

## Maintenance Rule

When routes, auth behavior, security assumptions, or troubleshooting paths change:

- update this file
- update [technical-walkthrough.md](/Users/glennrowe/Development/Projects/RcktScore/docs/technical-walkthrough.md)
- update [troubleshooting.md](/Users/glennrowe/Development/Projects/RcktScore/docs/troubleshooting.md)
