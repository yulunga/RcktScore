# Technical Walkthrough

**Naming:** HitnScore is the customer-facing application. `RcktScore` is the internal project and repository code name.

## Purpose

This document describes the current end-to-end request lifecycles in `RcktScore` v2.
It is written to help developers trace product behavior through the actual web app,
Lambda handlers, and shared backend logic.

The app entry document at `frontend/index.html` and the public landing homepage use the same browser title, `HitNScore | Every Point. Every Court.`, and the same public description metadata.

The React app's consent panel mirrors the public landing page. `CookieConsent.jsx` stores the visitor's explicit analytics choice, while `services/analytics.js` loads the GA4 tag only after consent and sends manual SPA page views. Dynamic user, match, tournament, organisation and public-draw path segments are replaced with route-template labels, query strings are not reported, and Google advertising storage/signals remain disabled. The Help Centre cookie section documents the active Analytics cookies and provides the control for reopening these preferences.

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
5. The normalized email identity is authenticated only when the supplied password
   matches every non-null `SkwshOrgUsers.password_hash` for that email. A partial
   match returns `PASSWORD_RESET_REQUIRED`, emails an identity-wide reset, and
   exposes no memberships. If every row verifies but its salted hash text differs,
   login rewrites those rows to one fresh hash before continuing. Null-hash rows
   do not participate in verification but are retained after another row proves
   the identity. Organisation details come from `SkwshOrgSettings`.
6. The handler checks for an already-active session for the identity across web
   and mobile. A forced continuation revokes the previous token regardless of
   client source.
7. The handler creates an expiring opaque session in `org_user_sessions`; the default lifetime is 30 days. Web receives it only in the `__Host-hitnscore_session` HttpOnly cookie, while native clients retain the JSON bearer contract.
8. With the default `IdentityFirstLoginEnabled=true`, the API returns
   `data.session` immediately. It prefers the user's approved personal
   membership, falls back to the first approved club, and includes every
   approved membership in `available_memberships`. Setting the deployment
   parameter to `false` restores the legacy `data.organizationSelection`
   response for multiple memberships; clients retain both branches.
   Other outcomes are:
   - `PENDING_APPROVAL`
   - `ACTIVE_SESSION_EXISTS`
   Successful session and organisation-selection responses also include `session_expires_at`.
9. The frontend stores no authentication credential. It restores non-secret
   membership state and the in-memory CSRF value through `/session/status`.
   Until that initial request resolves, protected routes and the public login
   route render a neutral branded restoration screen rather than treating the
   user as signed out, which keeps a browser refresh on its requested URL;
   its context switcher changes only the active membership. Context changes reload Dashboard and
   Matches data. Web and iOS render every retained membership as a visible
   `Score this match for` choice before racket-sport selection, labelling the
   personal choice as Personal or Personal Plus, so a match cannot be started
   without seeing which account or club will own it.

### Troubleshooting cues

- `401 INVALID_CREDENTIALS` means the password matched none of the identity's membership rows.
- `403 PASSWORD_RESET_REQUIRED` means it matched only part of a legacy multi-membership identity; the user must complete the emailed reset before login.
- `403 PENDING_APPROVAL` means the email invitation exists but has not been accepted.
- `409 ACTIVE_SESSION_EXISTS` means the same identity is already signed in on web or mobile. Continuing revokes that previous device session.
- web and iOS call `GET /session/status` while active and on foreground/focus; `SESSION_REPLACED` clears local state and returns the displaced client to login. Network failures do not clear an offline session.
- if refresh briefly shows the login form, confirm `ProtectedRoute` is waiting for `restoringSession` rather than redirecting while the initial status request is pending
- authentication logs use masked identifiers such as `p***@example.com`; raw login emails must not be written to CloudWatch

The SAM deployment runs `configure_log_retention` as a CloudFormation custom resource after resolving every Lambda function name. It ensures each `/aws/lambda/<function-name>` group exists and applies the configured 60-day retention policy. A daily scheduled run reapplies the policy to stack-prefixed Lambda groups so later-created or manually altered groups do not remain indefinitely.

## 2. Root-Admin Login Flow

### Frontend entry

- [frontend/src/pages/RootAdminLoginPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/RootAdminLoginPage.jsx)
- [frontend/src/context/RootAdminContext.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/context/RootAdminContext.jsx)

### Current path

1. The root admin submits username and password plus the client-side human-check.
2. The frontend calls `POST /root_admin/login`.
3. [backend/functions/root_admin_login/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/root_admin_login/handler.py) verifies credentials against `SkRootAdmin`.
4. The backend revokes older sessions for the same root-admin account and creates an eight-hour session in `root_admin_sessions`.
5. The API sets the separate `__Host-hitnscore_root_admin` HttpOnly cookie and returns identity, expiry and a non-authenticating CSRF value; only the opaque cookie token's SHA-256 hash is stored.
6. The frontend keeps CSRF in memory and restores identity through `GET /root_admin/session/status`; it stores no Root Admin authentication token. The Ground Control keeps the current URL and shows the branded session loader until restoration finishes.
7. Each root-admin handler validates the cookie, expiry, revocation state and current `SkRootAdmin` identity; mutations additionally validate exact Origin and `X-CSRF-Token`.
8. Logout calls `POST /root_admin/logout`, revokes the database session and expires the cookie.

The dashboard’s Club Admin Memberships count comes from non-personal organisation membership rows with the admin role. Platform root-admin accounts are separate. Database operators rotate their passwords with [rotate-root-admin-password.sql](../scripts/rotate-root-admin-password.sql), which also revokes existing root-admin sessions. The root-admin User Accounts directory derives each identity's latest login from `MAX(org_user_sessions.created_at)` and offers 12- and 24-month inactivity cards. For a user with no session history, registration time is the inactivity reference; these cards are review filters and do not trigger deletion.

## 3. Personal Signup and Club-Enquiry Flow

The end-to-end entry, email, activation, login and first-match paths are shown
in [new-user-onboarding-walkthrough.md](/Users/glennrowe/Development/Projects/RcktScore/docs/new-user-onboarding-walkthrough.md).

### Frontend entry

- [frontend/src/pages/LoginPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/LoginPage.jsx)

### Public registration flag

Ground Control's flag opens Public Registration. The administrator saves the
Enable new users switch and the message shown while registration is paused.
The landing site's Start Scoring buttons check the uncached status through a
CloudFront route. In red mode the dialog links to the same form that opens
from Want In on the app login page. The form stores the person's details
and emails the team after a server-validated math question. Existing users
can sign in directly or through the dialog. Native clients receive the
configured pause message if they attempt public signup.

### Green registration flow

1. A visitor opens the `Want In` form on the login page.
   - both the standard web login and registration states omit internal package-version/build details
   - the login logo and HitnScore wordmark return to `https://www.hitnscore.com/`
   - the native form is a non-scrolling, centred card on iPhone and iPad with the compact mascot and contiguous branded `HitnScore` wordmark, the two-line welcome, and one `Create Account` action; Want In and Need Help remain side by side on the login card
   - the web login mirrors that entry pattern: Want In and Need Help are side by side, each opens a card over the login card, and an untouched card closes after 15 seconds. Editing the Want In form cancels its idle dismissal so registration data is retained. Need Help offers Ping Us, Guides and Password Reset, routing to `/ping`, `/help` and `/help?mode=reset` respectively
2. The frontend submits `first_name`, `surname`, `email`, and `use_type`.
3. The honeypot field is `company`.
4. [backend/functions/register_interest/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/register_interest/handler.py):
   - validates the payload
   - writes or updates `HitnScoreInterestRequests`
   - for Personal, rejects an existing Personal membership for the normalized email with `ACCOUNT_ALREADY_REGISTERED`, otherwise records the self-service registration, commits the pending `personal_free` organisation, owner membership, personal court, and password token, then sends a `mode=confirm-email` password-setup email without entering an admin approval queue. Club-associated identities already own Personal because Personal is now the required base account
   - for an unauthenticated Club selection, creates the required Personal Free base account when one does not already exist, keeps the club request pending, adds a private controlled-release club-interest message to that identity's inbox, and sends confirmation/admin enquiry emails; the requester copy renders only supplied optional fields while the admin copy retains all fields
   - for a logged-in native Club Essentials or Club Pro enquiry, validates the bearer session, derives the requester email from it, and stores the club name, address/postcode, club email, website, telephone, and requested plan for root-admin review
