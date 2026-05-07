# Mobile Docs

This folder contains current mobile-platform notes for the native iOS app that
ships from the same repository as the web and backend code.

Current documents:

- `setup.md`
- `signing.md`
- `build.md`
- `release-notes.md`
- `ios-v1-plan.md`

## Current iOS State

The native iOS project exists in `mobile/ios/RcktScoreMobile/`.

What the current app does:

- organisation-user login against the shared v2 backend
- session persistence on-device
- dashboard loading
- active and scheduled match access
- scoring against the shared backend routes

What it does not yet match perfectly:

- full parity with the web scorer warm-up flow
- first-server selection parity
- timer and interval behavior parity
- documented CI/archive/release pipeline

Current iOS should be treated as an active client implementation, but not yet as
a fully packaged mobile release program.
