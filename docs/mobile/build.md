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
9. Verify About, Profile, and Subscription are the first three settings rows.
10. Open Help & Feedback, review the Privacy & Data page, and confirm its online policy link resolves.
11. With a test personal account, verify both deletion confirmations appear. Cancel each stage during routine regression; perform one end-to-end destructive deletion only against a disposable account in the deployed test stack.
12. Verify the initial online bell is yellow, opening Notifications marks the welcome notice read, and the bell returns white. Confirm offline mode still replaces it with the offline icon.

Optional CLI smoke:

```bash
xcodebuild -project mobile/ios/RcktScoreMobile/RcktScoreMobile.xcodeproj -scheme RcktScoreMobile -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/RcktScoreMobileDerivedData build
```

## Current Known Gaps

- there is no documented CI build pipeline yet
- there is no documented archive/sign/distribute workflow yet
- there is no documented release build-number policy yet
- some local CLI builds fail before completion if the machine has no working iPhone simulator runtimes available to Xcode asset tooling
- notification inbox delivery and read state are backend-backed; there is no APNs push-notification path yet
- local StoreKit testing uses `HitnScore.storekit` selected under Scheme > Run > Options; in Debug, tap Personal Plus to expose monthly/yearly purchase, restore, and manage controls for 20 seconds. The app refreshes StoreKit entitlements on foreground, but the green outline and pink Current badge follow the latest backend organisation plan until server verification is implemented. Release purchasing remains disabled pending backend verification
- offline scoring supports one cached active match, but offline history and offline match creation remain incomplete

## Current Release Readiness

The iOS codebase is a serious testable client and is already useful on device,
but the repository still does not document a complete mobile release process or
the final launch signoff gate.