5. Personal signup returns `201` with `data.account_created = true`; the user verifies their email and chooses a password before signing in.
6. A first-time public Club enquiry returns `201` with the newly created Personal account; an enquiry from an existing or authenticated identity returns `202`. The club subscription itself remains controlled by the root-admin workflow.
7. In the native iOS client, a successful response replaces the submitted form with a confirmation screen. Personal registration explains that the emailed link verifies the address and sets the password; club registration also points to the private controlled-release update that appears in Messages after sign-in.

### Troubleshooting cues

- missing interest-request table returns `INTEREST_REQUESTS_TABLE_MISSING`
- missing `PASSWORD_RESET_BASE_URL` returns `PERSONAL_SIGNUP_CONFIGURATION_ERROR`
- personal setup email issues return `PERSONAL_SIGNUP_EMAIL_FAILED`
- club enquiry email issues return `INTEREST_EMAIL_FAILED`

## 4. Password Reset Flow

### Frontend entry

- [frontend/src/pages/HelpPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/HelpPage.jsx)

The app `/help` route is also the public Help Centre. Its overview is a search-free Guides library divided into Getting started, Accounts & access, Matches & scoring, Live sharing & displays, and Insights/tournaments/settings. The guide definitions live in `frontend/src/content/helpGuides.jsx` and cover the web client, native iOS, Android web-client status, Personal/Personal Plus, club roles/admin, setup/scoring, scheduling/history, score viewing/displays, Analytics, tournaments, settings/security, notifications and offline boundaries. Every guide is addressable through `?section=<guide-id>`; legal links retain `terms`, `privacy` and `cookies`. Password recovery uses `?mode=reset`, while Personal email setup uses `?mode=confirm-email`. Both token pages validate the link with `POST /password_reset/validate` before enabling the form. The public landing footer points to this route and its privacy/cookie sections, so `weblanding/` does not carry a separate Help page. `components/PublicSiteFooter.jsx` is the reusable React template for the complete public-homepage footer. The Help Centre renders that component rather than maintaining page-specific footer markup.

### Current path

1. A signed-out user opens `/help`, or uses the password-reset entry on native iOS.
2. The web or native request form calls `POST /password_reset/request`.
3. [backend/functions/password_reset_request/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/password_reset_request/handler.py) delegates to `password_reset_logic.py`.
4. The reset link base URL comes from:
   - `PASSWORD_RESET_BASE_URL`, then
   - request `Origin`
5. The emailed link returns to `/help?mode=reset&token=...` (or `mode=confirm-email` for first-account setup).
6. `frontend/public/.well-known/apple-app-site-association` associates only those two token-bearing `/help` modes with the iOS bundle. When the app is installed, `RcktScoreMobileApp` passes the Universal Link to `AppContainer` and presents `PasswordSetupView`; without the app, the same URL continues to the React Help Centre. The native login reset card also accepts a pasted complete link, query string or bare token. The production association and native reset-screen handoff were verified on a physical iPhone with the current TestFlight build on 9 November 2026.
7. The token is checked with unauthenticated `POST /password_reset/validate`; the native or web confirm form calls unauthenticated `POST /password_reset/confirm`.
8. iOS, the browser and the backend require eight or more characters, one uppercase letter, one number, one symbol and no configured common password term. Web success redirects to login after three seconds. Native success presents a sign-in action; an ordinary reset also removes the now-revoked normal and biometric device session, while first-account setup leaves any unrelated signed-in identity intact.

### Troubleshooting cues

- if reset emails are not arriving, check SES sender configuration and `PASSWORD_RESET_FROM_EMAIL`
- if links point to the wrong frontend host, check `PASSWORD_RESET_BASE_URL` and request `Origin`
- if a reset link opens Safari instead of the installed iOS app, verify the signed build contains the `applinks:app.hitnscore.com` entitlement and that `https://app.hitnscore.com/.well-known/apple-app-site-association` serves the checked-in JSON directly with a successful response, `application/json`, the production app ID and no redirect. After correcting the file, delete the app, restart the iPhone, reinstall the latest TestFlight build, open and close it once, request a fresh reset email and tap the complete link directly in Apple Mail. This sequence cleared the stale association and opened the native password screen during the 9 November 2026 production verification
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
   - `analytics_period_days` (`0` for all time, otherwise capped at 3650 days)
3. [backend/functions/get_dashboard/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/get_dashboard/handler.py) authorizes the org-user session.
4. [backend/common/dashboard_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/dashboard_logic.py):
   - loads organisation summary
   - loads active matches
   - loads scheduled matches for clubs
   - loads completed match history
   - applies personal-plan history limits
   - returns a redacted 26th history teaser for Personal Free when older matches exist
   - aggregates App analytics from match rows and event payloads for the requested rolling period, including duration, heatmap, trend, format/rule, competitiveness, point and participant measures
   - derives signed-in Player usage by exact profile-name participation
   - returns aggregate court/demand/peak-time/setup-adoption Club analytics for every authorised club role and subscription tier
   - derives Personal Plus performance statistics from completed match state and event actions
5. The API returns `data.dashboard`.
6. The page renders screen-mode-specific views for dashboard, matches, history, or Analytics. Dashboard Recent Matches retains at most 24 client-side preview records and paginates six cards at a time, giving three complete two-card rows on wide screens. The Active Matches, Scheduled Matches and Recent Matches heading text opens the corresponding Current, Scheduled or History tab on the Matches screen. Those tabs use the same white, blue and light-blue visual language as organisation Settings. For feature-enabled clubs, the dashboard then reads the existing tournament list and shows only `draw_published` events in an icon-labelled Live Tournaments panel below Recent Matches. Matches History paginates 20 cards at a time, giving exactly ten two-card rows on wide screens; the alternate mobile list is hidden there so it cannot duplicate those cards as full-width rows. While History is selected, its page root keeps the shared header in normal flow so header actions cannot cover the search, filter or match-card actions during phone/tablet scrolling. Matches provides Current, Scheduled and History tabs for every tier, with a Personal Free scheduling upgrade gate. Personal Plus Current Matches also accepts a match viewing code and lists its saved Viewed Matches. Web and iOS Analytics expose Personal and, while a club context is active, Club sections. Personal Free receives basic app usage and setup-abandonment reporting; Personal Plus adds player/game analytics and CSV export. Club reporting is available to every club tier and authorised role, covers aggregate match/setup adoption, court demand, peak/off-peak and simultaneous use, schedules, sport trends and a digest, and exports aggregate CSV without user or player personal details. Wide heatmaps and tables scroll inside their panels rather than widening the tablet portrait page.
7. On web, both the dashboard Start New Match action and the signed-in header `+` route through the same dashboard sport-selection overlay; selecting a sport continues to `/match/new/setup?sport=...`. The standalone `/match/new` route presents the same enabled-sport set in an iOS-style centred two-column grid, reusing the native transparent ball images and court diagrams. Further implemented sports naturally add new grid rows. This route suppresses `ClubPageHeader`'s native-style bottom navigation and provides its own Close action, preventing navigation from covering the final sport card. Native Android and iOS instead place Play immediately after Home in the bottom navigation; it opens their existing new-match flow and replaces the former dashboard start banner.
8. `GET /get_score/{match_id}` rejects completed Personal Free matches outside the latest-25 window, preventing direct URL access from bypassing the entitlement.

### Troubleshooting cues

- empty match lists can be valid if the `matches` tables are missing or empty
- Personal Free intentionally returns 25 readable history records plus an optional locked teaser as card 26; web, iOS, and Android Home show three readable records plus that teaser, while Personal Plus requests expanded history
- performance matches are attributed only when the registered first name and surname exactly match one recorded participant

## 6. Organisation Settings Flow

### Frontend entry

