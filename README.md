# RcktScore v2

RcktScore v2 is the active application in this repository.

Current implementation:

- `frontend/` is the React + Vite web app
- `backend/` is the AWS Lambda + SAM backend
- `mobile/` contains the native iOS app and shared mobile references
- `infrastructure/` contains deployment notes and reference config
- `version1/` is the legacy Flask application kept only as reference

## Current Product State

The codebase currently supports:

- organisation-user login with session tokens
- multi-organisation user selection after login when the same email belongs to more than one organisation
- organisation dashboard, settings, courts, and user administration
- match creation, scheduled matches, live scoring, undo, and manual match end
- public display screen for a single match
- root-admin screens for clubs, interest requests, and personal accounts
- self-service personal-account signup, controlled club enquiries, password reset, and feedback email flows

Important current gaps:

- org-user session enforcement exists in the backend
- root-admin routes now enforce expiring backend session tokens; broader rate limiting and audit hardening still remain before launch
- WebSocket infrastructure is only partially implemented
- some settings UI remains scaffold-only
- backend pytest unit tests and a Playwright public-route smoke suite are checked
  in under `testing/automated/`, but coverage is still an early baseline and is
  not wired into a documented CI pipeline

## Documentation Map

Start here when orienting or troubleshooting:

- [Repository operating guide](./AGENTS.md)
- [Backend API reference](./docs/backend-api.md)
- [Technical walkthrough](./docs/technical-walkthrough.md)
- [Troubleshooting guide](./docs/troubleshooting.md)
- [Feature and pricing structure](./docs/feature-payments-structure.md)
- [Mobile docs](./docs/mobile/README.md)

## Quick Verification

Useful local checks for the current repo shape:

1. Backend syntax check:

```bash
PYTHONPYCACHEPREFIX=/tmp/rcktscore-pyc python3 -m py_compile $(find backend/common backend/functions -name '*.py' | sort)
```

2. Frontend production build without touching the checked-in `dist/` directory:

```bash
cd frontend
npm run build -- --outDir /tmp/rcktscore-frontend-dist
```

The scratch `outDir` is recommended because the existing `frontend/dist/` folder may not always be removable in local environments.

3. Backend unit tests (after installing
   `testing/automated/backend/requirements-test.txt`):

```bash
pytest -c testing/automated/backend/pytest.ini testing/automated/backend
```

4. Web public-route smoke tests (after installing Playwright and its browsers as
   described in `testing/automated/web/README.md`):

```bash
cd frontend
npm run test:e2e:smoke
```
