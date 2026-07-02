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
- the dashboard no longer leaves a persistent fetch-failure banner behind when the device is offline
- native start-new-match flow includes sport selection, player/referee lookups,
  court selection, handicap setup, and scheduled fallback for busy courts
- native sport selection currently exposes the implemented and enabled sports:
  squash, racketball, and tennis
- the native match-setup flow now uses the same adaptive dark/light styling as
  the rest of the app and allows personal-tier squash/racketball handicap setup
- scheduled matches can be started from the native dashboard and scorer screen
- live scoring supports warm-up, first-server selection, score taps, stroke,
  let, undo, early end, serve-side toggle, match details, completed-game strip,
  event timeline, in-match game settings, and first-pass tennis scoring
- native historic-match view includes grouped point timeline plus match/game
  timing
- native settings support plan-aware account menus, local profile photo
  selection, self-profile editing, password-reset access, association
  switching, organisation details, user management, court management,
  racket-sport visibility, and display-code regeneration for club accounts
- each settings menu row now opens its own dedicated page rather than expanding inline
- native help flows support in-app feedback and password reset requests
- native login now supports organisation selection when the same email belongs
  to multiple approved clubs/accounts

Known gaps before launch:

- the current scoring layout is much stronger but still needs final iPhone-first UX polish
- the dashboard bell does not yet open a real notification center
- deeper association/federation links, account-level game settings, reporting,
  and stats are still placeholder sections in native settings
- profile photos are still stored locally on the device rather than in a central shared profile store
- offline history and offline scoring sync are still incomplete
- final release hardening and regression signoff are still outstanding
- no documented mobile CI/archive/release pipeline yet
- no completed mobile realtime/WebSocket path yet