- [frontend/src/pages/ProfilePage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/ProfilePage.jsx)
- [frontend/src/pages/OrganisationSettingsPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/OrganisationSettingsPage.jsx)

### Current path

1. The page calls `GET /organization_settings/{organization_id}`. Club admins receive the editable organisation experience. Non-admin club members remain on `/settings` in the existing view-only presentation rather than being redirected to the dashboard; all mutation controls stay disabled and backend write authorization is unchanged.
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
   - a frontend-only club Subscriptions preview
   - scaffold-only social profile fields under Organisation
5. For club admins, Address follows Club Name and Primary Contact is chosen from the approved users returned in the same response rather than entered as arbitrary text. The single-row, horizontally scrollable section control follows the Matches segmented style and scrolls its selected section into the visible centre on narrow screens and direct `?tab=` navigation. Users and Courts show compact rows first, use a circular `+` to reveal an add form before the corresponding search/filter control, and expose editing only for the selected row; court editing includes its scoreboard URL and display-code controls. Users retain local first-name/surname/email search and surname sorting, plus compact role/approval/edit indicators. Both add forms reset their inactivity timer during editing and collapse after one inactive minute or when the user changes Settings section.
6. Game Settings uses separate Racket Sports and Default Timers tiles. These retain the existing organisation-details persistence routes and only change the client presentation.
7. Subscriptions shows the current club plan, monthly/annual presentation, Club Essentials/Club Pro comparison and a disabled checkout review. It is an experience prototype only: it does not load Stripe, create a checkout session, update a subscription or change an entitlement, and undecided pricing and Club Pro details are explicitly marked to be confirmed.

### Current limitation

Social-profile fields and the web Subscriptions payment experience are still UI scaffolds and are not persisted/enforced. There is intentionally no organisation-level handicap setting: Squash/Racketball handicap scoring is available to Personal Free, Personal Plus, and club accounts.

## 7. Personal Profile Update Flow

### Frontend entry

- [frontend/src/pages/OrganisationSettingsPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/OrganisationSettingsPage.jsx)

### Current path

1. Any approved signed-in user can edit their web profile from the personal Profile section in Settings; the legacy `/profile` route remains supported for direct navigation, and iOS has its native profile screen. The personal Settings sections remain in one natively swipeable horizontal row. When that row overflows on a phone, borderless transparent-background 44-point-or-larger previous/next controls overlay the inside edges of the menu bar, show only in directions that contain hidden sections, move to the next concealed section, and update after swipe, selection, or resize.
2. The frontend or iOS app calls `PUT /personal_profile/{organization_id}` with first name, surname, email, telephone, country, optional city, and optional birth month/year fields. Migration `054_optional_birth_month_year.sql` supplies the nullable range-checked columns; no birth day is collected.
3. [backend/functions/update_personal_profile/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/update_personal_profile/handler.py) authorizes the presented org-user session for that organisation and uses the session username as the source of truth.
4. Shared logic updates the linked `SkwshOrgUsers` rows for that account. If the email changes, it also updates the login username and revokes active sessions so the user must sign in again.
5. The API returns updated `organizationSettings`.

## Tournament Manager Foundation Flow

1. Root admin opens an existing club, selects the dedicated Tournament tab after
   Game Settings, and enables Web Tournament Manager.
2. `PUT /root_admin/organizations/{organization_id}/tournament-feature` validates
   the root-admin session and upserts `tournament_organization_features`.
3. Organisation settings return
   `organization.features.tournament_manager.web_enabled`.
4. The signed-in web header shows a Tournament button to every member of an
   enabled club, and the dashboard shows its published tournaments beneath Recent
   Matches. The Live Tournaments heading opens Tournament Manager without a separate
   View all action. The club Settings page also shows its administrator entry point; the
   backend repeats the same feature check on every tournament request.
   Native iOS also reads the feature through every retained club association. If
   at least one club is enabled, the bottom navigation replaces Need Help with
   Tournament between Analytics and Settings. Its landing page combines only
   `registration`, `draw_published`, and `in_progress` events from enabled clubs;
   Help & Feedback remains available from Settings.
5. The unauthenticated Tournament Draw lookup and Scoreboard Display entry use the same permanently compact, full-width public header and compact key/code card. Tournament Draw calculates that full width from its page shell rather than `100vw`, so browser scrollbar geometry cannot widen the document. The scoreboard card is centred in the available space below its header. Their logo links to the public landing page, their small product label sits beneath the HitnScore wordmark in a crisp lightweight system font, and the header contains no page-description copy.
5. A club admin expands the New Tournament heading and creates a draft through
   `POST /organizations/{organization_id}/tournaments`, classifying it as internal
   or open and optionally enabling A–D grading or an entry-size limit. Creation
   writes four A–D `tournament_draws` groups for a graded event, or one Open Draw
   for an ungraded event. The create form starts collapsed and collapses again after
   five minutes only while it remains untouched.
6. Before manual entry, the web client searches canonical accounts and reusable
   players through `GET /organizations/{organization_id}/tournament-players?q=...`.
7. Adding an entry looks for a registered account with the supplied email, reuses
   the canonical `users` identity and an existing `players` identity when the
   email is already known, and
   otherwise creates an unclaimed or claimable player.
8. `player_organization_affiliations` records `member` when that account is an
   approved member of the host club and `guest` otherwise. Guest status grants no
   login or club permissions; internal events reject guest entries.
9. Every entrant receives a four-level organiser assessment. Level 1 is Grade A,
   level 2 Grade B, level 3 Grade C and level 4 Grade D.
10. The tournament entry stores a name/club snapshot so later profile edits cannot
    rewrite the historic event entry.
11. Every tournament and entry creation writes `tournament_audit_events`.
12. A club admin assigns optional unique seeds and calls
    `POST /tournaments/{tournament_id}/draw`. The backend deterministically
    shuffles unseeded entrants, separates seeds across a power-of-two bracket,
    gives top seeds non-power-of-two byes and stores a draft in
    `tournament_matches`. The organiser reviews a horizontal championship/plate
    brace and may swap first-round slots before publishing. Monrad generation
    instead stores the full classification tree: each round has one fixture for
    every original first-round pairing, with winners and losers routed into
    progressively narrower placement bands until the final placing matches.
13. `POST /tournaments/{tournament_id}/draw/publish` locks entries, enables a
    12-character public key and exposes the sanitized read-only draw through
    `GET /public/tournament-draws/{access_key}` without login. Returning to draft
    disables that key and is blocked after results start. The web client presents
    a generated, unpublished draft as **Draw ready** and `draw_published` as
    **Live**. Legacy status-only events expose **Rebuild Missing Draw**.
14. The selected tournament uses a full-width summary card whose tournament-name
    heading expands or collapses its metadata. There is no separate View tournament
    details action. A Draw/Entrants segmented control keeps bracket work separate
    from player management. For a live draw the expanded summary also contains the
    public-access switch and confirmation-protected return-to-draft edit control.
    Disabling public access leaves the internal draw Live but makes its
    no-login key unavailable immediately.
15. On a live draw, fixture actions appear only when both player slots contain
    real entrants. Any approved club member can create a standard scheduled scoring
    match or enter the completed score; correcting an entered result remains
    club-admin-only.
16. Scheduled scoring matches store the tournament event, fixture and tournament
    name. A sport-engine final point records a played tournament result and may
    advance the winner. An operator end or 12-hour stale close instead moves the
    fixture to `awaiting_resolution`; it cannot infer a winner from the partial
    score. A club admin must resolve it as played, retired, conceded, walkover or
    abandoned. Abandoned fixtures advance nobody. Knockout winners advance to
    their next fixture, and first-round losers enter the plate for
    knockout-with-plate events. Monrad sends both players to the next round:
    winners remain in the upper half of their current placement band and losers
    enter its lower half, ending with 1st–2nd, 3rd–4th and subsequent placement
    matches. The signed-in and public read-only web views show those bands as
    Last N, Quarters, Semis, Finals and a finishing-position column where applicable.
    An older published knockout containing only
    opening-round rows backfills its remaining tree on first result.

