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
- password reset, register-interest, and feedback email flows

Important current gaps:

- org-user session enforcement exists in the backend
- root-admin backend authorization is not fully implemented yet
- some root-admin organisation actions still rely on the `x-root-admin-request` header as a bypass
- WebSocket infrastructure is only partially implemented
- some settings UI remains scaffold-only
- there is no automated backend/frontend test suite checked into this repository yet

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
