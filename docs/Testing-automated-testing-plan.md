# RcktScore Automated Testing Implementation Plan

## Goal

Build a practical automated test stack for the **web app first** (mobile web, iPad web, desktop web), while keeping backend and API checks reliable and fast.

This plan is incremental so you can start getting value within days, not months.

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

Create:

```bash
backend/tests/
```

Add tests for:

- Session token validation and expiry behavior
- Tenant authorization checks
- Match scoring endpoint validation
- Role-based access checks (club user vs admin vs root admin)

Run:

```bash
cd backend
pytest -q
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

## 9) Suggested npm Scripts

In `frontend/package.json`:

```json
{
  "scripts": {
    "test:e2e": "playwright test",
    "test:e2e:smoke": "playwright test --grep @smoke",
    "test:e2e:ui": "playwright test --ui",
    "test:e2e:report": "playwright show-report"
  }
}
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

## 11) Flakiness Prevention Checklist

- Prefer stable selectors (`data-testid`) over text-only selectors
- Seed deterministic test data
- Avoid time-dependent assertions without controlled clocks
- Use retry only for known transient network/UI issues
- Capture traces/screenshots/video on failure

---

## 12) Definition of Done for “Automated Testing in Place”

You can consider automation established when:

- Critical auth and match lifecycle paths are green in CI
- Club user/admin permission boundaries are automated
- Mobile portrait + landscape smoke runs automatically on each PR
- iPad and desktop full runs happen on nightly/release pipeline
- Failures produce actionable artifacts (trace, screenshot, logs)

