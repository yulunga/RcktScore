# Mobile Setup

## Purpose

This document is the starting point for a developer building a native mobile
client in the `RcktScore` repository.

## Repository Areas

- `mobile/ios/` native iOS workspace location
- `mobile/shared/` shared mobile-facing contracts and state references
- `docs/backend-api.md` backend endpoint and contract reference
- `docs/technical-walkthrough.md` request lifecycle and end-to-end flows

## Current Platform Dependencies

- Frontend hosting: AWS Amplify
- Backend: AWS SAM / Lambda
- Database: Supabase Postgres
- Active API base URL:
  `https://st3nn5zsm6.execute-api.eu-west-2.amazonaws.com/prod`

## Mobile App Starting Scope

Recommended first mobile scope:

1. organisation login
2. mobile dashboard
3. live scoring match screen
4. spectator display handoff/open

## Environment Guidance

The mobile app should support environment-based API configuration instead of
hardcoding endpoints in code.

Recommended values:

- `development`
- `staging`
- `production`

## References

- `AGENTS.md`
- `docs/backend-api.md`
- `docs/technical-walkthrough.md`

