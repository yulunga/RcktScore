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
- active-session conflict handling is implemented for `mobile_app` sessions
- dashboard shell includes `Home`, `Matches`, `History`, `Settings`, and `Need Help`
- dashboard loads active, scheduled, and recent matches
- native start-new-match flow includes sport selection, player/referee lookups,
  court selection, handicap setup, and scheduled fallback for busy courts
- scheduled matches can be started from the native dashboard and scorer screen
- live scoring supports warm-up, first-server selection, score taps, stroke,
  let, undo, early end, serve-side toggle, match details, completed-game strip,
  event timeline, and in-match game settings
- native historic-match view includes grouped point timeline plus match/game
  timing
- native settings support organisation details, user management, court
  management, and display-code regeneration for club accounts
- native help flows support in-app feedback and password reset requests

Known gaps before launch:

- multi-organisation membership selection is not yet exposed in the iOS login flow
- the current scoring layout is functional but still needs an iPhone-first UX redesign
- final release hardening and regression signoff are still outstanding
- no documented mobile CI/archive/release pipeline yet
- no completed mobile realtime/WebSocket path yet
