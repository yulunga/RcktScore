# Mobile Workspace

This directory contains the native mobile work that lives alongside the web
frontend and Lambda backend.

Current structure:

- `ios/` contains the active SwiftUI iOS client
- `shared/` contains mobile-facing contracts, state notes, and documentation references

## Current Mobile Reality

The iOS app is no longer just a placeholder folder.

Current implementation includes:

- organisation-user login against the shared v2 backend
- persisted session state and active-session conflict handling
- dashboard tabs for home, matches, history, settings, and help
- active, scheduled, and recent match access
- native match setup, scheduled start, historic-match viewing, and club settings
- scoring against the same backend routes used by the web app

Current limitations:

- multi-organisation membership selection is not yet exposed in the iOS login flow
- the current iPhone scoring layout is functional but due for redesign
- no documented mobile CI/archive/release pipeline yet
- no completed mobile realtime/WebSocket path yet

Use the dedicated docs in [docs/mobile](../docs/mobile/README.md) for current
setup, build, and release guidance.
