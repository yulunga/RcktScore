# Troubleshooting Guide

## Purpose

This guide is the practical debugging companion to the API and lifecycle docs.
It is intended to help future troubleshooting start from the current code paths,
known failure modes, and useful verification commands.

If the app browser title or search description differs from the public landing homepage, verify `frontend/index.html` contains the shared `HitNScore | Every Point. Every Court.` title and description, rebuild the frontend, and clear any hosting/CDN cache.

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

### Backend unit tests

After installing `testing/automated/backend/requirements-test.txt`:

```bash
pytest -c testing/automated/backend/pytest.ini testing/automated/backend
```

### Web public-route smoke tests

After installing Playwright and its browsers as described in
`testing/automated/web/README.md`, start the frontend and run:

```bash
cd frontend
npm run test:e2e:smoke
```

### Visible web tennis journey

Run `npm run test:e2e:tennis:watch` from `frontend/`. Playwright starts or
reuses the local Vite server and opens a visible Chromium window with a short
delay between actions. The journey is API-mocked and does not alter live data.

If the browser runtime is missing after a fresh checkout, run `npm ci` followed
by `npx playwright install chromium`. A Python virtual environment is not used
for the React/Playwright suite. On failure, inspect `frontend/playwright-report/`
and `frontend/test-results/` for the HTML report, screenshots, video, and trace.
Use `npm run test:e2e:padel:watch` to watch only the doubles Padel and Golden
Point receiver-choice scenario.

Use `npm run test:e2e:racket:watch` to watch the API-mocked Squash/Racketball
journeys. They verify Golden Point and handicap payloads for Personal Free and
Personal Plus, the saved per-sport timer default, and that an untimed match
opens directly on scoring.

Use `npm run test:e2e:scheduling:watch` to watch a Personal Plus user schedule
a match and start it later from Matches. The mocked setup begins with another
active match to verify that scheduling remains available; activation happens
only after the active match has cleared. The journey also checks the visible
Current/Scheduled/History controls in both light and dark colour schemes.

Use `npm run test:e2e:history:watch` to watch dedicated completed Squash and
Tennis views. The fixtures verify match start time and duration, game/set
durations, sport terminology, the grouped scoring timeline, and separate
tennis game/set dividers. The web detail must use the plain shared header without
Historic Match copy or a separate History/Matches action row. Completed-match cards should navigate to
`/match/{match_id}/history`; `/match/{match_id}` is reserved for live scoring.

Use `npm run test:e2e:header:watch` to watch the signed-in dashboard header
compact after a vertical scroll. The check confirms that the outer width does
not change, the header remains sticky, Home and the blue new-match `+` precede
Matches/Analytics/Settings/Help, labels become icons, account and club details
stay absent, the removed dashboard description and footer stay absent, and
Start New Match remains a separate blue action. The header `+` and dashboard
action must both open the same sport-selection overlay before setup. It also verifies that new-match
routes do not highlight Matches, that the mobile menu remains on one row and
Settings opens `/settings`, the Settings section tabs do not repeat Home, and
Recent Matches uses date/time tiles with six-card pages over at most 24 records,
forming three complete two-card desktop rows. Its heading opens Matches → History;
the Active Matches and Scheduled Matches headings open their corresponding tabs.
Matches History uses 20-card pages that form exactly ten
two-card desktop rows. If full-width cards repeat below those rows, inspect the
desktop visibility of `.dashboard-carousel--mobile`; it must remain hidden until
the phone/portrait breakpoint. The automated journey also
holds the page at the former scroll-boundary failure point and verifies that the
header changes state once rather than oscillating between labels and icons.
The same suite verifies that the profile icon beside Messages exposes the
signed-in username, opens `/profile`, and lets a club admin update their own
name/contact/country fields. If the profile loads blank, verify that
`GET /organization_settings/{organization_id}` returns the signed-in username in
`users`; if saving fails, inspect `PUT /personal_profile/{organization_id}` and
the current org-user bearer session.

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

### iOS UI test build smoke

```bash
xcodebuild -project mobile/ios/RcktScoreMobile/RcktScoreMobile.xcodeproj -scheme RcktScoreMobile -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/rcktscore-xcode build-for-testing
```

The checked-in UITest bundle lives in `mobile/ios/RcktScoreMobile/RcktScoreMobileUITests`.
Its launch helpers currently use:

- `UITEST_MODE`
- `UITEST_LIGHT`
- `UITEST_DARK`
- `RESET_STATE=1`

The app now honors those launch flags by forcing light/dark appearance and clearing local `UserDefaults` state before boot when `RESET_STATE=1` is present.

The saved service-side regression can be run on an Apple Simulator without
test credentials or a live API:

```bash
testing/automated/mobile/run-racket-service-side-ui-test.sh
```

It opens a fixture match at `R2`, changes the server to Left, checks that the
marker is replaced by `L2`, awards the server the next point and checks for
`R3`. The runner saves an `.xcresult` containing the test log and three
screenshots. Use a new `RCKTSCORE_UI_RESULT_PATH` for subsequent retained runs.

The watchable credential-backed journey is deliberately separate:

```bash
RCKTSCORE_UI_RESULT_PATH=/tmp/RcktScore-LiveRacketMatch-$(date +%Y%m%d-%H%M%S).xcresult \
  testing/automated/mobile/run-live-racket-match-ui-test.sh
```

It creates a real completed Paul-versus-Mark match in the Personal Plus test
account and logs out. Keep Simulator open to watch it, or set
`RCKTSCORE_UI_STEP_DELAY=2` to slow the actions. The account must not already
have an active match. The script disables parallel testing to avoid invisible
Simulator clones and removes credential-variable lines from console output.
Never share a failed `.xcresult` until confirming that its launch diagnostics
contain no secrets; rotate a test credential immediately if Xcode prints it.

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
- `401 SESSION_EXPIRED`

What to check:

- the user exists in `SkwshOrgUsers`
- `password_hash` is present and valid
- `approval_status` is approved when login should succeed
- `org_user_sessions` contains the expected current or revoked rows
- `org_user_sessions.expires_at` is in the future; the default lifetime is 30 days and the iOS app will discard an expired cached session
- the browser is actually sending `Authorization: Bearer <token>`
- the returned session or membership payload contains the expected client-effective `enabled_sports` list

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
- pending club users can now also be approved from the root-admin club page, so if email approval was skipped manually, check `SkwshOrgUsers.approval_status` and `approved_at` first before debugging the invitation link itself
- whether the organisation user email is shared across more than one `SkwshOrgUsers` membership when password editing is unexpectedly disabled
- whether the organisation is down to its last admin when a delete or role downgrade is blocked
- current plan values such as `personal_free`, `personal_plus`, or `club_essentials`
- for Personal Free, confirm the dashboard returns no more than three readable completed matches and only a redacted `locked: true` fourth preview
- for Personal Plus statistics, verify the registered first name and surname exactly match player details stored on completed matches; otherwise those matches appear in `unclassified_match_count`
- if point or serving percentages are unexpectedly empty, inspect the retained `match_events` payloads because those figures come from scoring actions rather than the final score alone
- `platform_settings.enabled_sports_web` / `enabled_sports_ios`, the organisation `enabled_sports`, and the membership's matching client column all contain the sport
- whether the UI control is real or scaffold-only

Important current truth:

- Squash/Racketball handicap scoring is available to Personal Free, Personal Plus, and club accounts; there is intentionally no organisation-level handicap entitlement switch
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

- root-admin requests require an unexpired bearer token backed by `root_admin_sessions`
- only one active root-admin session per root-admin account is retained; a newer login revokes the previous session

If a root-admin issue appears:

