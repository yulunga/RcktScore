# Mobile Build

## Purpose

This document captures the current local build and verification reality for the
native iOS app in this repository.

## Current Project Location

- project: `mobile/ios/RcktScoreMobile/RcktScoreMobile.xcodeproj`
- scheme: `RcktScoreMobile`
- app target: `RcktScoreMobile`

## Current Runtime Dependency Model

The iOS app calls the same backend used by the web app.

Runtime configuration is read through:

- `Config.plist`
- `AppConfig.swift`

The app can fall back to a configured backend URL when local configuration is
not overridden.

## Recommended Local Verification

1. Open the project in Xcode.
2. Build for an iPhone simulator.
3. Run the app and verify organisation login.
4. Verify dashboard loading for active, scheduled, and recent matches.
5. Open an active match and verify:
   - score point
   - event action
   - undo
   - end match
6. Open a scheduled match and verify start-then-score flow.

## Current Known Gaps

- there is no documented CI build pipeline yet
- there is no documented archive/sign/distribute workflow yet
- there is no documented release build-number policy yet
- native timer/warm-up parity still trails the web scorer

## Current Release Readiness

The iOS codebase is an active client implementation and useful for development
and validation, but the repository does not yet document a complete mobile
release process.
