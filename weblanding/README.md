# Marketing Site (Standalone)

This folder is intentionally separate from the React app in `frontend/`.

## Why

- Keep `hitnscore.com` marketing content independent from app code changes.
- Let the product app continue to live at `app.hitnscore.com`.

## Suggested hosting split

- `hitnscore.com` and `www.hitnscore.com` -> deploy `marketing-site/` as static files.
- `app.hitnscore.com` -> deploy the existing `frontend/` application.

This split means changes in `frontend/` do not alter the landing page unless you explicitly redeploy `marketing-site/`.

## Current landing content

- Hero section
- Login button in the top-right (links to `https://app.hitnscore.com/login`)
- "Help me" section