- verify whether the failing route is a true root-admin route or a reused organisation route
- check for `ROOT_ADMIN_SESSION_REQUIRED`, `ROOT_ADMIN_SESSION_INVALID`, `ROOT_ADMIN_SESSION_REPLACED`, or `ROOT_ADMIN_SESSION_EXPIRED`
- verify migration `018_root_admin_sessions.sql` has been applied before testing login
- verify migration `020_personal_registration_status.sql` has been applied if historical personal signups still show approval terminology
- confirm the frontend is sending `Authorization: Bearer <token>` and is not relying on the removed `x-root-admin-request` header
- if User Accounts totals look higher than the visible list, remember the summary cards count distinct usernames by account category and a user with both personal and club memberships can appear in more than one category
- club match activity on a user profile is attributed from `matches.referee_name`; personal-account activity is attributed from the user's personal organisation
- user-profile Last Activity is the latest `org_user_sessions.last_seen_at` value for that username; `Not recorded` means no retained session activity exists
- adding a club association intentionally creates a pending membership and invitation; personal registration remains immediate
- a root-admin password change updates every membership row sharing the username and revokes the user's active web/mobile sessions; the user must sign in again with the replacement password
- if a match seems to have vanished from normal club history, check whether `matches.is_archived` was set by the root-admin archive flow
- if root-admin delete looks incomplete, confirm whether the `matches` row is gone and whether `match_events` cascaded with it
- if a sport disappears for every account on one client, check the matching platform client list and whether migration `028_client_sport_access.sql` has been applied
- if only one user is affected, inspect `SkwshOrgUsers.enabled_sports_web` and `enabled_sports_ios` for each of their memberships; access changes intentionally revoke active sessions
- saving Platform RacketSports availability alone must not enable the sport for existing users or clubs; enable the required client from the User Account page for personal users, or enable the club first and then select the club membership's client access
- if the affected-user preview fails, verify `POST /root_admin/platform_sports/preview` is deployed and the root-admin session is still valid; the preview is read-only and must not alter sport access
- logout is idempotent and revokes the token through `POST /root_admin/logout`

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
- a selected shirt colour is replaced by the default colour
- tennis appears in setup but cannot be created
- tennis score labels or server rotation look wrong during tie-breaks
- Golden Point scoring reaches 40-40 but the next point cannot be recorded
- a final-set 10-point match tiebreak does not start when the sets become level
- a queued offline point appears to be applied twice after reconnection

What to check:

- tenant plan and organisation type
- the submitted `player1_shirt_color` and `player2_shirt_color` values, plus all four `team{1|2}_player{1|2}_shirt_color` values for tennis doubles (all personal and club plans may set them)
- `matches.sport` and the tenant `enabled_sports` list
- court conflict behavior
- latest `match_events` entries
- the matching `match_action_receipts.client_action_id` row when investigating a replayed iOS mutation
- whether the action used `score_point` or `event_action`
- whether the UI is expecting realtime updates instead of using the returned `data.match`
- whether the active engine is `squash_match_logic.py` or `tennis_match_logic.py`
- whether migration `021_tennis_scoring_formats.sql` is present and the match row contains the expected tennis flags; tennis should accept the deciding point immediately from the Right service side, while padel must have a `receiver_choice` event identifying the selected receiving partner's court first

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
  - `PASSWORD_RESET_BASE_URL` for automatic personal-account password setup
  - `FEEDBACK_TO_EMAIL`
  - `FEEDBACK_FROM_EMAIL`
- for club-user invitation links, `USER_APPROVAL_BASE_URL` controls the public approval-link host/path and `USER_APPROVAL_LOGIN_URL` controls where the success page redirects after showing the confirmation message for three seconds
  - `USER_INVITATION_FROM_EMAIL`
  - `PASSWORD_RESET_FROM_EMAIL`
  - `EMAIL_LOGO_URL` when the mascot does not load inside an HTML email; the URL must be public and use HTTPS
- base URLs are configured correctly for invitation or reset links

Common symptoms:

- request stored but email not sent
- `Ping Us` returns `FEEDBACK_DELIVERY_FAILED` because SES rejected or could not accept the message
- personal signup returns `PERSONAL_SIGNUP_CONFIGURATION_ERROR` when the password-setup URL is not configured
- personal signup creates a pending owner membership until the emailed password is chosen; this is email verification, not manual root approval
- root admin can manually verify an unverified account from **User Accounts → user profile → Profile**; this validates a matching personal registration and approves pending memberships for that email, but does not create a password, so use the separate Change Password control when a test account still needs credentials
- personal signup returning `REGISTRATION_FAILED` with a `SkwshOrgSettings_interest_request_id_fkey` error indicates migration `017_platform_enabled_sports.sql` is missing and the old optional-table fallback rolled back the registration insert; apply migration 017 and deploy the current transaction-safe fallback
- club requests remain pending enquiries and do not create accounts automatically
- logged-in subscription enquiries require migration `022_club_subscription_enquiries.sql`; if the extended club fields fail to store, apply that migration before deploying the updated `register_interest` and root-admin interest-request functions
- `SESSION_REQUIRED`, `SESSION_INVALID`, or `SESSION_EXPIRED` from a Club Essentials/Club Pro enquiry means the saved mobile session must be refreshed by signing in again
- password reset link points to the wrong host
- organisation invite exists but user remains pending forever

