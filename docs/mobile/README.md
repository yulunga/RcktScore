# Mobile Docs

This folder contains mobile-platform setup and delivery guidance for developers
working on a native app from the same repository.

Current documents:

- `setup.md`
- `signing.md`
- `build.md`
- `release-notes.md`
- `ios-v1-plan.md`

## Current iOS State

The native iOS app scaffold now exists in `mobile/ios/RcktScoreMobile/`.
It includes organisation login, session persistence, dashboard loading, scheduled
match start, and a live scoring screen that calls the existing v2 backend.

The main remaining v1 gap is native timer parity with the web scorer:
warm-up phases, first-server selection after warm-up, and the 90 second
between-game interval.
