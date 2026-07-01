# iOS V1 Plan

## Purpose

This document tracks the current native iOS baseline and the remaining work to
turn it into a confident first release.

The immediate product priority is now the iPhone scoring experience.
Foundation, dashboard, match setup, settings, and history are already in place.
The next phase should redesign the live scorer so it feels intentional and safe
for real event-day use on iPhone before broader launch hardening resumes.

## Current Baseline

The native app is well beyond a prototype.

Already in place:

- organisation login for `mobile_app` sessions
- persisted session
- active-session conflict handling with force-logout retry
- register-interest and help flows on login
- dashboard shell with `Home`, `Matches`, `History`, `Settings`, and `Need Help`
- active, scheduled, and recent match loading
- native start-new-match flow with sport picker
- player and referee lookup suggestions
- court selection plus automatic scheduled fallback when a court is busy
- handicap setup and tier-aware shirt-colour handling
- scheduled match start
- live scoring with warm-up, first-server selection, score taps, stroke, let,
  undo, early end, serve-side changes, in-match game settings, completed-game
  strip, and event timeline
- warm-up, interval, and match timer flow
- historic-match timeline with grouped point history and game-duration summary
- history search and separate matches/history views
- native club settings sections for organisation details, users, and courts
- native organisation, user, court, and court display-code mutations through the
  existing backend
- in-app feedback and password-reset request flow

## Current Gaps

These are the main gaps still visible in the current iOS build:

- iOS login does not yet expose the backend `organizationSelection` branch for
  multi-membership users
- the live scoring screen is functionally rich but visually crowded on iPhone
- the timer, match details, secondary controls, and destructive actions compete
  too strongly in the current scoring layout
- there is no documented mobile CI/archive/release pipeline yet
- there is no completed realtime/WebSocket sync path yet
- release-grade automated and manual signoff coverage is still missing
- iPad polish still needs a final hardening pass after scoring redesign

## Device Targets

### Primary

1. iPhone portrait
2. iPad portrait

### Secondary

1. iPad landscape

The design should continue to feel mobile-first. iPad should be polished enough
for live operational use, but not at the expense of slowing down the iPhone
release.

## Next Active Workstream

### Phase 4: iPhone Scoring Redesign

Goal:

- keep the current scorer feature set, but redesign the screen around iPhone
  usability, visual hierarchy, and safer match control

Required work:

1. make the live score the dominant visual focus
2. separate primary scoring actions from secondary match-management actions
3. clarify warm-up, first-server, and timer phases so the scorer always knows
   the current match state
4. reduce below-the-fold dependence for common scoring actions
5. move destructive actions into a safer visual and interaction pattern
6. decide whether completed-game history and detailed timeline belong inline,
   collapsed, or in a secondary surface
7. preserve existing backend contracts and event behavior while changing the UI

Definition of done:

- common scoring actions feel fast and comfortable one-handed on a typical
  iPhone
- the scorer can always see match state, current score, and next likely action
- secondary controls no longer compete with the main scoring task
- the layout is cleaner without dropping warm-up, timer, undo, or settings
  capability

### Phase 5: Launch Hardening

Goal:

- validate the redesigned scorer and turn the current app into a shippable v1

Required work:

1. manual iPhone regression across login, dashboard, setup, scoring, history,
   settings, and help
2. iPad portrait and landscape pass
3. session-expiry and session-replacement handling verification
4. docs, release notes, and signoff checklist refresh
5. decision on how multi-organisation membership selection should work in iOS

Definition of done:

- manual launch checklist passes cleanly
- there is no known blocker that sends scorers back to the web app for normal
  club event-day use

## Release Gate

Do not proceed to release if:

1. scoring can get stuck mid-match
2. the redesigned scorer hides or slows common operator actions
3. scheduled matches cannot be started reliably from iPhone
4. session bugs sign users out unexpectedly
5. the app still lacks a clear decision for multi-membership login behavior

## Deferred For Later

These items should stay out of the immediate scoring redesign unless they become
blocking:

1. root admin tools
2. full spectator-display configuration
3. WebSocket/live sync parity beyond the current refresh model
4. full offline scoring sync
5. deep notification center flows behind the dashboard bell
6. Android/native cross-platform work