For `Ping Us`, verify that the deployed `FEEDBACK_FROM_EMAIL` identity exists in `eu-west-2` and that `FEEDBACK_TO_EMAIL` is permitted by the account's SES production or sandbox status. The checked-in feedback defaults use `hello@hitnscore.com`; redeploy the backend after changing these parameters because updating the iOS app alone cannot repair SES configuration.

For subscription enquiries, verify `INTEREST_FROM_EMAIL` is an SES-verified identity and `INTEREST_TO_EMAIL` is set to the intended `hello@` mailbox. The backend sends one confirmation to the signed-in requester and one admin notification to that configured destination.

On iOS, the Want In and Ping Us forms are replaced by their confirmation screens only after the API returns success. If a form remains visible, check its inline error and the corresponding registration or feedback backend logs; the retained fields allow the user to correct the request and retry.

On the web, package version/build details are intentionally absent from both the standard login and `Want In` registration states. If they still appear at `/` or `/login?interest=1#want-in`, deploy the current frontend bundle; no backend change is required.

The login logo and HitnScore wordmark should link to `https://www.hitnscore.com/`. If they do not, verify the `.login-branding` anchor in `LoginPage.jsx` and deploy the current frontend bundle.

The app route `/help` is the authoritative public Help Centre. The landing site should not serve `help.html`: its Help & feedback link targets `/help`, Privacy & terms targets `/help?section=privacy`, and Cookie settings targets `/help?section=cookies`. If a landing link still opens the removed static page, deploy the current `weblanding/` bundle or clear the hosting/CDN cache. If a direct Help Centre section opens the overview instead, verify the `section` value against `web-access`, `ios-access`, `terms`, `privacy`, and `cookies` and deploy the current frontend bundle.

If web Analytics does not appear, inspect `hitnscore.analytics-consent` in local storage. A missing value should display the privacy-choice panel, `denied` must leave the Google tag unloaded, and `granted` should add one `script[data-hitnscore-analytics]` element for measurement ID `G-30V1YTPY1F`. Use GA4 DebugView or the browser network panel only after granting consent. SPA page-view payloads should contain route templates such as `/match/:matchId` or `/tournament-draw/:accessKey`, never the real path identifiers or query strings. The Cookie Policy's **Update cookie preferences** control reopens the panel; choosing **Essential only** disables collection and removes accessible `_ga` cookies.

The Help Centre header should remain fixed and switch to `help-centre-header--compact` after scrolling beyond 48 pixels. If it does not shrink, check the scroll listener in `HelpPage.jsx` and the compact rules in `styles.css`. The Help Centre logo/wordmark should navigate to `https://www.hitnscore.com/`, not the app login route.

The root-admin User Accounts `Unverified Users` card requests `GET /root_admin/users?account_type=unverified`. If its count is non-zero but selecting it does not filter the list, deploy the current root-admin users Lambda as well as the frontend; the card depends on backend support for that filter value.

## 7. Schema and Migration Issues

Relevant files:

- `backend/schema/*.sql`

Most relevant current tables:

- `SkwshOrgSettings`
- `SkwshOrgUsers`
- `SkwshCourts`
- `SkRootAdmin`
- `org_user_sessions`
- `root_admin_sessions`
- `match_action_receipts`
- `matches`
- `match_events`
- `HitnScoreInterestRequests`

If behavior seems impossible:

- confirm the expected migration actually exists in the target database
- for offline iOS scoring, confirm migration `019_offline_scoring_support.sql` has added `org_user_sessions.expires_at` and `match_action_receipts`
- for Golden Point and final-set match-tiebreak options, confirm migration `021_tennis_scoring_formats.sql` has added both tennis format columns
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
- an active match cannot be reopened while offline
- offline actions remain queued after connectivity returns
- iPhone scorer feels visually crowded even when the backend state is correct
- club-admin sport visibility changes save in iOS settings but do not affect native match setup
- a personal-account profile photo disappears after reinstalling or signing in on another device
- the native start-match form looks washed out or unreadable on a device running dark mode
- `xcodebuild` reaches Swift compilation but fails later in asset-catalog tooling with no simulator runtimes available
- the welcome notice remains unread after opening Notifications, or the bell colour does not change
- personal-account deletion is rejected or the user remains signed in afterward

What to check:

- whether `POST /login` returned `data.session` or `data.organizationSelection`
- whether the account hit `ACTIVE_SESSION_EXISTS` for `client_type = mobile_app`
- whether the match has a court display code and `GET /match_display_access/{match_id}` is succeeding
- whether the issue is a backend scoring-state problem or only a scorer-layout problem
- whether `NetworkMonitor.swift` has marked the device offline
- whether `OfflineMatchStore.swift` contains a cached match for the same username and organisation membership
- whether the cached match had been opened online on this device before connectivity was lost
- whether queued UUIDs exist in `match_action_receipts` after reconnection, and whether the saved session expired before synchronisation
- if the device is online but an action remains queued, use the detailed synchronisation message now shown by the scorer to distinguish an API rejection, expired session, missing migration, or transport failure; the action remains queued under its original UUID for a safe retry
- whether `GET /organization_settings/{organization_id}` returned the updated `enabled_sports`
- whether `SessionStore` was refreshed after the native settings save and `StartNewMatchView.swift` is filtering against the current `enabled_sports`
- whether the profile photo was only chosen locally in the native settings screen and was never backed by a server-side upload path
- whether the installed build includes the adaptive dark-mode styling now used by `StartNewMatchFlowView` and `StartNewMatchView`
- whether the local Xcode install actually has usable iPhone simulator runtimes when CLI builds fail in `actool`
- whether migration `023_system_notifications.sql` was applied and `GET /notifications/{organization_id}` returns the expected `all` or plan-specific audience
- whether `POST /notifications/{notification_id}/read` succeeds with the current organisation-user bearer token
- whether account deletion used a personal-owner session, had connectivity, sent the exact confirmation value, and deployed the `DELETE /personal_account/{organization_id}` Lambda route

Important current truths:

- the iOS app now presents a native organisation-selection chooser when `/login` returns `data.organizationSelection`
- the iOS login form now exposes a show/hide password control locally, but it still posts the same backend login request and does not change session behavior on its own
- historic matches, new match creation, scheduled-match activation, and settings changes are online-only in the native app
- one previously opened active match is cached locally; squash/racketball and tennis scoring actions update locally, survive an app restart, and replay in order when connectivity returns
- offline undo can remove actions still queued on that device; undoing an older server-synchronised action requires connectivity
- the dashboard stays quiet when offline and replaces the bell with an offline icon; online, an unread persisted notification makes the bell yellow until the user explicitly marks it read
- self-service deletion applies only to the authenticated owner of a personal account; club memberships remain club-admin managed, and deletion requires two client confirmations plus server-side ownership validation
- each queued mutation keeps the same `client_action_id` across retries, and the backend receipt prevents duplicate application
- native settings now push each section onto its own page, allow self-profile edits and association switching, expose an About page with the installed app version/build, can enable local Face ID / Touch ID session unlock, but profile-photo selection is still device-local only
- native tennis scoring automatically assigns the other singles player as receiver when the opening server is chosen; doubles still expects explicit opening serve/receive selections, and its lineup/order and per-participant shirt colours come from the native match-setup payload rather than from a dedicated participant table
- optional tennis timed breaks come from `tennis_timed_breaks` in the `match_started` event; when enabled, there is no break after game 1, later odd games trigger 90 seconds, and a completed set triggers 120 seconds instead
- at tennis Golden Point the deciding point proceeds automatically from the 40-40/Right service side; in padel, the receiving team chooses which named partner receives and that `receiver_choice` is queued like a point while offline and synchronised before the deciding point
- the squash/racketball scorer now selects compact widths on phone-sized screens, scrolls long game history horizontally, adapts warm-up actions when they cannot fit side by side, and shows a completed-match summary after the final point
- changing the current squash/racketball service box at an unchanged score must replace the latest rail marker (`R2` to `L2`), not add a second marker; run `testing/automated/mobile/run-racket-point-rail-scenarios.sh` for fast reducer coverage, `testing/automated/mobile/run-racket-service-side-ui-test.sh` for the credential-free Simulator regression, and the opt-in `testing/automated/mobile/run-live-racket-match-ui-test.sh` only when a completed match may be written to the Personal Plus test account
- white, yellow, and pink scoring cards use dark foregrounds and a contrasting score inset; a running match clock is light green, a paused clock remains slate, and stroke/let player choices stay in the pink-accented Match Actions sheet with explicit player names
- the shared iOS bottom navigation now compacts labels and icon sizing under larger Dynamic Type settings, but extremely aggressive accessibility sizes may still need further tab-bar simplification if new labels are added later

## 10. Production Health and Alarm Issues

