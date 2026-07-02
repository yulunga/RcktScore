# AGENTS.md

## Purpose

This file is the short operating guide for the `RcktScore` repository.
It should describe the codebase as it exists now, not as it is planned to be.

When the product, API surface, security posture, or troubleshooting path changes,
update this file together with:

- [docs/backend-api.md](/Users/glennrowe/Development/Projects/RcktScore/docs/backend-api.md)
- [docs/technical-walkthrough.md](/Users/glennrowe/Development/Projects/RcktScore/docs/technical-walkthrough.md)
- [docs/troubleshooting.md](/Users/glennrowe/Development/Projects/RcktScore/docs/troubleshooting.md)

## Current Product State

`RcktScore` v2 is the active app in this repository.

Current stack:

- React + Vite frontend in `frontend/`
- Python AWS Lambda backend in `backend/`
- Supabase Postgres as the primary datastore
- AWS SAM for backend deployment
- native iOS client in `mobile/ios/`

The old Flask code in `version1/` is reference-only and should not be treated as the active product.

## Current Release Posture

The repository is still pre-launch. Web and backend flows are in late beta, and
the native iOS app is in active device hardening rather than production release
readiness.

What is real and implemented:

- org-user login with backend session tokens
- multi-organisation membership selection
- dashboard, history, and match lists
- organisation settings, user creation with first-name/surname fields, organisation-user detail editing and delete, user role updates, and court CRUD
- match create, schedule, start, score, event actions, undo, and end
- sport-specific match engine dispatch with live squash/racketball and first-pass tennis scoring
- separate engine modules exist for padel, table tennis, badminton, and pickleball, and are wired through the dispatcher to fail safely until their scoring logic is implemented
- native iOS client for org-user login, dashboard/matches/history/settings/help, native match setup, historic-match viewing, and live scoring
- native iOS match setup currently exposes the implemented and enabled sports only: squash, racketball, and tennis
- organisation and root-admin controls for enabling which racket sports are visible to a club or personal account
- native settings now use a plan-aware menu layout with dedicated per-section pages, personal-account profile/photo controls, password-reset access, and club-admin access to organisation, user, court, and racket-sport visibility controls
- register-interest, password reset, and feedback email flows
- root-admin UI and supporting backend functions

What is still partial or risky:

- root-admin backend authorization is not fully implemented
- some root-admin organisation actions use `x-root-admin-request` header bypass logic
- WebSocket broadcast infrastructure is scaffolded but not fully wired
- iOS login does not yet expose multi-organisation membership selection when the backend returns `organizationSelection`
- the current iPhone scoring layout is much improved but still needs final UX hardening before release
- some native settings sections are still UI scaffolds only, including account-level game-settings presets, association/federation profile links, and reporting/stats views
- the native notification center behind the dashboard bell is not implemented yet
- native profile photos are still device-local only and are not stored centrally or shared across users/devices yet
- offline behavior is still partial in the native app: the dashboard now stays quiet when offline, but historic data and scoring are not fully offline-capable
- there is no documented iOS CI/archive/release pipeline in the repo yet
- no automated test suite is checked into the repo

## Repository Layout

- `frontend/`
  - route definitions in `src/App.jsx`
  - auth state in `src/context/AuthContext.jsx`
  - root-admin state in `src/context/RootAdminContext.jsx`
  - match state in `src/context/MatchContext.jsx`
  - HTTP client in `src/services/api.js`
  - browser WebSocket client in `src/services/websocket.js`
- `backend/`
  - Lambda handlers in `functions/*/handler.py`
  - shared backend logic in `common/*.py`
  - sport engines currently split across `common/match_logic.py`, `common/squash_match_logic.py`, `common/tennis_match_logic.py`, plus placeholder engine files for `padel`, `table_tennis`, `badminton`, and `pickleball`
  - schema migrations in `schema/*.sql`
  - SAM template in `template.yaml`
- `mobile/`
  - iOS project in `ios/RcktScoreMobile/`
  - mobile-facing shared references in `shared/`
- `docs/`
  - backend/API reference
  - lifecycle walkthrough
  - troubleshooting
  - mobile notes
  - pricing and packaging notes

## Current Frontend Routes

Defined in [frontend/src/App.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/App.jsx):

- `/` and `/login`
- `/help`
- `/dashboard`
- `/matches`
- `/history`
- `/settings`
- `/ping`
- `/match/new`
- `/match/:matchId`
- `/display`
- `/rckscoreAdmin`
- `/rckscoreAdmin/dashboard`
- `/rckscoreAdmin/clubs/:organizationId`
- `/rckscoreAdmin/interests`
- `/rckscoreAdmin/personal-accounts`

## Current Backend API Groups

Defined in [backend/template.yaml](/Users/glennrowe/Development/Projects/RcktScore/backend/template.yaml):

- authentication and session
- password reset and membership approval
- root-admin operations
- dashboard and organisation settings
- personal profile
- user and court administration
- match setup lookup
- match lifecycle and scoring

See the backend/API reference for the exact route list.

## Security Notes

- org-user session enforcement is real in `backend/common/session_logic.py`
- scoring and organisation endpoints are tenant-aware through backend authorization checks
- sport visibility is now enforced through organisation-level `enabled_sports` settings before match creation
- root-admin login is real, but root-admin session/token enforcement is not yet implemented as a backend-wide control
- do not describe the current root-admin surface as fully secured
- do not describe WebSocket live display as production-complete

## Troubleshooting Entry Points

Use these first:

- [docs/troubleshooting.md](/Users/glennrowe/Development/Projects/RcktScore/docs/troubleshooting.md)
- [docs/backend-api.md](/Users/glennrowe/Development/Projects/RcktScore/docs/backend-api.md)
- [docs/technical-walkthrough.md](/Users/glennrowe/Development/Projects/RcktScore/docs/technical-walkthrough.md)

Fast local verification commands:

```bash
PYTHONPYCACHEPREFIX=/tmp/rcktscore-pyc python3 -m py_compile $(find backend/common backend/functions -name '*.py' | sort)
cd frontend && npm run build -- --outDir /tmp/rcktscore-frontend-dist
```