The web entrant importer accepts CSV files with required First Name/Surname and
optional Email, Club and Ability columns. It previews invalid and duplicate rows,
checks exact matches against both current entries and the shared player search,
and lets the organiser skip, reuse, replace or update as appropriate. Updates use
`PUT /tournaments/{tournament_id}/entries/{entry_id}` and write an audit event.
Linked account email and home-club values are locked; unlinked player records can
be completed before they are claimed.
Compact entry cards put a small edit gear at the top right and group grade, seed,
linked-account and host-club-member indicators beneath the club details. Linked
means that the reusable player identity belongs to a registered HitNScore account;
it does not grant a plan, role or club access. Published list entries use a green
Live badge in the client.

Ordinary club members may list/read tournaments and schedule or score ready live
fixtures. Creation, entry changes, draw changes and result corrections remain
restricted to club administrators.

Tournament detail reads use `to_regclass` before querying `tournament_draws` or
`tournament_matches`, so
an existing event remains readable during a staggered schema deployment. The
fallback only supplies display labels; migration `032` remains required for
persisted draw groups and new-event creation. Migration `034` is required to
generate fixtures, migration `035` supplies publication keys and seed uniqueness,
and migration `036` supplies bracket/result/scoring-link fields. Migration `041`
adds explicit early-result outcomes and the awaiting-resolution/abandoned states.

The seeded Demo Club has the feature enabled. Its approved
`demouser@democlub.com` login is intentionally password-disabled until root admin
sets a password through the existing User Accounts control.
Migration `033_demo_club_players.sql` adds eight similarly password-disabled
Demo Club user memberships named Demo PlayOne through Demo PlayEight for entrant
search and import testing.

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

Before a new club membership is inserted, `ensure_personal_account_for_identity(...)` creates Personal Free when the normalized email does not already own Personal/Personal Plus. A brand-new invite uses the same setup token for its Personal owner membership and requested club association, so choosing a password activates the linked account model in one flow. Existing identities retain their Personal plan and simply gain another pending club association. Migration `047_personal_account_for_every_identity.sql` applies the same model to historical club-only rows and enforces it with a deferred constraint trigger.

### Edit or remove user

1. The organisation user details page submits an update or delete action.
2. The frontend calls:
   - `PUT /organization_users/{user_id}`, or
   - `DELETE /organization_users/{user_id}`
3. Shared logic in `organization_logic.py`:
   - validates updated email and role and rejects membership-scoped password fields
   - directs administrators to send the member an identity-wide reset link
   - revokes active sessions when a user email changes or when the membership is deleted; reset confirmation and the root-admin identity password control revoke sessions after updating every membership
   - blocks demoting or deleting the last remaining admin in the organisation

### Approve invite

1. The invited user opens the email link.
2. `GET /organization_users/approve?token=...` runs.
3. The Lambda updates the membership to approved and returns an HTML page.
4. If `USER_APPROVAL_LOGIN_URL` is configured, the success page stays visible for three seconds and then redirects to sign in.

### Troubleshooting cues

- a user may exist in multiple organisations but has one identity-wide password
- new identities choose that password through their invitation; club admins cannot choose or edit it
- login remains blocked until approval is accepted
- the approval route returns HTML, not JSON
- `USER_APPROVAL_BASE_URL` controls the branded approval-link host/path used in invitation emails

## 9. Court Flow

### Current path

1. Web and iOS show compact court rows, filter them by an enabled racket sport, and expand only the selected add/edit form. Each row shows its controlled court number, editable court name, scoreboard code, edit action and QR scoreboard-pairing action. Existing courts whose sport is null are treated as legacy all-sport courts.
2. The backend authorizes the user as an org admin for normal club use.
3. For a new or renumbered court, `court_name` stores the controlled number and `court_alias` stores the customer-facing name. Club Essentials offers `Court-1`–`Court-5` per sport and Club Pro offers `Court-1`–`Court-25`; the name initially follows the number but can be changed independently. Shared logic normalizes the number, enforces the plan range and rejects duplicates within the same organisation/sport. A future unrestricted/Premium plan uses a free-text number. Migration `037_court_sports.sql` adds the nullable validated `sport` column. Match creation verifies that an assigned court belongs to the tenant and, when it has a sport, that it matches the requested match sport.
4. The API returns `data.court` or `data.deleted`.

### Root-admin note

The root-admin club page marks these shared calls as root-admin requests in the API client. The browser sends the separate Root Admin HttpOnly cookie and `X-HitnScore-Session: root_admin` selects that cookie when an ordinary user cookie also exists. The selector grants no privilege; the backend validates the Root Admin database session before permitting access.

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

On web and iOS club setup, the `Me` referee switch fills the referee
field from the authenticated profile. Each client disables and clears that
switch if the same full name is entered as any singles or doubles participant,
and prevents the conflicting payload from being submitted. Web additionally
exposes that identity in a hover/focus overlay. This is client-side validation
over the existing `referee_name` field and does not add a lookup or match-create
route.

## 11. Match Creation Flow

The React tennis setup mirrors the native lineup contract through a named Singles/Doubles switch,
four named doubles participants with adjacent colour-only shirt controls, Golden Point, an
optional final-set 10-point match tiebreak, and timed 90-second odd-game
changeovers plus 120-second set breaks. Before play begins, singles asks only for
the named opening server and derives the receiver as the other player. Doubles
asks for both and submits the participant IDs, alternating serve order, and
Deuce-court receiver map used by the native client.
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
server and receiver, Right/Left service side, completed sets, point timeline and final
result. It intentionally omits Stroke, Let and manual service-box controls.
The live-match shared header omits redundant description copy, standard scoring
is presented as `Standard advantage scoring`, and the opening-order confirmation
uses the same branded primary action treatment as the rest of the web client.
The tennis format heading also names the physical venue court. Game Settings
keeps each shirt palette collapsed behind its current colour, contains the
existing club spectator URL/display code, and shares the live screen with a
dedicated Undo icon beside Game Settings. Match Actions contains named No Let,
Yes Let and Stroke choices for Squash/Racketball, plus a separately confirmed
End Match Early action. Early completion requires the operator to record Player
1, Player 2, or draw/no winner; the selected result is sent through the existing
`POST /end_match` route as `winner_side`. Natural and early completion replace
the live board with a result/game-duration summary, adding server points won and
serves lost for Personal Plus from the point-time server event stream.
`MatchScreen.jsx` retains shared loading, mutation, undo, match timer and network
plumbing and starts a 90-second break only after an odd completed game, or a
120-second break after a completed set, when `tennis_timed_breaks` is enabled.
It forces the shared signed-in header into its compact form throughout active
scoring. The signed-in web context trigger shows only Personal or the active
club name, with no generic Account prefix. Phone portrait hides the HitnScore
wordmark while retaining the mascot icon, Messages and that context trigger.
Signed-in phone-landscape pages from 480–956 CSS pixels wide and 280–499 pixels
high, covering iPhone SE through iPhone Pro Max, use the same icon-only branding
in a single shallow header row with icon-only navigation, Messages and the
context control, with compact dashboard actions/cards and no floating
mobile navigation control. Active scoring then hides the navigation icons to
give the board maximum height while retaining the mascot icon.
The shared Start New Match chooser also switches to a landscape grid: its title
and context selector share the top row and all four implemented sports use one
compact row beneath it. The overlay and standalone selector therefore fit
without scrolling from iPhone SE through Pro Max landscape dimensions.
In phone portrait the same overlay remains centred within the backdrop, uses
more of the available screen area, aligns the context selector to the sport-grid
edges and pins its standard circular close button to the overlay's top-right
above the context selector. Phone landscape keeps the close button immediately
to the context selector's right within the compact top row.

The public login uses the same 480–956 by 280–499 phone-landscape boundary. Its
collapsed sign-in state places compact branding on the left and the complete
Username, Password, Sign In, Want In and Need Help flow on the right, without
document scrolling. Want In and Need Help open as internally scrollable cards
over the existing login card, preserving the compact landscape shell. Both
untouched cards close after 15 seconds; an edited Want In form stays open. The
Need Help card presents Ping Us, Guides and Password Reset and then hands off to
the existing public destinations.

