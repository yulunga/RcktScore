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
- session tokens are sent in `Authorization: Bearer <token>`
- most protected organisation and match routes validate that token server-side
- session invalidation codes currently include:
  - `SESSION_REQUIRED`
  - `SESSION_INVALID`
  - `SESSION_REPLACED`
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
- session and membership payloads now include `enabled_sports`, which is the
  racket-sport visibility list for that organisation membership

### Root-admin users

Root-admin credential checking is real, but backend session enforcement is not complete.

Current behavior:

- `POST /root_admin/login` verifies credentials against `SkRootAdmin`
- the frontend stores the returned identity in `sessionStorage`
- there is no backend-wide root-admin session token model equivalent to `org_user_sessions`
- some root-admin routes are currently callable without server-side auth checks
- some organisation admin routes allow a root-admin bypass by trusting `x-root-admin-request: true`

Do not describe the current root-admin surface as production-grade authenticated administration.

## Current Route Inventory

Routes are defined in [backend/template.yaml](/Users/glennrowe/Development/Projects/RcktScore/backend/template.yaml).

### Public and auth-adjacent routes

- `POST /login`
- `POST /logout`
- `POST /password_reset/request`
- `POST /password_reset/confirm`
- `GET /organization_users/approve`
- `POST /root_admin/login`
- `POST /register_interest`
- `POST /feedback`

### Root-admin routes

- `GET /root_admin/dashboard`
- `GET /root_admin/platform_sports`
- `PUT /root_admin/platform_sports`
- `GET /root_admin/matches`
- `PUT /root_admin/matches/{match_id}/archive`
- `DELETE /root_admin/matches/{match_id}`
- `POST /root_admin/organizations`
- `GET /root_admin/organizations/search?q=...`
- `POST /root_admin/organization_users`
- `PUT /root_admin/organization_users/{user_id}`
- `GET /root_admin/interest_requests`
- `PUT /root_admin/interest_requests/{request_id}`
- `GET /root_admin/personal_accounts`
- `PUT /root_admin/personal_accounts/{request_id}`

Current root-admin personal-account behavior:

- `PUT /root_admin/personal_accounts/{request_id}` can now update `personal_plan`, `enabled_sports`, or both for a personal account organisation

Current root-admin match-management behavior:

- `GET /root_admin/matches` supports optional `sport` and `organization_id` query filters
- archived matches are excluded from standard club/user match views and from the root-admin match directory by default
- `PUT /root_admin/matches/{match_id}/archive` hides a match without deleting the underlying row
- `DELETE /root_admin/matches/{match_id}` permanently removes the match row and cascades `match_events`

Current root-admin platform-sport behavior:

- `GET /root_admin/platform_sports` returns the current globally allowed racket-sport list
- `PUT /root_admin/platform_sports` updates the platform default and applies the same enabled sport list across all existing clubs and personal accounts
- organisation-level and personal-account-level enabled-sport updates are now constrained to the currently allowed platform list

### Organisation and dashboard routes

- `GET /dashboard/{organization_id}`
- `GET /organization_settings/{organization_id}`
- `GET /match_setup_lookup/{organization_id}?q=...`
- `PUT /organization_details/{organization_id}`
- `PUT /personal_profile/{organization_id}`
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
- the native iOS `About` settings page reads the installed app version/build from the app bundle locally and does not call a backend route
- the native iOS login screen now exposes a local show/hide password toggle, but it still submits the same `POST /login` request payload as before
- the native iOS Face ID / Touch ID setting is device-local session unlock only; it does not add a backend route or store a second server-side login method
- native tennis match creation can now include optional team-format and lineup metadata for doubles, and the tennis `server` event path accepts opening serve/receive order metadata in the event payload

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
- successful session payloads include `enabled_sports`
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

### Organisation settings

[functions/get_organization_settings/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/get_organization_settings/handler.py)

- org-user sessions are authorized server-side
- root-admin requests currently bypass org-user checks when `x-root-admin-request` is set
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
- changing `email` updates the login username across all memberships linked to that account and revokes existing sessions so the user must sign in again

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
- root-admin club page uses the header-based bypass path

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
- personal accounts can only have one active match at a time
- clubs can auto-schedule a match if the chosen court already has an active match
- live sport engines today:
  - squash
  - racketball
  - tennis
- additional engine files for `padel`, `table_tennis`, `badminton`, and `pickleball` are wired but currently raise a safe unsupported-sport error
- supported score types by live engine:
  - squash/racketball: `11`, `15`
  - tennis: `4`, `6`
- supported best-of values:
  - `1`
  - `3`
  - `5`
- supported action types:
  - `let`
  - `match_settings`
  - `stroke`
  - `server`
  - `serve_side`
  - `timer`

### Interest requests and feedback

- register interest: [functions/register_interest/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/register_interest/handler.py)
- feedback: [functions/send_feedback/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/send_feedback/handler.py)

Current behavior:

- register-interest writes to `HitnScoreInterestRequests`
- honeypot field is `company`
- SES delivery must be configured correctly
- feedback sends email but does not persist to a database table

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
- `matches`
- `match_events`
- `HitnScoreInterestRequests`

### Match model notes

Schema bootstrap begins in [backend/schema/001_match_storage.sql](/Users/glennrowe/Development/Projects/RcktScore/backend/schema/001_match_storage.sql).

Important current `matches` concepts:

- tenant and court identity
- player names, surnames, countries, handedness
- player shirt colours
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

What is not fully protected today:

- root-admin routes do not yet have a full backend session/token model
- some root-admin flows rely on `x-root-admin-request` as a bypass header
- WebSocket infrastructure is not complete enough to describe as production-ready live transport

## Current Known Gaps

- there is still no automated backend or web frontend test suite in the repo, but a lightweight native iOS UI test bundle now exists in `mobile/ios/RcktScoreMobile/RcktScoreMobileUITests`
- social profile settings are UI-only scaffolds right now
- organisation-level handicap settings are UI scaffolds and are not persisted/enforced
- root-admin security needs a proper backend auth layer
- WebSocket subscription persistence is not implemented
- local frontend builds may fail if the checked-in `frontend/dist/` directory cannot be cleaned

## Maintenance Rule

When routes, auth behavior, security assumptions, or troubleshooting paths change:

- update this file
- update [technical-walkthrough.md](/Users/glennrowe/Development/Projects/RcktScore/docs/technical-walkthrough.md)
- update [troubleshooting.md](/Users/glennrowe/Development/Projects/RcktScore/docs/troubleshooting.md)
