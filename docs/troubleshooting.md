# Troubleshooting Guide

## Purpose

This guide is the practical debugging companion to the API and lifecycle docs.
It is intended to help future troubleshooting start from the current code paths,
known failure modes, and useful verification commands.

Related docs:

- [backend-api.md](/Users/glennrowe/Development/Projects/RcktScore/docs/backend-api.md)
- [technical-walkthrough.md](/Users/glennrowe/Development/Projects/RcktScore/docs/technical-walkthrough.md)
- [AGENTS.md](/Users/glennrowe/Development/Projects/RcktScore/AGENTS.md)

## Quick Local Checks

### Backend syntax

```bash
PYTHONPYCACHEPREFIX=/tmp/rcktscore-pyc python3 -m py_compile $(find backend/common backend/functions -name '*.py' | sort)
```

### Frontend production build

```bash
cd frontend
npm run build -- --outDir /tmp/rcktscore-frontend-dist
```

Use the scratch `outDir` because local builds may fail if Vite tries to clean
the checked-in `frontend/dist/` directory.

### iOS project inventory

```bash
xcodebuild -list -project mobile/ios/RcktScoreMobile/RcktScoreMobile.xcodeproj
```

This is a quick way to confirm the native target and scheme are still present
before debugging app-specific issues.

### iOS CLI build smoke

```bash
xcodebuild -project mobile/ios/RcktScoreMobile/RcktScoreMobile.xcodeproj -scheme RcktScoreMobile -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/RcktScoreMobileDerivedData build
```

If this fails with `No available simulator runtimes for platform iphonesimulator`,
the local Xcode/CoreSimulator installation needs attention before native CLI
builds will complete.

## Current Debugging Mindset

Start by deciding which of these layers is failing:

1. frontend route/state
2. API client request construction
3. Lambda handler validation or authorization
4. shared business logic
5. database schema or data
6. email or WebSocket infrastructure

## 1. Login and Session Issues

Relevant files:

- [frontend/src/context/AuthContext.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/context/AuthContext.jsx)
- [frontend/src/services/api.js](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/services/api.js)
- [backend/functions/login/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/login/handler.py)
- [backend/common/session_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/session_logic.py)

Common outcomes:

- `401 INVALID_CREDENTIALS`
- `403 PENDING_APPROVAL`
- `409 ACTIVE_SESSION_EXISTS`
- `401 SESSION_REQUIRED`
- `401 SESSION_INVALID`
- `401 SESSION_REPLACED`

What to check:

- the user exists in `SkwshOrgUsers`
- `password_hash` is present and valid
- `approval_status` is approved when login should succeed
- `org_user_sessions` contains the expected current or revoked rows
- the browser is actually sending `Authorization: Bearer <token>`
- the returned session or membership payload contains the expected `enabled_sports` list for that club or personal account

## 2. Dashboard, History, and Settings Issues

Relevant files:

- [backend/functions/get_dashboard/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/get_dashboard/handler.py)
- [backend/common/dashboard_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/dashboard_logic.py)
- [backend/functions/get_organization_settings/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/get_organization_settings/handler.py)
- [backend/common/organization_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/organization_logic.py)

Common symptoms:

- dashboard loads but lists are empty
- personal history seems unexpectedly short
- settings load but some controls do not persist

What to check:

- the `matches` and `match_events` tables exist
- the organisation exists in `SkwshOrgSettings`
- the signed-in user belongs to that organisation
- `SkwshOrgUsers.first_name` and `SkwshOrgUsers.surname` contain the expected values when user names look blank in settings or lookup flows
- whether the organisation user email is shared across more than one `SkwshOrgUsers` membership when password editing is unexpectedly disabled
- whether the organisation is down to its last admin when a delete or role downgrade is blocked
- current plan values such as `personal_free`, `personal_plus`, or `club_essentials`
- the `enabled_sports` JSON on `SkwshOrgSettings` matches what the UI should expose
- whether the UI control is real or scaffold-only

Important current truth:

- organisation-level handicap settings are not persisted yet
- racket-sport visibility settings are persisted through `enabled_sports`
- social profile fields are not persisted yet

## 3. Root-Admin Issues

Relevant files:

- [frontend/src/context/RootAdminContext.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/context/RootAdminContext.jsx)
- [backend/functions/root_admin_login/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/root_admin_login/handler.py)
- [backend/functions/get_root_admin_dashboard/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/get_root_admin_dashboard/handler.py)
- [backend/functions/get_root_admin_matches/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/get_root_admin_matches/handler.py)
- [frontend/src/pages/RootAdminClubPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/RootAdminClubPage.jsx)

Current risk areas:

- root-admin login is credential-checked, but backend session enforcement is incomplete
- some club admin actions rely on `x-root-admin-request`

If a root-admin issue appears:

- verify whether the failing route is a true root-admin route or a reused organisation route
- verify whether the request is depending on `rootAdminRequest: true`
- if a match seems to have vanished from normal club history, check whether `matches.is_archived` was set by the root-admin archive flow
- if root-admin delete looks incomplete, confirm whether the `matches` row is gone and whether `match_events` cascaded with it
- if a sport disappears for every club and personal account at once, check the root-admin `platform_sports` setting and whether the bulk apply path updated `SkwshOrgSettings.enabled_sports`
- do not assume root-admin failures will look like org-user session failures

## 4. Match Creation and Scoring Issues

Relevant files:

- [backend/functions/create_match/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/create_match/handler.py)
- [backend/functions/score_point/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/score_point/handler.py)
- [backend/functions/event_action/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/event_action/handler.py)
- [backend/functions/undo_action/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/undo_action/handler.py)
- [backend/functions/end_match/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/end_match/handler.py)
- [backend/common/match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/match_logic.py)

Common symptoms:

- personal user cannot start a second match
- a club match becomes scheduled instead of active
- score or server state looks wrong after undo
- shirt-colour changes do not apply for a personal-free account
- tennis appears in setup but cannot be created
- tennis score labels or server rotation look wrong during tie-breaks

What to check:

- tenant plan and organisation type
- `matches.sport` and the tenant `enabled_sports` list
- court conflict behavior
- latest `match_events` entries
- whether the action used `score_point` or `event_action`
- whether the UI is expecting realtime updates instead of using the returned `data.match`
- whether the active engine is `squash_match_logic.py` or `tennis_match_logic.py`

Important current truths:

- personal accounts are intentionally limited to one active match
- scheduled club matches can be created automatically when a court is busy
- undo works by removing the last non-`match_started` event and rebuilding state
- `common/match_logic.py` is now a dispatcher facade, not the only scoring implementation file

## 5. Display and WebSocket Issues

Relevant files:

- [frontend/src/services/websocket.js](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/services/websocket.js)
- [backend/functions/websocket_broadcast/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/websocket_broadcast/handler.py)
- [infrastructure/websocket.yaml](/Users/glennrowe/Development/Projects/RcktScore/infrastructure/websocket.yaml)

Current reality:

- WebSocket client code exists
- broadcast helper Lambda exists
- connection registration and subscription persistence are not fully implemented

If the display is stale:

- verify the match fetch path first
- treat WebSocket behavior as optional/partial until the infra is completed
- check `VITE_WEBSOCKET_URL`, `WEBSOCKET_DOMAIN_NAME`, and `WEBSOCKET_STAGE`

## 6. Email Flow Issues

Relevant files:

- [backend/functions/register_interest/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/register_interest/handler.py)
- [backend/functions/send_feedback/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/send_feedback/handler.py)
- [backend/functions/password_reset_request/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/password_reset_request/handler.py)
- [backend/common/mailer.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/mailer.py)

What to check:

- SES sender addresses are configured and verified
- the correct environment variable is present:
  - `INTEREST_TO_EMAIL`
  - `INTEREST_FROM_EMAIL`
  - `FEEDBACK_TO_EMAIL`
  - `FEEDBACK_FROM_EMAIL`
  - `USER_INVITATION_FROM_EMAIL`
  - `PASSWORD_RESET_FROM_EMAIL`
- base URLs are configured correctly for invitation or reset links

Common symptoms:

- request stored but email not sent
- password reset link points to the wrong host
- organisation invite exists but user remains pending forever

## 7. Schema and Migration Issues

Relevant files:

- `backend/schema/*.sql`

Most relevant current tables:

- `SkwshOrgSettings`
- `SkwshOrgUsers`
- `SkwshCourts`
- `SkRootAdmin`
- `org_user_sessions`
- `matches`
- `match_events`
- `HitnScoreInterestRequests`