Phone and portrait-tablet signed-in pages use a persistent bottom navigation for
Home, Play, Matches, Analytics, Settings and Help instead of a floating hamburger
and modal sheet. Play sits immediately after Home, opens the existing match
selector and replaces the large dashboard Start New Match banner at these sizes;
view-only members omit it. The active item uses the same blue/pink visual language
as the native clients. Active scoring and the standalone sport chooser omit the
bar. At tablet dimensions from 600–1400 CSS pixels wide and at least
500 pixels high, ordinary signed-in page shells use the viewport with 16-pixel
side margins, allowing Settings and other panels to fill iPad and Android tablet
portrait or landscape screens.

Tablet landscape viewports from 720–1400 pixels wide and 500–1024 pixels high retain
the compact navigation header. Both use a fixed dynamic-viewport shell instead
of document scrolling: the score controls and timer remain visible, the
Squash/Racketball point rail scrolls internally, and Tennis/Padel place their
internally scrolling point timeline beside the score board. Dashboard return is
removed from live scoring, while non-scoring detail panels and the footer are
hidden in both constrained live-scoring layouts. Fresh web
Squash/Racketball matches now require the same opening-server confirmation even
when optional timing is disabled.
Migration `039_match_timed_breaks.sql` adds this per-match flag; it is separate
from the setup default stored by migration `029_timed_break_defaults.sql`.
Every web scoring mutation also sends a client-generated UUID through the
existing `client_action_id` contract so a retried browser request cannot apply
the same action twice.

### Frontend entry

- [frontend/src/pages/NewMatch.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/NewMatch.jsx)
- [frontend/src/context/MatchContext.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/context/MatchContext.jsx)
- [mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/StartNewMatchView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/StartNewMatchView.swift)

### Current path

1. The operator submits player, court, referee, sport, score type, best-of, optional handicap data, Golden Point, and the per-match timing choice. On web, Squash/Racketball handicap is presented inside the same compact rules card as the other per-match switches. Web and iOS initialise timing from `organization.timed_break_defaults` for the selected sport, but the operator may override it before starting.
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
The native scheduled list keeps each row compact: court and format appear once,
the two player names share one line, and circular pencil/play icons replace the
former Edit/Start labels. It does not show readiness copy or the creation time.

### Personal Plus remote viewing

1. An authenticated scorer opens live Game Settings. `GET /match_display_access/{match_id}` creates or returns the match's eight-character `viewer_code`.
2. A Personal Plus user enters that code from Matches on web or iOS. The client calls `POST /match_watch/lookup` with its own organisation ID and the code.
3. The backend authenticates that personal membership, verifies its current plan is `personal_plus`, resolves the code globally, and returns a read-only serialized match. This deliberately does not grant access to any scoring mutation.
4. Both clients refresh the lookup every five seconds while the match is active. Once complete, the same response sets `finished` and supplies the retained result and event timeline.
5. `POST /match_watch/save` idempotently links that match to the viewer's personal organisation. `GET /dashboard/{organization_id}` then returns it in `viewed_matches` across web and iOS.

The native completed-match screen opens with Match Information collapsed. Its
point timeline shows `Point`, `Stroke`, or `Let` followed by one normalized
player name, renders markers only on the awarded player's side, and uses tight
row spacing so substantially more events fit before scrolling.
6. Migration `038_personal_plus_match_watch.sql` supplies `matches.viewer_code` and `match_view_profiles` and must be applied before deploying the new endpoints.

## 12. Match Load and Scoring Flow

### Frontend entry

- [frontend/src/pages/MatchScreen.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/MatchScreen.jsx)
- [frontend/src/components/MatchControls.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/components/MatchControls.jsx)
- [mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/MatchScoringView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/MatchScoringView.swift)

### Current path

1. The page loads `GET /get_score/{match_id}`.
2. The backend authorizes access to the match tenant and returns `scoring_access`. A club match is locked to the membership that created or activated it; another scorer receives a read-only client state and `409 MATCH_SCORER_LOCKED` from every mutation. A club admin must explicitly call `POST /matches/{match_id}/scorer-lock/takeover`, which transfers ownership and appends an audit row before that admin may score. Legacy active club matches without an owner are atomically claimed by their first authorised post-deployment mutation. Personal matches are unchanged.
3. Shared logic loads `matches` plus `match_events`, then dispatches serialization through the sport engine for that match.
4. Live state is rebuilt from the event stream.
5. Operator actions call:
   - `POST /score_point`
   - `POST /event_action`
   - `POST /undo_action`
   - `POST /end_match`
6. Native iOS supplies a stable `client_action_id` UUID for each queued mutation. `match_action_receipts` claims that UUID before the mutation so reconnect retries cannot duplicate a point or other action.
7. Shared logic opens the mutation by locking the `matches` row with `SELECT ... FOR UPDATE`, then rebuilds and changes state through the active sport engine. This serialises distinct taps or devices for the same match instead of allowing both to derive a transition from the same event history.
8. The action receipt, event or undo, derived match summary, and any completed tournament-fixture result remain in that transaction until one final commit. An exception rolls all of them back. Database-generated `match_events.event_sequence` is the canonical replay order. Undo selects only an effective engine-approved scoring event, appends an authenticated `undo` event plus compensation links for the score and later completion timer, and leaves the original rows immutable. Effective replay hides both the compensated records and audit-only Undo event. During a staggered deployment, read-only match lists retry with legacy `created_at, id` ordering if migration 042 is absent; scoring and Undo do not use this compatibility path. Completed tournament-linked matches refuse Undo after bracket progression. A completion-timer request that loses the race with Undo sees the newly active match under the same row lock and returns without appending stale duration data.
9. The web frontend updates local match state from the returned `data.match`. Native iOS and Android disable points, actions, timers and settings when `scoring_access.can_score` is false; an eligible admin receives an explicit takeover action. Native offline queues also check the lock before accepting a new local mutation, while the backend remains authoritative for stale or older clients. Native iOS caches the last server match, applies permitted queued actions locally, and adopts each ordered server response during synchronisation. The queue re-reads its latest snapshot around every request so a timer or scoring action added during an in-flight request cannot be overwritten.

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

- undo compensates the latest effective score event (`score_point`, or `stroke` for Squash/Racketball), not timer/settings/let/service metadata; the original score and a completion timer written after it remain in the append-only audit stream but are excluded from effective replay so the resumed match can record a fresh duration
- `stroke` is score-aware and can end a game or match
- shirt-colour changes are accepted for personal-free, personal-plus, and club accounts

## 13. Display Screen Flow

### Frontend entry

- [frontend/src/pages/DisplayScreen.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/DisplayScreen.jsx)

### Current path

1. An unpaired `/scoreboard` creates a two-minute public pairing request and displays its one-time token as a QR code. Manual court display-code entry remains available.
2. A signed-in club administrator opens Club Settings → Courts in iOS or Android, chooses the intended court and scans the QR. The authenticated approval route verifies the admin membership and that the court belongs to that tenant.
3. The scoreboard polls the one-time exchange route. After approval, the backend consumes the request atomically and returns the same read-only, court-scoped 24-hour display session used by manual code entry. The QR never carries the permanent display code or resulting session token.
4. The display loads the active court match and polls `GET /scoreboard_display/current` every five seconds. It renders a read-only scoreboard and optional event timeline. Standard layout sizes the court name to the game-details text (0.8rem), keeps header/history rows content-sized, and gives score cards the remaining height with point scores scaled to viewport width and height, up to 24rem, so the numbers dominate the cards.

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
The Ground Control Users directory sorts the full filtered response by latest login or username before displaying 25, 100 or 200 rows. Profile tabs share a navigation strip with the username and a back arrow to Users.

