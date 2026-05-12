# Web Automation

This area is for browser automation using Playwright.

## Why Playwright

It matches the automated testing plan well because it can:

- open the real web app in a browser
- emulate mobile phones and iPads
- take screenshots, traces, and videos on failure
- run the same flow across multiple device profiles

## First run

From the `frontend/` folder:

```bash
npm install -D @playwright/test
npx playwright install
```

Then start the frontend app in one terminal:

```bash
cd frontend
npm run dev
```

Run the smoke tests in another terminal:

```bash
cd frontend
npm run test:e2e:smoke
```

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
- match creation flow
- match scoring and undo
- admin permission boundaries

