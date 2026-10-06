# Marketing Site (Standalone)

This folder is intentionally separate from the React app in `frontend/`.

## Why

- Keep `hitnscore.com` marketing content independent from app code changes.
- Let the product app continue to live at `app.hitnscore.com`.

## Suggested hosting split

- `hitnscore.com` and `www.hitnscore.com` -> deploy `weblanding/` as static files.
- `app.hitnscore.com` -> deploy the existing `frontend/` application.

This split means changes in `frontend/` do not alter the landing page unless you explicitly redeploy `weblanding/`.

## Deployment runbook

- AWS + GoDaddy implementation: [docs/weblanding-aws-godaddy-deployment.md](/Users/glennrowe/Development/Projects/RcktScore/docs/weblanding-aws-godaddy-deployment.md)

## Current landing content

- Single-page responsive marketing experience with no menu navigation
- Large fixed white brand header that compacts after scrolling
- Public personal-registration calls to action
- High-resolution court imagery for squash, tennis, Padel, table tennis,
  pickleball, and badminton
- Responsive iPhone and iPad product mockups
- Consent panel with all/essential choices and expandable details
- Separate comparison and help pages retained for later release decisions, but
  not linked from the main header