2. Every root-admin route validates the separate cookie session against `root_admin_sessions`; mutations additionally require Root Admin CSRF validation.
3. Club-detail calls to shared organisation endpoints accept root access only after the same session validation succeeds.
4. The platform dashboard now also links to a root-admin match directory that calls `GET /root_admin/matches` and can archive or delete matches across the system.
5. Match archive is implemented as a flag on `matches`, so archived matches drop out of standard dashboard/history lists without deleting the underlying row.
6. The platform dashboard links to a root-admin `RacketSports` page that manages separate web and iOS availability lists. Its primary save changes only the platform gate and does not grant the sport to organisations or users. `POST /root_admin/platform_sports/preview` lists every user and membership that the separate optional bulk action would affect without writing data; that bulk action requires confirmation and signs out active users. User Account profiles assign either client independently, and personal-account assignments maintain their personal organisation umbrella automatically; club users remain capped by club settings.
7. `GET /root_admin/users` groups membership rows by username and supports Personal Free, Personal Plus, club, unverified-user, inactivity and Delete Pending filters plus username/name search. Delete Pending is derived from the Personal organisation's deletion timestamps and shows the scheduled 12-month clearing date while retaining the profile for inspection.
8. `GET /root_admin/users/{user_id}` returns registration details, email-verification state, last session activity, personal and club associations, per-client enabled sports, and attributable scoring activity. The Settings tab calls `PUT /root_admin/users/{user_id}/memberships/{membership_id}/sport-access` for independent web/iOS access. Updating access revokes the user's active sessions. Email verification, password replacement, subscription changes, club invitations, and association removal remain separate actions.
9. Personal registrations do not appear in `GET /root_admin/interest_requests`; that queue now contains club enquiries only.

### Remaining hardening

The root-admin trust boundary is now enforced. Rate limiting, richer security audit events, and operational session-management tooling remain launch-hardening work.

## 15. Native iOS Flow

### Current path

1. [ContentView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/ContentView.swift) routes the app to `LoginView` or `DashboardView` based on the persisted `SessionStore`, but clears the saved session and requires fresh credentials once `session_expires_at` is reached.
2. [LoginView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/LoginView.swift) calls `POST /login` with `client_type = mobile_app`, handles `ACTIVE_SESSION_EXISTS`, exposes a local show/hide password control, and branches between `data.session` and the retained legacy `data.organizationSelection`. Under the default identity-first backend setting, multi-membership users enter the preferred personal/first-club session directly; the native account picker appears only when the backend deployment switch restores legacy selection. First-time sign-in requires connectivity, and the login card displays an offline explanation when no network is available.
3. [DashboardView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/DashboardView.swift) loads `GET /dashboard/{organization_id}`. Personal Free and Personal Plus both present `Home`, `Matches`, `Analytics`, `Settings`, and `Need Help`. Matches uses a Current / Scheduled / History selector; Personal Free retains 25 readable history records with the upgrade prompt as card 26 and an upgrade-gated Scheduled view, while Home stays compact with three readable matches followed by the upgrade prompt. Personal Plus can create and list scheduled personal matches, enter a remote viewing code, and reopen its saved Viewed Matches. Analytics always includes scored-match Stats and adds Personal reporting for Personal Plus. The compact native header renders only the mascot at the left and places Messages directly beside a prefix-free active-context menu at the right; the former wordmark and separate Context row are absent. The Messages control becomes an offline indicator while disconnected and glows yellow while an online message is unread. A cached active match can be reopened from the active-match section.
4. The native settings flow in `DashboardView.swift` follows Android's personal-first hierarchy. It resolves the Personal membership for the borderless photo, username and Personal/Personal Plus header even when a club context is active, then shows Account rows in the order About, Profile, Subscription, optional Association and Game Settings. Profile repeats the editable identity image and Personal tier at its top, offers adjacent edit and remove-image controls, remains read-only until Edit is selected and shows the email-change warning only while editing. Subscription separates Personal and Club memberships and displays the latest verified purchase/renewal provider when available. Game Settings separates Racket Sports, Timers and Game Attributes in a native segmented control. An active club admin additionally sees Organisation, Users, Courts, Club Settings and Data under a separate Club heading, followed directly by sign-out. Data owns the aggregate club CSV preparation/share controls that previously appeared in Club Analytics. The old club-name/club-subscription summary, landing-page view-only notice and redundant signed-in username line are not rendered; the role-specific view-only explanation lives in Association for non-admin members. Profile resolves deletion against the retained Personal membership even while a club is active, then uses a warning followed by an exact typed `DELETE` confirmation before submitting `DELETE MY ACCOUNT` to the existing API. The web `/settings` route follows the same personal-first principle: Profile is initially read-only and enters editing explicitly, and read-only club associations appear beneath it. Web adds Club Management between Association and Subscription only when the identity administers a club: one admin association opens directly, while multiple admin associations first show a chooser. Web, iOS and Android centre-crop and compress a selected JPEG/PNG/WebP source to a 512-pixel JPEG, request a five-minute presigned POST from `POST /profile_image/{personal_organization_id}/upload`, upload directly to the private S3 bucket, and call `/complete`. The backend validates identity ownership, JPEG structure, 5 MB maximum, square 256–512 dimensions and absence of EXIF/IPTC metadata before updating the canonical identity. `GET /profile_image/{personal_organization_id}` supplies the same short-lived read URL to every client. Association cards come from the approved membership list retained at login. Web association browsing keeps the active scoring tenant unchanged. Native iOS filters Association to icon-led club cards; opening one selects that authorised club context and enters a two-column Profile / Users / Courts / Club Settings / Data hub so the existing organisation-scoped controls operate on the selected club. Native context changes clear and reload dashboard data, including clearing local sport/date history filters and generated export files, and their confirmation appears in a three-second bottom toast. Matches History performs text, enabled-sport and single-day filtering locally over the loaded completed-match list. Web club administration adds a Leagues sub-menu with collapsible Club leagues and Inter-club leagues groups. League names use the shared catalog returned by `GET /organization_settings/{organization_id}`; selecting a league expands its dated opposition fixtures. The complete normalized list is saved through admin-authorized `PUT /organization_details/{organization_id}`, and root admin can still delete an inappropriate competition name platform-wide.
   The current Leagues presentation uses chevrons for its group disclosures. An expanded group exposes a circular add control; each saved league row uses a view icon for dated opposition fixtures and a delete icon that requires exact `DELETE` confirmation before removing the whole league. The normalized list is persisted through the same admin-authorized organisation-details request. Match setup and scheduling do not yet consume league metadata.
   From Subscription, non-current Club Essentials and Club Pro cards open an authenticated club-enquiry page. A successful submission is added to the root-admin Club Account Enquiries queue and triggers confirmation to the signed-in user plus notification to the configured `INTEREST_TO_EMAIL` recipient.
   Club-admin Users uses a circular add action, live first/surname search, and an
   Admin/User filter. Collapsed rows expose only the member name and view/edit
   icon. Accepted identity details are read-only in this context; only the club
   role is saved. Typed `delete` removes the club membership without deleting the
   Personal identity or another association. Courts uses one Squash category for
   both Squash and Racketball because those sports share the same physical court;
   legacy Racketball court rows are shown and saved as Squash.
