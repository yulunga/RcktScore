# Mobile Release Notes

This document tracks native mobile release history for the iOS app in
`mobile/ios/RcktScoreMobile/`.

Suggested format:

## Version

- release date
- build number
- key features
- bug fixes
- known issues

## Current State

TestFlight builds have already been produced from this repository for testing.
An App Store launch has not been completed yet.

Current unreleased iOS build state:

- organisation login and persisted session are implemented
- dashboard shell now includes `Home`, `Matches`, `History`, `Settings`, and `Need Help`
- dashboard loads active, scheduled, and recent matches
- native start-new-match flow is implemented
- scheduled matches can be started from the native dashboard
- live scoring supports score taps, stroke, let, undo, early end, serve-side toggle, match details, completed-game strip, and event timeline
- native timer flow includes warm-up, interval, and match-duration behavior
- native settings now supports organisation details, user management, and court management for club accounts
- native scorer now supports in-match game settings editing, scheduled-match edit entry, and spectator display visibility
- final release hardening and regression signoff are still outstanding before launch
