# Web Automation

This area is for browser automation using Playwright.

The executable tests and configuration live under `frontend/e2e/` and
`frontend/playwright.config.cjs` so Node resolves the pinned frontend test
dependency without machine-specific path settings.

## Why Playwright

It matches the automated testing plan well because it can:

- open the real web app in a browser
- emulate mobile phones and iPads
- take screenshots, traces, and videos on failure
- run the same flow across multiple device profiles

## First run

From the `frontend/` folder:

```bash
npm ci
npx playwright install
```

`@playwright/test` is pinned in `frontend/package-lock.json`, so every developer
and CI run uses the same test-runner version.

The Playwright configuration starts the Vite development server automatically,
so a separate terminal is no longer required. If a server is already running on
port 5173, Playwright reuses it.

Run the public smoke tests:

```bash
cd frontend
npm run test:e2e:smoke
```

## Tennis development journey

The checked-in tennis and Padel journeys use mocked API responses. They exercise the real
React UI without changing a live account or requiring credentials. It verifies
singles/doubles selection, all four participant names and team metadata,
per-participant shirt-colour payloads, the three optional tennis rules, and the
named opening server/receiver plus generated doubles serve order. The Padel
scenario also verifies its doubles-only setup and receiving-team Golden Point
partner choice. The live-score scenarios additionally cover tennis point labels,
games and sets, participant-level serve/receive rotation, Deuce/Ad court,
tiebreak mode, the 90-second odd-game changeover, 120-second set break,
sport-specific completion summary, idempotent action UUIDs, and the absence of
squash/racketball Stroke and Let controls.

Run it headlessly:

```bash
cd frontend
npm run test:e2e:tennis
```

Watch it in a visible Chromium window, slowed down enough to follow:

```bash
cd frontend
npm run test:e2e:tennis:watch
```

To run or watch only Padel:

```bash
npm run test:e2e:padel
npm run test:e2e:padel:watch
```

## Squash and Racketball development journey

The racket journey is also API-mocked and safe to run repeatedly. It creates
Personal Plus Squash and Racketball handicap matches plus a Personal Free
Squash handicap match, verifies Golden Point and the persisted per-sport timer
default in the submitted payload, and confirms that an untimed match bypasses
warm-up and opens directly on live scoring.

```bash
cd frontend
npm run test:e2e:racket
npm run test:e2e:racket:watch
```

## Personal Plus scheduling journey

This mocked journey begins with an active Personal Plus match, schedules a new
match without disturbing it, confirms the scheduled match is visible in
Matches, and then starts it after the active-match fixture clears.

```bash
cd frontend
npm run test:e2e:scheduling
npm run test:e2e:scheduling:watch
```

## Historic match journey

The history journey opens the dedicated read-only completed-match route with
API-mocked Squash and Tennis records. It verifies sport-specific game/set
terminology, match start time and total duration, expandable per-game/set
durations, structured point history, tennis score labels, and separate tennis
game and set completion dividers.

```bash
cd frontend
npm run test:e2e:history
npm run test:e2e:history:watch
```

## Signed-in header journey

The header journey opens an API-mocked club dashboard, verifies the embedded
Home, blue new-match `+`, Matches, Analytics, Settings and Help menu, and scrolls
the page to exercise the sticky compact state. It confirms that the header keeps
the same outer width, shrinks vertically, replaces labels with iOS-style icons,
omits account/club details, the former dashboard description and shared footer,
leaves Start New Match as a separate blue action, and verifies that Played
Matches forms a two-column grid on the desktop profile.

```bash
cd frontend
npm run test:e2e:header
npm run test:e2e:header:watch
```

No Python virtual environment is needed for web tests. Playwright and its
browser driver are pinned by `frontend/package-lock.json`; Python virtual
environments remain appropriate for the backend pytest suite only.

Failed runs retain screenshots and video under `frontend/test-results/`. The
first retry also records a trace, and the HTML report is written to
`frontend/playwright-report/`.

## Base URL

By default the Playwright config expects the frontend at:

`http://127.0.0.1:5173`

If you want to test another environment:

```bash
E2E_BASE_URL=https://your-staging-url npm run test:e2e:smoke
```

## Next tests to add

- successful login for a seeded club user
- session survives refresh
- dashboard route works after login
- credential-backed staging tennis journey that creates, completes, and cleans
  up a real match
- full tennis scoring through deuce, Golden Point, set tiebreak, and final-set
  match tiebreak
- timed odd-game and set-break presentation
- match scoring and undo
- admin permission boundaries