5. The native profile page edits first name, surname, email/username, telephone, and country through `PUT /personal_profile/{organization_id}`; the country field offers local country-name completion. The web Profile page also exposes typed-confirmation Personal deletion. Native uses two destructive confirmations. Both call `DELETE /personal_account/{organization_id}`: the backend records a Delete Pending request, revokes every identity session and blocks subsequent login immediately. The profile remains visible to Root Admin until `PurgePersonalAccountsFunction` runs daily on or after `deletion_purge_after`, exactly 12 months later, and deletes Personal-owned matches/scoring records, the central S3 profile photograph, and the identity workspace and memberships. Club-owned matches remain. Clients clear their local session (and native offline cache) after acceptance.
6. [SessionStore.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/State/SessionStore.swift) tracks session expiry and whether local biometric unlock is available and enabled. When the user opts in, the unexpired session is also stored in the device-bound iOS Keychain behind the current biometric enrolment. Face ID or Touch ID can unlock it at cold launch or restore it from the login screen after local sign-out, including offline. A successful authentication remains valid across brief interruptions and the app only relocks after five continuous minutes in the background; transient `.inactive` states such as system overlays and the biometric prompt do not relock it. Biometrics are not a second backend login method and an expired or server-rejected session is removed.
7. The native About page reads the installed app version and build directly from the iOS bundle metadata on device; it does not rely on a backend route.
8. The native header, Matches view, pre-match sport chooser and association page use the locally persisted membership list to switch active organisation without signing out. The switch refreshes dashboard, current, scheduled and history data; Matches has one small read-only context label rather than a second context control, and omits that label entirely for an identity with only Personal or Personal Plus. The Personal Free scheduling gate uses an `Upgrade` action that opens the Personal membership's Subscription page, so an active club context cannot make that page request club organisation settings. Before sport selection, the compact `Score this match for` dropdown lists Personal first and then clubs, using the same three-line affordance as the header. Personal Profile, Subscription and Game Settings remain identity-level by resolving the personal membership when one exists.
9. Native Settings places racket-sport access inside the active club's Club Admin group, while Personal sport access is a separate part of Game Settings. Future sport rows are informational, remain disabled, and cannot enter the saved enabled-sports payload.
9. [StartNewMatchView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/StartNewMatchView.swift) uses `GET /organization_settings/{organization_id}`, `GET /match_setup_lookup/{organization_id}`, and `POST /start_match` for the native match-setup flow. Its sport picker combines adaptive light/dark cards, brand-blue court linework, pink accents, and transparent photo-style ball assets for squash, racketball, tennis, and Padel; compact versions of those same assets appear in the Settings Racket Sports rows while retaining their existing layout and controls. Player headings update as first names are entered and shirt choice is a compact colour-dot menu. Tennis setup omits country and handedness, supports singles/doubles with one shirt colour per participant, best-of sets, Golden Point, an optional final-set 10-point match tiebreak, and timed breaks. Squash/racketball can opt into Golden Point at 10-all or 14-all, handicap scoring on Personal Free, Personal Plus, or club accounts, and timed 90-second game breaks; the warm-up uses two 120-second squash halves or two 150-second racketball halves. Padel uses the same court-scoring presentation but requires two named players on each team and defaults to best of three. Every sport's timing toggle is initially set from its saved Game Settings default. When timing is not selected, Squash/Racketball opens directly on live scoring while Tennis/Padel proceeds directly to the required opening serve/receive choice.
10. [MatchScoringView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/MatchScoringView.swift) owns common loading, timers, networking, and controls. A match whose status is still `scheduled` clears any stale local clock, stays at `00:00`, and blocks clock/scoring/action controls; successful activation then bootstraps the normal sport-specific timer state. When an online match is open and the retained membership may operate it, the view concurrently sends authenticated `{ match_id, warm: true }` requests to `/score_point`, `/event_action`, and `/undo_action`. These calls initialize each independent Lambda plus its database/authorization path without claiming ownership or creating events. Its Match Settings shirt controls use player-name labels and compact colour-only menus matching setup. Its squash/racketball presentation selects compact geometry from the available width as well as height, uses an adaptive vertical fallback for warm-up actions, keeps game history horizontally scrollable, enlarges the main player scores while keeping the point-rail text compact, and replaces the live board with a completed-match summary after the final point. On an iPhone with compact landscape height, it further reduces player-header, score-card and point-rail height while retaining the bottom timer and Action controls; opening-server, warm-up and interval overlays hide that dock and consume the released safe-area height instead of being covered by it. The credential-free landscape UI regression asserts that both score cards remain tappable above the timer dock. [RacketPointRailReducer.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/State/RacketPointRailReducer.swift) reconciles the live serving marker with the latest point: when the server manually changes box without changing score, the existing marker is replaced (`R2` becomes `L2`) instead of duplicated. The current marker remains readable as an outlined, lightly tinted pair rather than filling both its service-side and score pills with the player colour. The saved `RacketServiceSideTimelineUITests` fixture starts this real screen offline at `R2`, verifies the visible replacement with `L2`, scores the next server point and verifies `R3`; `testing/automated/mobile/run-racket-service-side-ui-test.sh` runs it in an Apple Simulator and retains screenshots in the `.xcresult`. The separate opt-in `LiveRacketMatchJourneyUITests` signs into the real Personal Plus test account, creates Paul versus Mark as Best of 1 / PAR-11, checks the same side correction plus let and undo behavior, completes the match and signs out; it writes a real completed test match and therefore never runs as part of the credential-free baseline. Light shirt colours use dark foregrounds and a visible score inset, the running match timer is light green while its paused state remains slate, and the custom pink-accented action sheet names both players and keeps player selection within the same sheet. [TennisScoringPresentation.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/TennisScoringPresentation.swift) owns the tennis/padel scoreboard and an available-height scrolling score timeline with scores pulled towards the centre. Tennis Golden Point proceeds automatically from the 40-40/Right service side; padel instead presents the two receiving players by name and maps the selected partner to their established receiving court before allowing the deciding point. The visible timeline shows only point scores, labels a game-winning point as `Game` in mustard, and follows it immediately with a larger blue score-only divider. Backend and offline point events still record the actual server, receiver and Deuce/Ad court before the point as well as its score and game/set boundary for future statistics, rather than relying on the next-point serving state. When enabled, `TennisBreakRules` drives a 90-second interval after odd games from game 3 onward and a 120-second interval after a completed set. [OfflineMatchStore.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/State/OfflineMatchStore.swift) retains the ordered action queue, while [TennisScoringReducer.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/State/TennisScoringReducer.swift) mirrors backend tennis transitions offline. Each accepted score or action is projected immediately, the UI lock lasts only for a 150 ms tap debounce, and a background task drains the queue serially. Reconnection uses the same UUID-tagged replay, preserves actions appended during an in-flight request, adopts each authoritative server response, and exposes the actual replay error while keeping failed actions queued.
11. [HistoricMatchView.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/HistoricMatchView.swift) and [HistoricMatchPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/HistoricMatchPage.jsx) reload the same authenticated match payload and render matching read-only experiences for completed matches. Both use the iOS-style compact two-row result card, initially collapsed Match Information, shallow Match Time disclosure, sport-specific game/set terminology, grouped point history and normalized `MM:SS` timing. Each displays the greater of `match_duration_seconds` or combined first-to-last event durations so a stale saved clock cannot be shorter than its visible rows. Game/set headers place the completed score between player names, and the two web disclosures use one circular expand/collapse treatment. Squash/racketball point rows reserve equal-width rails, show score and orange service-side markers only on the winner's side, and keep the winner and timestamp geometrically centred; no empty opponent circles, redundant Point labels or server-name line is rendered. A blue cumulative games-score row derived from `game_history` follows each completed squash/racketball game. Web tennis and Padel use a separate equal-rail layout with only score and time in the centre and a tennis-ball server marker on the recorded point-time server's side; a game-winning point is normalized from values such as `Game–30` to `Game`, while distinct game/set completion dividers remain. The web result card remains sticky below the standard shared header, which omits the former Historic Match title, explanatory copy and redundant History/Matches action row. Web history cards navigate to `/match/{match_id}/history`; `/match/{match_id}` remains the live-scoring route.
12. [ClubPageHeader.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/components/ClubPageHeader.jsx) owns the signed-in web navigation for Home, new match, Matches, Analytics, Settings and Help. The header starts three pixels from the viewport top, stays sticky at the page-shell width on ordinary signed-in pages and listens to vertical scroll position; it collapses after 72 pixels and expands again below 16 pixels, preventing browser scroll anchoring from repeatedly toggling the menu while another control passes underneath it. Match History is the deliberate exception: `DashboardPage.jsx` adds `match-history-page` while that view is active, and its direct header uses normal document flow so it cannot overlap interactive history content. The compact state reduces vertical padding, logo, wordmark and navigation controls and swaps text labels for the same SVG icon language used by the mobile navigation. The Home control is always icon-only, the new-match `+` is the only blue bordered navigation action, Messages sits immediately left of the compact account/club context menu at the far right, and Logout is the menu's final action. The context menu renders Personal first, inserts a separator, and sorts club memberships alphabetically. It shares the trigger's right edge and touches its lower edge; a top-right transform origin makes it grow diagonally toward the bottom-left and shrink back to the same anchor. The redundant profile icon is omitted because self-profile editing is available from Settings. Dashboard descriptions and account/club text are omitted, Start New Match remains a separate blue action immediately below the header, and `AppFooter` no longer renders version/build or duplicate help content. `/match/new` and completed-match detail routes use this same clean header without a page title, explanation or separate local navigation actions; Home and the primary navigation provide return routes. The dashboard and full history view arrange completed matches as a two-column grid at viewport widths of 1100px and above while preserving the one-column/card-carousel presentation below that breakpoint.
13. Offline scope is deliberately limited to a match previously opened on that device. Creating matches, activating scheduled matches, loading history, changing settings, account deletion, and opening uncached matches still require connectivity.
14. Help & Feedback includes a native privacy/data page covering account, match, device, offline and biometric handling. The public login uses the measured device width for its portrait card and a compact side-by-side landscape layout; centred Ping Us and Password Reset cards return with their top-right close control rather than a second Back action. [PrivacyInfo.xcprivacy](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/PrivacyInfo.xcprivacy) declares the app's required-reason UserDefaults access. App Store Connect privacy answers and the public policy URL must still be maintained for each release.
15. [StoreKitPurchaseService.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Services/StoreKitPurchaseService.swift) loads the authenticated purchase context and offers the yearly Personal Plus product for new purchases, displays Apple's localised price, passes `.appAccountToken`, observes updates, restores purchases, and supports Apple's manage-subscriptions sheet. Monthly transactions remain recognized for restore and server lifecycle handling so earlier purchases are not orphaned. For server-enabled purchasing it submits both the transaction JWS and signed `AppTransaction` JWS, finishes only after backend acceptance, and refreshes the server-authoritative dashboard plan. Debug local StoreKit tests remain non-authoritative while the deployment gate is off.

