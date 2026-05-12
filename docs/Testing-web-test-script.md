# RcktScore Web Application Test Script

## Scope and Goal

This script is a **manual end-to-end test plan** for the current RcktScore web app, with a priority on:

1. Mobile phone web (primary focus)
2. iPad/tablet web
3. Desktop web

This plan covers the three major web personas:

- **Player-facing user** (match participants and scorekeepers)
- **Club user** (org-user with normal operational permissions)
- **Club administrator** (org-user with admin capabilities)

> Note: Native mobile app testing is intentionally out of scope for this script and should be handled in a separate mobile test plan.

---

## Prerequisites

- Test environment deployed and reachable (frontend + backend APIs)
- At least one test organisation with:
  - 1 club administrator account
  - 2 club user accounts
  - 4 player identities (can be club users if needed)
- At least 2 courts configured for scheduling tests
- Access to both root-admin accounts: `yulungaAdmin` and `SkwshAdmin`
- Access to personal accounts: `mike@ucingo.com` and `paul@ucingo.com`
- Mail inbox access for password reset and feedback verification

---

## User Tier Coverage Matrix (Required Accounts)

Use these exact user tiers and accounts during execution:

| Tier | Account | Expected Access | Core Areas to Validate |
|---|---|---|---|
| Club-linked user | `skwshClubAdmin` (CALSA membership as user role) | Club user access only in CALSA context | Login/session, dashboard, matches/history visibility, no admin-only actions |
| Club-linked admin | `skwshClubAdmin` (SkwshClub admin membership) | Club admin access in SkwshClub context | Org settings, user/court CRUD, full match operations |
| Root admin | `yulungaAdmin` | Root-admin routes and tools | `/rckscoreAdmin` routes, interests, personal accounts, org-level admin screens |
| Root admin | `SkwshAdmin` | Root-admin routes and tools | Same as above, plus regression check for role parity with `yulungaAdmin` |
| Club account (user) | `rackets@calsa.co.uk` | Standard club user | Club-user flows and permissions boundaries |
| Club account (admin) | `racketsadmin@calsa.co.uk` | Club admin | Club-admin CRUD + match lifecycle administration |
| Personal account | `mike@ucingo.com` | Personal account baseline permissions | Personal account login/session behavior and access boundaries from club-only surfaces |
| Personal Plus account | `paul@ucingo.com` | Personal Plus entitlements | Personal Plus feature visibility/access vs baseline personal account |

Execution notes:

- Treat `skwshClubAdmin` as a **multi-tier verification user** and test both declared memberships/roles separately.
- Validate that account-to-tier permissions remain correct after logout/login and hard refresh.
- Validate that none of the personal accounts can reach club-admin or root-admin actions unless explicitly granted in backend config.

---

## Test Device Matrix

Run each test section across this matrix where applicable.

### Mobile Phones (Primary)

- iPhone Safari
  - Portrait
  - Landscape
- Android Chrome
  - Portrait
  - Landscape

### Tablet

- iPad Safari
  - Portrait
  - Landscape

### Desktop

- Chrome (latest)
- Safari or Edge (latest)

---

## Test Data Setup

Create these baseline records before execution:

- Club users:
  - `skwshClubAdmin` (CALSA user role and SkwshClub admin role)
  - `rackets@calsa.co.uk` (Standard)
  - `racketsadmin@calsa.co.uk` (Admin)
- Courts:
  - Court A
  - Court B
- Match-ready participants:
  - Team A: Player 1 / Player 2
  - Team B: Player 3 / Player 4

Suggested match test values:

- Match type: Standard doubles flow used by your club
- Start time: current time + 10 minutes (for schedule visibility checks)

---

## Global Acceptance Criteria (All Personas)

For every test case below, record:

- Pass/Fail
- Device + browser + orientation
- Screenshot/video evidence (especially for layout issues)
- Console/API errors (if any)
- Severity label: Blocker / High / Medium / Low

Additionally verify:

- No blocking UI overlap in portrait or landscape
- Buttons/tappable targets remain accessible on small screens
- Session behavior is consistent (no unexpected logout during active use)

---

## Section A — Authentication and Session

### A1. Login flow (club user)

1. Open `/login`
2. Login with standard club user credentials
3. Verify redirect to dashboard
4. Refresh browser
5. Verify user remains logged in

Expected:

- Successful login
- Session persists across refresh
- No broken mobile layout in portrait/landscape

### A2. Login flow (club admin)

1. Logout
2. Login with club admin credentials
3. Verify dashboard access and settings visibility

Expected:

- Admin session works
- Admin-only actions are available in settings areas

### A3. Multi-organisation membership selector (if applicable)

1. Login with user tied to multiple organisations
2. Switch organisation
3. Verify dashboard/history/match list context updates

Expected:

- Correct organisation context after switch
- No stale records from previous organisation

### A4. Password reset flow

1. Open reset flow from login
2. Submit test email
3. Complete reset via email link
4. Login with new password

Expected:

- Reset email sent
- Token/link usable
- New password accepted

---

## Section B — Player-Facing Core Match Journey

### B1. Create match

1. Go to `/match/new`
2. Select court, players, and scheduled/start fields
3. Save match

Expected:

- Match successfully created
- Visible in `/matches`
- Layout usable on phone portrait first

### B2. Start match

1. Open created match from `/matches`
2. Start match
3. Confirm status changes to active/in-progress

Expected:

- Match transitions to active state
- Timer/controls render correctly

### B3. Scoring actions

