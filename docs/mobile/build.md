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
2. Build for an iPhone simulator or connected device.
3. Run the app and verify organisation login.
4. Verify dashboard loading for active, scheduled, and recent matches.
5. Open `Start New Match` and verify:
   - the sport picker only shows enabled and implemented sports
   - the setup screen remains readable on a device using system dark mode
6. Open an active match and verify:
   - score point
   - event action
   - undo
   - end match
7. Open a scheduled match and verify start-then-score flow.
8. Open Settings and verify the current menu structure and any launch-critical admin saves.

Optional CLI smoke:

```bash
xcodebuild -project mobile/ios/RcktScoreMobile/RcktScoreMobile.xcodeproj -scheme RcktScoreMobile -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/RcktScoreMobileDerivedData build
```

## Current Known Gaps

- there is no documented CI build pipeline yet
- there is no documented archive/sign/distribute workflow yet
- there is no documented release build-number policy yet
- some local CLI builds fail before completion if the machine has no working iPhone simulator runtimes available to Xcode asset tooling
- native notification-center behavior behind the dashboard bell is not implemented yet
- offline scoring and offline history are still incomplete

## Current Release Readiness

The iOS codebase is a serious testable client and is already useful on device,
but the repository still does not document a complete mobile release process or
the final launch signoff gate.
