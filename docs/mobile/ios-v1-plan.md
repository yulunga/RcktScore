# iOS V1 Plan

## Purpose

This document tracks the current native iOS baseline and the remaining work to
turn it into a confident first release.

The native app now covers the main day-of-use journeys, including native match
setup, settings, history, and first-pass tennis support. The remaining work is
less about proving the app concept and more about finishing release hardening,
closing unsupported edge cases, and polishing the last iPhone-first flows.

## Current Baseline

The native app is well beyond a prototype.

Already in place:

- organisation login for `mobile_app` sessions
- persisted session
- active-session conflict handling with force-logout retry
- multi-organisation membership selection at login and association switching
- optional local Face ID / Touch ID unlock for a saved session
- server-provided session expiry with mandatory fresh login after expiry
- self-service personal-account signup, controlled club enquiries, and help flows on login
- dashboard shell with `Home`, `Matches`, `History`, `Settings`, and `Need Help`
- active, scheduled, and recent match loading
- native start-new-match flow with sport picker
- player and referee lookup suggestions
- court selection plus automatic scheduled fallback when a court is busy
- handicap setup and tier-aware shirt-colour handling
- enabled-sport-aware native setup flow for squash, racketball, and tennis
- scheduled match start
- live scoring with warm-up, first-server selection, score taps, stroke, let,
  undo, early end, serve-side changes, in-match game settings, completed-game
  strip, event timeline, and first-pass tennis scoring
- warm-up, interval, and match timer flow
- historic-match timeline with grouped point history and game-duration summary
- history search and separate matches/history views
- native plan-aware settings menus for subscription, profile, association,
  racket sports, game settings, help, and club-admin tools
- native organisation, user, court, and court display-code mutations through the
  existing backend
- native password-reset access from login and from settings
- local profile photo picking in native settings
- in-app feedback and password-reset request flow
- quieter offline dashboard behavior that no longer leaves a persistent fetch
  error visible when the device is offline
- a device-persisted cache for one previously opened active match, local squash/racketball and tennis scoring, ordered reconnect replay, and UUID duplicate-action protection

## Current Gaps

These are the main gaps still visible in the current iOS build:

- the live scoring screen is much better than the earlier layout, but still
  needs final small-screen polish and confidence-building QA
- native tennis now covers online and offline game/set/tie-break transitions plus singles/doubles service and receiver order, but still needs broader device regression coverage
- the dashboard bell has no real notification-center flow yet
- settings areas for association links, account-level game-settings presets,
  reporting, and stats are still placeholder surfaces
- offline history, offline match creation, scheduled activation, settings changes, and multi-match caching remain outside the current offline scope
- offline scoring still needs physical-device Airplane Mode, app-termination, long-queue, session-expiry, and reconnect signoff
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

### Phase 4: Final UX And Edge-Case Polish

Goal:

- keep the current feature set, but finish the last polish needed for iPhone
  confidence and predictable edge-case handling

Required work:

1. finish iPhone scorer polish across squash/racketball and tennis
2. validate dark-mode device behavior for flows that intentionally force light presentation
3. decide what the dashboard bell should do at launch if notifications remain unimplemented
4. decide whether placeholder settings sections should stay visible at launch
5. preserve existing backend contracts and event behavior while tightening the UX

Definition of done:

- common scoring actions feel fast and comfortable one-handed on a typical
  iPhone
- the scorer can always see match state, current score, and next likely action
- the launch build no longer contains obvious dead-end UI affordances
- the layout is cleaner without dropping warm-up, timer, undo, or settings capability

### Phase 5: Launch Hardening

Goal:

- validate the redesigned scorer and turn the current app into a shippable v1

Required work:

1. manual iPhone regression across login, dashboard, setup, scoring, history,
   settings, and help
2. iPad portrait and landscape pass
3. session-expiry and session-replacement handling verification
4. docs, release notes, and signoff checklist refresh
5. regression coverage for multi-organisation selection and association switching
6. decision on whether placeholder settings sections ship or are hidden
7. add and validate account-deletion initiation for self-service personal accounts
8. add the required privacy manifest where the final archive uses required-reason APIs, and complete App Store privacy disclosures

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
5. multi-membership login or association switching fails to preserve the
   selected organisation correctly
6. the launch build still contains visible placeholder/dead-end flows that confuse users

## Deferred For Later

These items should stay out of the immediate scoring redesign unless they become
blocking:

1. root admin tools
2. full spectator-display configuration
3. WebSocket/live sync parity beyond the current refresh model
4. offline history, offline match creation, and multi-match caching
5. deep notification center flows behind the dashboard bell
6. Android/native cross-platform work