1. Record a sequence of scoring events for both sides
2. Verify scoreboard updates correctly after each point
3. Add event actions (if available in UI)
4. Use undo

Expected:

- Each scoring action reflected immediately
- Undo reverts exactly one action at a time
- Event timeline remains consistent

### B4. End match

1. Complete score to match end condition
2. End match via controls
3. Navigate to `/history`
4. Verify finished match appears with correct result

Expected:

- End flow finalizes record
- Match visible in history
- No post-end scoring allowed

### B5. Display route verification

1. Open `/display` while match is active
2. Validate live score readability on:
   - Phone portrait
   - Phone landscape
   - iPad landscape
   - Desktop

Expected:

- Scoreboard legible at each form factor
- No clipped controls/text

---

## Section C — Club User Functional Coverage

### C1. Dashboard

1. Open `/dashboard`
2. Validate summary widgets/data load
3. Tap through linked areas (matches/history/settings)

Expected:

- Data loads without API error banners
- Navigation works consistently on mobile and desktop

### C2. Matches list and filters

1. Open `/matches`
2. Validate list rendering with scheduled + active + completed contexts
3. Apply any available filters/search

Expected:

- Correct filtering behavior
- No layout break at narrow widths

### C3. History page

1. Open `/history`
2. Validate recent completed matches
3. Open a historical match detail if supported

Expected:

- History entries are accurate and ordered as expected

### C4. Help and Ping pages

1. Open `/help`
2. Open `/ping`
3. Submit ping/feedback flow (if available)

Expected:

- Pages load properly
- Submission success confirmation appears

---

## Section D — Club Administrator Functional Coverage

### D1. Organisation settings access

1. Login as club admin
2. Navigate to `/settings`
3. Validate organisation-level settings sections load

Expected:

- Admin can access settings sections
- Non-admin user should not be able to perform restricted actions

### D2. User management

1. Create a new user
2. Edit role (user ↔ admin as appropriate)
3. Disable/remove user if supported

Expected:

- CRUD actions succeed
- Role updates reflected on next login/session refresh

### D3. Court management

1. Create court
2. Edit court name/details
3. Delete/archive court if supported

Expected:

- Court changes immediately available in match creation flow

### D4. Permissions boundary spot check

1. Sign in as standard club user
2. Attempt admin-only operations via UI

Expected:

- Restricted operations are blocked or hidden

---

## Section E — Active User and Concurrency Test

### E1. Two-device same match scoring observation

1. Device A: open active match scoring screen
2. Device B: open same match (or display page)
3. On A, record points rapidly (10–20 actions)
4. On B, observe update behavior

Expected:

- Device B reflects updates with acceptable delay
- No duplicated or out-of-order score state

### E2. Session stability under long use

1. Keep scoring screen open for 20+ minutes
2. Perform periodic scoring actions
3. Verify session continuity and state integrity

Expected:

- No involuntary logout during active usage window
- No stale state requiring hard refresh

### E3. Multi-user list freshness

1. User 1 creates new match
2. User 2 refreshes `/matches` and `/dashboard`

Expected:

- New match appears promptly after refresh/navigation

---

## Section F — Responsive and Orientation-Focused Checks

Perform these checks for critical pages: `/dashboard`, `/matches`, `/match/new`, `/match/:id`, `/settings`, `/display`.

### F1. Mobile portrait baseline

Expected:

- Primary actions reachable without accidental taps
- No horizontal scrolling except intentional tables

### F2. Mobile landscape

Expected:

- Scoreboard and controls remain usable
- Modals and dropdowns remain fully visible

### F3. iPad portrait/landscape

Expected:

- Layout uses space efficiently; no oversized empty sections
- Navigation components are stable on orientation switch

### F4. Desktop regression

Expected:

- Desktop layout unaffected by mobile-oriented fixes
- Same workflows complete without extra steps

---

## Section G — Personal and Personal Plus Account Coverage

### G1. Personal account baseline (`mike@ucingo.com`)

1. Login using `mike@ucingo.com`
2. Verify expected personal-account landing and available nav items
3. Attempt access to club-admin screens (direct URL and in-app)

Expected:

- Personal account login succeeds
- Club-admin and root-admin surfaces are blocked/hidden
- No cross-tenant club data leakage

### G2. Personal Plus comparison (`paul@ucingo.com`)

1. Login using `paul@ucingo.com`
2. Compare visible capabilities with baseline personal account
3. Validate any Plus-only indicators/features

Expected:

- Personal Plus account login succeeds
- Plus entitlements appear only where intended
- No unintended access to club-admin or root-admin controls

---

## Section H — Root Admin Surface (Optional Regression)

Run smoke checks only (given current security posture notes):

1. `/rckscoreAdmin`
2. `/rckscoreAdmin/dashboard`
3. `/rckscoreAdmin/interests`
4. `/rckscoreAdmin/personal-accounts`

Expected:

- Pages load for valid root-admin login
- No accidental exposure to non-root users

---

## Defect Logging Template

For each issue captured, log:

- Title
- Environment (device/browser/orientation)
- Persona (player / club user / club admin)
- Steps to reproduce
- Expected result
- Actual result
- Screenshot/video
- Severity and priority

---

## Exit Criteria for Web Test Cycle

Minimum completion criteria:

- 100% pass on authentication, match lifecycle, and admin CRUD critical paths
- 0 open Blocker defects
- Any High defects have documented workaround and owner
- Mobile portrait + landscape coverage completed for all critical flows
- iPad and desktop smoke/full coverage executed as planned