The production readiness endpoint is:

```text
GET https://st3nn5zsm6.execute-api.eu-west-2.amazonaws.com/prod/health
```

- `200` with `data.status = "healthy"` confirms API Gateway, the health Lambda, the Supabase connection configuration and a minimal database query.
- `503 SERVICE_UNAVAILABLE` means the database readiness query failed. Inspect `/aws/lambda/<HealthFunctionName>` in CloudWatch Logs; the HTTP response deliberately omits exception details.
- no alarm email after deployment usually means the SNS confirmation email sent to `AlarmNotificationEmail` has not been accepted. Check that the subscription on `rcktscore-backend-production-alarms` is `Confirmed`.
- `rcktscore-backend-health-check-errors` covers scheduled database failures; `rcktscore-backend-http-api-5xx` covers HTTP server responses.
- `rcktscore-backend-apple-reconciliation-missing` enters ALARM when no hourly reconciliation invocation is observed for two hours. Check EventBridge Scheduler before invoking reconciliation manually.
- use CloudWatch alarm history to distinguish a real failure from deployment transition noise before changing thresholds.

Useful verification commands:

```bash
curl -fsS https://st3nn5zsm6.execute-api.eu-west-2.amazonaws.com/prod/health
aws cloudwatch describe-alarms --alarm-name-prefix rcktscore-backend- --region eu-west-2
aws sns list-subscriptions-by-topic --topic-arn <ProductionAlarmTopicArn> --region eu-west-2
```

## 11. Things That Are Not Bugs Right Now

These are current product limitations, not accidental breakage:

- handicap setup is intentionally shown only for Squash/Racketball, but it is available on every account tier for those sports
- per-sport timer defaults in Game Settings are persisted by migration `029_timed_break_defaults.sql`; if a setup toggle has the wrong initial value, inspect `organization.timed_break_defaults` from `GET /organization_settings/{organization_id}`. The setting preselects timing but never prevents a per-match override
- Personal Plus scheduling is available on web and iOS. If `Start` is disabled with “Finish active match first,” end the current personal match first; direct activation correctly returns `409 ACTIVE_MATCH_EXISTS`. Personal Free does not receive the scheduling control
- reporting rows remain placeholders in native settings; Analytics now contains working basic scored-match stats plus Personal Plus personal performance, while deeper federation-style association integrations remain incomplete
- if squash/racketball Golden Point does not end a PAR-11 game at 11-10 or a PAR-15 game at 15-14, confirm `tennis_no_ad_scoring` is present on the match and match-start event; the shared field is intentionally reused for the racket Golden Point rule
- WebSocket infrastructure is partial
- notification inbox delivery and cross-device read state are implemented, but APNs push delivery and background badge refresh remain unimplemented
- StoreKit purchase buttons appear only in Debug builds until backend Apple verification is connected; tap the Personal Plus plan to reveal the yearly purchase, Restore Purchases, and Manage Subscription controls for 20 seconds
- the subscription page's green current-tier outline and pink Current badge follow the latest backend organisation plan, not a local StoreKit test transaction. If the UI disagrees with `SkwshOrgSettings.plan`, confirm `GET /dashboard/{organization_id}` returns the expected plan and that the app is online so it can replace its cached login-session plan
- new Personal Plus purchases are yearly-only. Monthly transactions remain recognized for restore and lifecycle processing; an old local StoreKit transaction must not make a purchase choice look like the current backend tier
- Padel is doubles-only in both clients and requires four named participants. If it is missing from match setup, confirm `padel` is enabled in both Root Admin platform sports and the active account/club
- cancelling an Apple auto-renewable subscription normally disables renewal but retains Personal Plus through the paid `expires_at`; downgrade only after verified expiry or revocation. Local Xcode StoreKit transactions can be inspected or expired from Xcode's transaction manager
- when the native Apple subscription-management sheet closes, the app refreshes StoreKit entitlements and reloads the server dashboard so a just-processed expiry or revocation replaces the cached plan. Cancelled SwiftUI/URL refresh tasks are ignored rather than shown as `Unable to fetch dashboard data`; genuine API, decoding, and network failures still surface that error
- production subscription troubleshooting and verification gates are defined in [apple-subscription-production.md](/Users/glennrowe/Development/Projects/RcktScore/docs/apple-subscription-production.md); Release purchasing must remain disabled until its configuration and test checklists pass
- the Apple purchase-context endpoint requires migration `025_apple_subscription_account_identity.sql`. If it reports a missing column/table, apply migrations `024` then `025`; if it returns `APPLE_PURCHASE_NOT_ALLOWED`, confirm the organisation has `org_type = 'personal'` and its `owner_username` matches the authenticated session username
- the Apple verification endpoint additionally requires `026_apple_purchase_verification.sql`, the public Apple roots in `backend/certs`, and `app-store-server-library==3.1.2`; deploy with `APPLE_ALLOWED_ENVIRONMENTS=Sandbox` first
- if the Personal Plus card expands to an empty area in TestFlight, inspect the deployed CloudFormation `ApplePurchasesEnabled` parameter and the purchase-context response. Release builds intentionally hide purchase actions while that server flag is `false`; the app now displays an explicit disabled-state message instead of a blank expansion
- `APPLE_PURCHASES_DISABLED` is expected while the deployment kill switch is false. Account, app, product and environment mismatch errors are hard security rejections and must not be bypassed
- Xcode `.storekit` transactions are intentionally UI-only for this deployment. Use a Sandbox account through TestFlight for end-to-end Apple-signed verification
- Production verification requires the numeric App Store Connect Apple ID in `APPLE_APP_ID`; it is different from the bundle ID and `appAccountToken`
- lifecycle processing additionally requires migration `027_apple_subscription_lifecycle_processing.sql`. Configure App Store Connect V2 Sandbox/Production URLs as `/subscriptions/apple/notifications`; the endpoint has no user bearer token because its trust boundary is Apple's verified `signedPayload`
- scheduled reconciliation prioritises elapsed subscriptions and asks Apple for current status before removing access. The local expiry fallback waits 15 minutes so a delayed renewal notification does not cause a temporary Plus-to-Free-to-Plus transition or false audit pair. The fallback still runs without Apple credentials; full missed-notification repair requires `APPLE_SERVER_API_SECRET_ARN` to reference a Secrets Manager JSON value containing `private_key`, `key_id`, and `issuer_id`. Inspect `reconciliation_error`, retry count and next reconciliation time in root admin if the Apple status lookup fails
- cancellation is not immediate expiry: `auto_renew_enabled=false` retains Plus until `expires_at`. Refund/revoke removes Plus immediately; billing retry removes it unless Apple reports an active grace period
- CORS currently uses `Access-Control-Allow-Origin: *` in both API Gateway/SAM and Lambda response headers. This permits JavaScript from any website origin to call the API and read its responses when it can supply valid credentials; it does not bypass bearer-token checks and does not govern native iOS networking. Before production, replace the wildcard with exact trusted web origins, keep `OPTIONS` and Lambda headers consistent, emit `Vary: Origin`, and give preview/local environments their own explicit allowlists
- backend pytest logic tests, Playwright public-route smoke tests, and native
  iOS UI smoke scaffolding are checked in, but their coverage is still limited
  and they are not wired into a documented CI pipeline

## Maintenance Rule

When a new recurring failure mode appears, update this file with:

- the symptom
- the likely layer
- the key files
- the fastest verification step
## Tournament Manager

If Tournament Manager does not appear in club Settings:

- confirm the current association is a club rather than a personal account
- confirm the signed-in membership role is `admin`
- inspect `organization.features.tournament_manager.web_enabled` from
  `GET /organization_settings/{organization_id}`
- confirm `tournament_organization_features.web_enabled` is true for that club
- use the root-admin club Tournament tab, immediately after Game Settings, to
  enable or disable the feature

If the Tournament button does not appear in the signed-in web header, confirm the
user is currently associated with the enabled club rather than another personal
or club membership. The header reads the effective feature from organisation
settings whenever the active organisation changes.

Direct calls return `TOURNAMENT_FEATURE_DISABLED` while the club feature is off.
Disabling the feature retains its tournament and player data.

The dashboard Live Tournaments section uses the same feature flag and tournament
list request as the header/list page. It is intentionally absent for personal or
disabled-club sessions, and only `draw_published` events appear there. If the
section or its green Live badges are missing, inspect both
`organization.features.tournament_manager.web_enabled` and the returned event
statuses. Its heading is the link to `/tournaments`; there is no separate View all
button. New Tournament starts collapsed and expands from its heading. If it closes
unexpectedly, confirm the form was still untouched for the five-minute inactivity
window. Selected tournament details, public access and the return-to-draft edit
control likewise expand from the tournament-name heading. Entrant edit controls are top-right gear buttons; grade, seed,
linked-account and approved-member indicators sit beneath the club line.

