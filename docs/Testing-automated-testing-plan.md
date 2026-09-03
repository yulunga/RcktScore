# RcktScore Automated Testing Implementation Plan

## Goal

Build a practical automated test stack for the **web app first** (mobile web, iPad web, desktop web), while keeping backend and API checks reliable and fast.

This plan is incremental so you can start getting value within days, not months.

## Launch Context

The next release priority is the native iOS app, but that app still depends on
the same backend contracts and the same operational match flows as mobile web.

That means the practical testing strategy is:

1. keep web/mobile-web automation as the fastest regression net
2. increase backend/API coverage around sessions and match lifecycle
3. run a documented manual signoff pass on iPhone and iPad before release

This document therefore covers both:

- the automated testing roadmap
- the release-gate checks needed to ship the iOS app safely

## Current Checked-In Baseline

The repository has moved beyond a plan-only state:

- `testing/automated/backend/` contains pytest tests for selected match and
  session helpers
- `testing/automated/web/` contains a Playwright configuration and public-route
  smoke tests across phone, tablet, and desktop projects
- `frontend/package.json` exposes `test:e2e`, `test:e2e:smoke`, and
  `test:e2e:headed`
- `mobile/ios/RcktScoreMobile/RcktScoreMobileUITests/` contains the first native
  UI smoke-test bundle

These are starter suites, not the completed coverage or CI rollout described
below. Playwright is not currently declared in `frontend/package.json`, so use
the installation step in the web automation README before running it.

---

## 1) Recommended Testing Stack

### Frontend UI + E2E

- **Playwright** for browser automation (best fit for mobile emulation + orientation coverage)
- Test targets:
  - Mobile phone web (primary): iPhone + Android emulation
  - Tablet web: iPad emulation
  - Desktop: Chromium/WebKit

### Backend/API

- **Pytest** for Lambda/business logic tests
- **Requests/httpx** for API integration tests

### Contract/Smoke layer

- Optional: lightweight smoke tests that run against deployed staging endpoint before releases

---

## 2) What to Automate First (Priority Order)

Automate the highest-risk paths first:

1. Login/session persistence
2. Match lifecycle (`/match/new` → start → score → undo → end)
3. Club admin critical CRUD (users, courts)
4. Permissions boundaries (user cannot perform admin actions)
5. Responsive smoke checks on key routes (`/dashboard`, `/matches`, `/match/:id`, `/settings`, `/display`)

For the upcoming iOS launch, add these to the same high-priority set:

6. single-session replacement behavior across web and iOS
7. scheduled-match lifecycle (`create scheduled` → `start` → `edit` → `score`)
8. dashboard parity checks for small screens (`/dashboard`, `/matches`, `/history`)

---

## 3) Suggested Test Pyramid for This Repo

### Layer A — Fast unit tests

- Frontend utility/state logic where practical
- Backend common logic in `backend/common/*.py`

### Layer B — API integration tests

- Auth, org context, match endpoints, role restrictions

### Layer C — E2E browser tests

- A small but stable set of high-value end-to-end flows

Target balance:

- ~70% unit/integration
- ~20% API integration
- ~10% E2E critical flows

---

## 4) Bootstrap Playwright for Web Automation

From repository root:

```bash
cd frontend
npm i -D @playwright/test
npx playwright install
```

Create folders:

```bash
frontend/tests/e2e/
frontend/tests/fixtures/
frontend/playwright.config.ts
```

### Example `playwright.config.ts` (mobile-first)

```ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  timeout: 60_000,
  expect: { timeout: 10_000 },
  reporter: [['html'], ['list']],
  use: {
    baseURL: process.env.E2E_BASE_URL || 'http://localhost:5173',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'Mobile Safari Portrait',
      use: {
        ...devices['iPhone 14'],
        viewport: { width: 390, height: 844 },
      },
    },
    {
      name: 'Mobile Safari Landscape',
      use: {
        ...devices['iPhone 14'],
        viewport: { width: 844, height: 390 },
      },
    },
    {
      name: 'Android Chrome Portrait',
      use: {
        ...devices['Pixel 7'],
        viewport: { width: 412, height: 915 },
      },
    },
    {
      name: 'iPad Landscape',
      use: {
        ...devices['iPad Pro 11'],
        viewport: { width: 1194, height: 834 },
      },
    },
    {
      name: 'Desktop Chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'Desktop WebKit',
      use: { ...devices['Desktop Safari'] },
    },
  ],
});
```

---

## 5) Account Strategy for Automation

Use dedicated seeded accounts that match your tier model:

- `skwshClubAdmin` (CALSA user context + SkwshClub admin context)
- `rackets@calsa.co.uk` (club user)
- `racketsadmin@calsa.co.uk` (club admin)
- `yulungaAdmin`, `SkwshAdmin` (root admins)
- `mike@ucingo.com` (personal)
- `paul@ucingo.com` (personal Plus)

Best practice:

- Keep credentials in environment variables (never in git)
- Seed deterministic test data before each run (or nightly reset)

The native UI-test bundle reads its three accounts from these environment variables:

- `RCKTSCORE_UI_TEST_CLUB_USERNAME` / `RCKTSCORE_UI_TEST_CLUB_PASSWORD`
- `RCKTSCORE_UI_TEST_PERSONAL_USERNAME` / `RCKTSCORE_UI_TEST_PERSONAL_PASSWORD`
- `RCKTSCORE_UI_TEST_PERSONAL_PLUS_USERNAME` / `RCKTSCORE_UI_TEST_PERSONAL_PLUS_PASSWORD`