If behavior seems impossible:

- confirm the expected migration actually exists in the target database
- confirm column names match the code path you are debugging
- remember that some handlers intentionally tolerate missing match tables by returning empty lists

## 8. Frontend Build and Dist Issues

Relevant files:

- [frontend/package.json](/Users/glennrowe/Development/Projects/RcktScore/frontend/package.json)
- [infrastructure/amplify.yaml](/Users/glennrowe/Development/Projects/RcktScore/infrastructure/amplify.yaml)

Known local issue:

- `npm run build` may fail if Vite cannot empty the existing `frontend/dist/` directory

Current workaround:

```bash
cd frontend
npm run build -- --outDir /tmp/rcktscore-frontend-dist
```

## 9. Native iOS Issues

Relevant files:

- [mobile/ios/RcktScoreMobile/RcktScoreMobile/Services/APIClient.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Services/APIClient.swift)
- [mobile/ios/RcktScoreMobile/RcktScoreMobile/State/SessionStore.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/State/SessionStore.swift)
- [mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/LoginView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/LoginView.swift)
- [mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/DashboardView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/DashboardView.swift)
- [mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/StartNewMatchView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/StartNewMatchView.swift)
- [mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/MatchScoringView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/MatchScoringView.swift)
- [mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/HistoricMatchView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/HistoricMatchView.swift)

Common symptoms:

- login works on web but fails on iOS for a user with multiple memberships
- iOS scorer loads, but court display code is missing
- completed matches do not appear while offline
- iPhone scorer feels visually crowded even when the backend state is correct
- club-admin sport visibility changes save in iOS settings but do not affect native match setup
- a personal-account profile photo disappears after reinstalling or signing in on another device
- the native start-match form looks washed out or unreadable on a device running dark mode
- `xcodebuild` reaches Swift compilation but fails later in asset-catalog tooling with no simulator runtimes available
- the dashboard bell appears to do nothing because no notification center flow exists yet

What to check:

- whether `POST /login` returned `data.session` or `data.organizationSelection`
- whether the account hit `ACTIVE_SESSION_EXISTS` for `client_type = mobile_app`
- whether the match has a court display code and `GET /match_display_access/{match_id}` is succeeding
- whether the issue is a backend scoring-state problem or only a scorer-layout problem
- whether `NetworkMonitor.swift` has marked the device offline
- whether `GET /organization_settings/{organization_id}` returned the updated `enabled_sports`
- whether `SessionStore` was refreshed after the native settings save and `StartNewMatchView.swift` is filtering against the current `enabled_sports`
- whether the profile photo was only chosen locally in the native settings screen and was never backed by a server-side upload path
- whether the installed build includes the adaptive dark-mode styling now used by `StartNewMatchFlowView` and `StartNewMatchView`
- whether the local Xcode install actually has usable iPhone simulator runtimes when CLI builds fail in `actool`

Important current truths:

- the iOS app now presents a native organisation-selection chooser when `/login` returns `data.organizationSelection`
- historic matches are online-only in the native app
- the dashboard now stays quiet when the device is offline instead of showing a persistent fetch-failure banner
- the dashboard bell no longer shows a placeholder message, but there is still no real notification-center implementation behind it
- native settings now push each section onto its own page, allow self-profile edits and association switching, expose an About page with the installed app version/build, but profile-photo selection is still device-local only
- native tennis scoring now expects opening serve/receive selections after warm-up, and doubles lineup/order data comes from the native match-setup payload rather than from a dedicated participant table
- the current scorer is functionally ahead of the docs that used to describe it,
  but its iPhone layout still needs redesign

## 10. Things That Are Not Bugs Right Now

These are current product limitations, not accidental breakage:

- root-admin backend auth is incomplete
- organisation handicap toggle in settings is scaffold-only
- reporting, stats, federation-style association links, and account-level game-settings sections in native settings are still mostly scaffold/placeholder surfaces
- WebSocket infrastructure is partial
- there is no native notification-center flow behind the dashboard bell yet
- there is no automated test suite in the repo yet

## Maintenance Rule

When a new recurring failure mode appears, update this file with:

- the symptom
- the likely layer
- the key files
- the fastest verification step