In club Settings, Primary Contact can only be selected from approved members in
the organisation-settings response. If a person is missing, add and approve their
club membership first. Organisation Users are sorted by surname and filtered
client-side by the Search Users field; the Add User form starts collapsed and an
untouched expanded form closes after five minutes.

The migration-created `demouser@democlub.com` account has no known initial
password. Set one through Root Admin → User Accounts before using the demo login.
The eight migration `033` Demo PlayOne–Demo PlayEight accounts follow the same
password-disabled rule and do not become usable logins until an administrator
sets their passwords.

If adding an entrant unexpectedly creates or reuses an identity, inspect
`players.email`, `registered_username`, and `claim_status`. Email is
the current strong deduplication key; name-only duplicate review and merge tooling
is not implemented yet.

Player entry is deliberately search-first. The player-search route requires a
club-admin session, at least two query characters and an enabled Tournament
Manager feature. An `Internal tournaments can only include members` error means
the selected identity has no approved membership of the host club; change the
event to Open only if external entrants are intended. A draw-size error means the
count of non-withdrawn entries has reached `tournament_events.draw_size_limit`.

If the new event options or ability values are absent after deployment, confirm
`032_tournament_event_options.sql` has been applied before deploying the Lambda
and web changes.

The tournament detail read checks for `tournament_draws` and `tournament_matches`
before querying them. It returns temporary derived draw-group labels, or draw
groups without fixtures, during a staggered deployment. Migration `032` is still
mandatory before creating events, migration `034` before generating draws,
migration `035_tournament_draw_publication.sql` before publishing or public access,
and migration `036_tournament_match_results.sql` before scheduling fixtures or
recording results.

If Generate Draw is disabled, the event needs at least two active entrants and
the current membership must be a club admin. If the draw request fails after the
button becomes available, confirm `034_tournament_draw_matches.sql` has been
applied. Draw generation now creates an editable draft; only **Publish Draw**
changes the event to `draw_published` and locks entry changes. Round robin creates
every round; knockout and knockout-with-plate create complete future-round trees,
while Monrad currently creates the opening round only. Knockout winners progress
automatically, and first-round knockout-with-plate losers populate the plate. Older
published knockout draws with opening-round rows only backfill their future rounds
when the first result is saved after migration `036`.
A generated, unpublished draw is shown as **Draw ready**, with **Publish Draw**
above the bracket. The database value `draw_published` is shown as **Live**. From
the tournament list, select **View Draw**. If the detail page instead reports
**Draw needs rebuilding**, the event status exists without fixture rows; an admin
can use **Rebuild Missing Draw**, which is idempotent when fixtures already exist.

If publishing does not produce a public key, confirm migration `035` and the
publish Lambda routes were deployed together. Public responses deliberately omit
emails, account IDs and membership details. **Return Draw to Draft** disables the
key immediately and refuses to proceed once a match has started or completed.
The Public Access switch is in the live tournament description card and is
club-admin-only. Turning it off preserves the key for later reuse but causes the
public route to return not found until the switch is enabled again; it does not
change the draw's Live status.

If a fixture action icon is absent, confirm the draw is Live and both participant
slots contain actual entrants rather than Winner/Bye placeholders. Scheduling also
requires at least one active club court. A scheduled match carries
`tournament_event_id`, `tournament_match_id` and `tournament_name`; if its Tournament
label is missing from Scheduled Matches, confirm migration `036` and the updated
match serializers are deployed together. Once scheduled, enter the result through
that linked scoring match; the separate manual score action is removed to prevent
two conflicting result sources. Ordinary approved members can enter an unscheduled
fixture's first result, but only club admins can use **Edit Score**. Admin corrections are
rejected when a dependent next-round fixture has already started or completed.

CSV player imports require `First Name` and `Surname` headers. Optional recognised
headers are Email, Club and Ability (1–4). Duplicate warnings are produced for
repeated file rows, an existing tournament entrant or one exact shared-player
match. If an update rejects email or club changes, inspect `players.user_id`,
`registered_username` and `claim_status`; linked account-owned identity fields
must be edited through the account/membership workflow instead.
The pink link icon means the player identity is connected to a registered
HitNScore account. The member icon independently means the account has an
approved membership of the host club; neither indicator creates new entitlement.
