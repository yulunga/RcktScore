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
- persisted session state
- dashboard loading
- active and scheduled match access
- scoring against the same backend routes used by the web app

Current limitations:

- native timer/warm-up flow does not yet fully match the web scorer
- no documented mobile CI/archive/release pipeline yet
- no completed mobile realtime/WebSocket path yet

Use the dedicated docs in [docs/mobile](../docs/mobile/README.md) for current
setup, build, and release guidance.
