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

## Current Mobile Scope

Current implemented native scope:

1. organisation login
2. persisted session
3. mobile dashboard with active, scheduled, and recent matches
4. scheduled match start
5. live scoring match screen

Current remaining v1 scope:

1. native timer/warm-up parity with the web scoring screen
2. first-server selection after warm-up
3. 90 second between-game interval

Still out of scope for the first native release:

1. native new-match setup
2. organisation settings management
3. root admin portal
4. spectator display configuration

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