---

## 6) Example E2E Scenarios to Implement

### `auth.spec.ts`

- Login succeeds for club user
- Session survives refresh
- Logout returns to login

### `match-lifecycle.spec.ts`

- Create match
- Start match
- Score points
- Undo one event
- End match
- Verify history entry exists

### `admin-permissions.spec.ts`

- Club admin can access settings/user/court actions
- Club user is blocked from admin operations

### `personal-boundaries.spec.ts`

- Personal accounts cannot access club-admin/root-admin screens
- Personal Plus shows intended Plus-only indicators

### `responsive-smoke.spec.ts`

- Key pages render and core controls are visible per device project

---

## 7) Add API Tests (Pytest)

The current starter suite lives in:

```bash
testing/automated/backend/
```

Add tests for:

- Session token validation and expiry behavior
- Tenant authorization checks
- Match scoring endpoint validation
- Role-based access checks (club user vs admin vs root admin)
- Session replacement rules (`web app` and `mobile app` coexistence rules)
- Scheduled match start/edit paths
- Match settings update behavior if enabled for launch

Run from the repository root:

```bash
pytest -c testing/automated/backend/pytest.ini testing/automated/backend
```

---

## 8) CI Pipeline Rollout

### Stage 1 (fast PR gate)

- Python syntax check (`py_compile` from AGENTS guide)
- Frontend build check
- Small Playwright smoke suite (1 mobile + 1 desktop project)

### Stage 2 (post-merge/nightly)

- Full Playwright project matrix
- Full API integration tests

### Stage 3 (release candidate)

- Staging environment smoke with production-like data setup

---

## 9) Current npm Scripts

In `frontend/package.json`:

```bash
cd frontend
npm run test:e2e
npm run test:e2e:smoke
npm run test:e2e:headed
```

---

## 10) Practical Rollout Timeline

### Week 1

- Install Playwright
- Add config + 3 smoke tests (auth, dashboard load, match list load)

### Week 2

- Add full match lifecycle E2E
- Add permissions E2E for club user/admin

### Week 3

- Add personal/personal Plus/root-admin coverage
- Add baseline API pytest coverage

### Week 4

- Stabilize flaky tests
- Wire smoke tests to PR CI and full matrix to nightly

---

## 11) iOS Launch Signoff Plan

Automation will not be enough on its own for the first native release. Use this
manual signoff gate on top of the automated coverage.

### Device Matrix

Minimum manual coverage:

1. iPhone portrait
2. iPad portrait

Recommended additional pass:

1. iPad landscape

### Accounts To Test

1. club admin
2. club user
3. personal
4. personal plus

### Functional Signoff

Each of these should be explicitly checked on-device:

1. login and logout
2. session persistence across relaunch
3. session replacement by web login and by another mobile login
4. dashboard load with active, scheduled, and recent data
5. create immediate match
6. create scheduled match
7. start scheduled match
8. score live squash/racketball match
9. score live tennis match
10. undo event
11. end match
12. completed match appears in history
13. settings load and save for launch-critical club features, including sport visibility
14. dark-mode device opens native match setup with readable colors
15. offline dashboard state does not strand the user with a persistent fetch-error banner
16. help / password reset / feedback paths work

### UX Signoff

1. tap targets are usable one-handed on iPhone
2. active, scheduled, and history cards remain readable with longer names
3. iPad layouts do not clip controls or hide primary actions
4. error and empty states are understandable
5. loading states do not feel broken on slower networks
6. the current compact recent-match cards remain readable with longer names

### Release Blockers

Do not sign off the release if any of the following fail:

1. match scoring becomes stuck or inconsistent
2. scheduled match start/edit flow is unreliable
3. users are signed out unexpectedly during normal use
4. club admins still need the web app for launch-critical match operations
5. small-screen layouts hide important controls on iPhone or iPad
6. the live tennis flow cannot be started and scored cleanly

---

## 12) Recommended CI Gate Before Release

### Pull Request Gate

1. Python syntax check
2. Frontend build check
3. backend pytest subset for sessions and match lifecycle
4. Playwright smoke for login, dashboard, and match list on one mobile and one desktop project

### Nightly Gate

1. full Playwright device matrix
2. full backend test suite
3. report of flaky tests and reruns

### Release Candidate Gate

1. staging smoke pass against deployed backend
2. manual iPhone signoff
3. manual iPad signoff
4. explicit pass/fail checklist captured in release notes or test log

---

## 13) Flakiness Prevention Checklist

- Prefer stable selectors (`data-testid`) over text-only selectors
- Seed deterministic test data
- Avoid time-dependent assertions without controlled clocks
- Use retry only for known transient network/UI issues
- Capture traces/screenshots/video on failure

---

## 14) Definition of Done for “Automated Testing in Place”

You can consider automation established when:

- Critical auth and match lifecycle paths are green in CI
- Club user/admin permission boundaries are automated
- Mobile portrait + landscape smoke runs automatically on each PR
- iPad and desktop full runs happen on nightly/release pipeline
- Failures produce actionable artifacts (trace, screenshot, logs)

For the iOS launch specifically, also require:

- the manual iPhone and iPad signoff checklist is documented and completed
- session replacement behavior has been exercised end-to-end
- scheduled-match create/start/edit/score path has been exercised at least once
