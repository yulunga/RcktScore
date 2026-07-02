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
- Native runtime configuration: `Config.plist` and `AppConfig.swift`

## Current Mobile Scope

Current implemented native scope:

1. organisation login
2. persisted session
3. mobile dashboard with active, scheduled, and recent matches
4. native start-new-match flow with sport picker, lookup suggestions, court selection, and scheduled fallback
5. live scoring match screen for squash/racketball plus first-pass tennis
6. historic match viewer
7. native settings and help flows

Current remaining v1 scope:

1. multi-organisation membership selection in iOS login
2. final iPhone scoring and settings polish
3. release-grade QA, CI/archive notes, and signoff process

Still out of scope for the first native release:

1. root admin portal
2. full offline scoring sync
3. deep notification-center flows
4. live padel, table tennis, badminton, and pickleball scoring

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