### Current native gap

- the current iPhone scoring layout is much improved but still needs final polish
- notification inbox delivery, automatic read-on-open and per-identity dismissal are backend-backed; APNs push delivery is not implemented
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

## 17. Schema Migration and Promotion Flow

1. Migration SQL is stored in `backend/schema/` with one unique three-digit
   version per file. `scripts/check_migrations.py` rejects duplicate or missing
   versions and verifies every exact file SHA-256 against
   `backend/schema/checksums.sha256`.
2. Migration `043_schema_migration_ledger.sql` creates `schema_migrations` as
   the database-specific record of successful migrations. A promotion compares
   its versions, filenames, and checksums with the target Git commit before any
   SQL or application artifact is deployed.
3. Existing databases predate the ledger. They require a one-time schema and
   seed-data audit before versions `001`–`042` can be marked as a verified
   legacy baseline. The former duplicate `010_user_profile_fields.sql` is not
   retained as a second `010`; idempotent migration
   `044_reconcile_user_profile_fields.sql` reconciles that shape after the
   ledger exists.
4. New migrations are applied in ascending order, one transaction per file,
   with the ledger insert committed only when the SQL succeeds. Applied files
   are immutable; a defect is corrected by a later forward migration.
5. Additive schema normally precedes the backend that requires it, followed by
   frontend and compatible native-client promotion. Breaking changes use
   separate expand-and-contract releases. `docs/promotion-runbook.md` contains
   the operational checks, smoke tests, evidence, and rollback policy.
6. The current pre-release system has one Supabase environment protected by
   daily backups. Its legacy ledger baseline is useful evidence, but it does not
   replace a future staging-to-production rehearsal against a separate
   production database before launch.
7. On 26 October 2026 that pre-release database passed all 42 legacy audit rows
   and recorded versions `001`–`044`: 44 ledger rows, 44 distinct checksums, and
   schema commit `c825c8c2560a1c82066d2c9aca1fa537b9002061`. Future status can
   be exported with `scripts/migration-ledger-status.sql`.

## 18. Current Cross-Cutting Gaps

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
Tournament reads are available to approved members of an enabled club, but only
`admin` and `scorer` roles can schedule or score fixtures. Non-admin tournament
payloads omit entrant email and account identifiers. An administrator can share
the Personal or Personal Plus registration route shown on an unlinked guest
profile; matching-email registration links the existing reusable player while
leaving its host-club affiliation as `guest`.


### Ground Control Match Directory

The directory filters non-archived matches locally by organisation name, sport and UK calendar date. The date is the completion date when available, otherwise the creation date. Match rows show club or Personal context, and the court is displayed in Match Details. The sport totals count completed matches for the organisation and date scope across all sports. The detail route fetches the sport engine's read-only snapshot and effective scoring events. Archive hides the match from standard views. The detail page requires typed confirmation before permanently deleting the match and its scoring records.

The Ground Control counts a user with multiple club memberships once under Users → Club Accounts. Published notification cards report the eligible audience size captured at publication and the distinct identities with an inbox read receipt. The inbox audience remains plan-based when users open it.

The Ground Control Online Users report refreshes every 30 seconds while open. Activity reflects authenticated requests recorded in `org_user_sessions.last_seen_at`. Web attribution uses the existing login source. Native attribution is recorded at login from the client platform. Distinct-user totals deduplicate across platforms.

Ground Control Settings links Tournament Manager and Sports Controls. The Tournament Manager card opens the same per-club configuration page, and the dashboard directory marks enabled clubs with a trophy.

Selecting a club name in Ground Control Tournament Manager shows events in registration, draw published or in progress, and counts completed events separately.

## Current iOS Hardening Notes

The Account settings list now ends with Need Help. Profile is read-only until Edit and saves optional birth month/year against the retained Personal organisation, even while a club scoring context is active. The pre-match account selector is a compact Personal-first dropdown, shirt colours open in a two-row grid of five, and Squash/Racketball place handedness beside country. Every fresh sport confirms its opening server before live scoring. The scorer fits up to five completed games across the available width and places offline/synchronisation status immediately above the timer/action dock.

The native bottom bar gives all six destinations equal width. Match cards use a compact `MMM` date tile, add the year only for an earlier calendar year, and reduce the sport-strip padding. Current, Scheduled and History headings share one icon and type scale. Historic results keep the winner and score pink and the opponent blue, while top-level back controls use an icon-only circle.

Match setup now defaults Player 1 to blue and Player 2 to the distinct pink palette entry, keeps `Lefty` on one line, and shares the same two-row shirt grid with live Match Settings. Active Match Details aligns cards by row and begins with its event timeline collapsed. A Personal Plus personal match can reveal its private viewing code; a club match shows the court scoreboard code instead.

For Squash/Racketball, `RacketPointRailReducer` retains an optional decision label while reconciling a manual service-side change. Stroke and Let events render as their own bright-yellow, full-word `Stroke` and `Let` rows on the awarded/requesting player's lane. A Let appends the unchanged server marker again; a Stroke appends the resulting point and service marker after the decision row. Recording a point or decision resumes a paused local match clock; the paused control is red and carries a pause icon. Game Settings stores the optional full-height ST/L decision tree locally on the device for eligible Personal Plus and club play. Personal Plus completion derives separate Serves Won and Serves Lost rows plus total Stroke/Let counts from effective events and their point-time server snapshots.

The signed-in web, iOS and Android clients refresh memberships every five seconds while active and immediately after browser focus or native foreground. This quickly reconciles role, plan, enabled-sport and verified subscription-source presentation after a Control Panel change, but it is not the security boundary: each protected request still re-authorizes its selected membership and role on the server. The iOS Personal Game Settings editor uses a separate sport draft and saves to the Personal workspace, while Club Settings saves to the selected club.

Migration `055_unified_subscription_sources.sql` introduces the server-written `subscription_sources` ledger. It records the organisation, provider (`apple`, `google_play`, `stripe`, or `manual`), provider subscription identifier, plan/product, lifecycle status, renewal/expiry dates and auto-renew state. Existing App Store subscriptions and transactions are backfilled, and an App Store table trigger keeps verified Apple state synchronized. Session responses expose the latest applicable provider state so all clients can report its source consistently. Apple is currently the only live purchase verifier; Google Play and Stripe require their own verified webhook or receipt adapters before those providers can activate or renew an entitlement.

The dashboard monthly charts count non-archived matches, canonical user identities and Apple subscription records by their creation month. The current month is month to date.
