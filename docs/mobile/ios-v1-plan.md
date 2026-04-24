# iOS V1 Build Plan

## Purpose

This document turns the current native iOS scaffold into a concrete build plan
for a first usable organisation-user release.

The target is not feature parity with the full web app. The target is a stable,
score-first iPhone app that reuses the existing `RcktScore` backend and follows
the current mobile web scoring UX.

## Reference Experience

Use the mobile web flow as the visual and interaction reference for v1:

1. organisation login
2. dashboard with active and scheduled matches
3. live scoring screen
4. end / undo / stroke / let actions

Design principle:

- one backend
- one API contract
- one scoring rules engine
- separate native SwiftUI presentation layer

## Current State

Already present:

- Xcode project exists in `mobile/ios/RcktScoreMobile/`
- login screen exists
- session persistence exists
- API envelope handling exists
- dashboard loads active, scheduled, and recent matches
- scheduled matches can be started from the dashboard
- live match scoring screen exists with score taps, stroke, let, undo, early end, serve-side toggle, details, completed-game strip, and event timeline
- native timer flow now includes warm-up, first-server selection, interval breaks, live match timing, and match-duration capture

Still outstanding for the first native release:

- native new-match setup remains out of scope for this release

## V1 Scope

### In Scope

1. Organisation login
2. Session persistence
3. Dashboard
4. Active matches
5. Scheduled matches
6. Start scheduled match
7. Live scoring screen
8. Score point
9. Stroke / let
10. Undo last action
11. End match early
12. Match details toggle
13. Match event timeline

### Out Of Scope For First Native Release

1. Root admin portal
2. Organisation settings management
3. Court/user CRUD
4. Ping Us flow
5. New match setup in native
6. Spectator display configuration
7. Full timer parity with web warm-up overlays
8. iPad landscape optimisation

## Delivery Order

### Milestone 1: Foundation

Goal:

- make the existing shell production-usable as a signed-in app skeleton

Tasks:

1. Confirm bundle, deployment target, and environment config are sane
2. Keep login/session flow stable
3. Keep API contract aligned with the backend success/error envelope

Definition of done:

- app launches
- user can log in
- user stays logged in across relaunch

### Milestone 2: Dashboard

Goal:

- show the same operational dashboard concepts as the mobile web app

Tasks:

1. Extend dashboard models for:
   - `active_matches`
   - `scheduled_matches`
   - `recent_matches`
2. Replace the current `List`-only dashboard with a score-first mobile layout
3. Add scheduled match start action
4. Keep navigation into live scoring

Definition of done:

- active and scheduled matches both render
- a scheduled match can be started from the dashboard
- tapping active or scheduled matches opens live scoring

### Milestone 3: Live Match Screen

Goal:

- reproduce the current mobile web scoring experience in SwiftUI

Required UI:

1. court name
2. active status
3. score/game/best-of chip
4. player score cards
5. current serve badge
6. point-order rail
7. completed-game strip
8. scoring control rows
9. match details toggle
10. event timeline

Required behaviors:

1. tapping player score adds a point
2. stroke P1 / let / stroke P2 actions work
3. undo works
4. end match early works
5. serve side can be changed
6. screen reload refetches live state

Definition of done:

- a scorer can run a live match entirely from the native screen

### Milestone 4: Match Timer

Goal:

- add native timer behavior matching the current mobile web flow

Tasks:

1. warm-up ready overlay
2. 60 second side 1 warm-up
3. side swap prompt
4. 60 second side 2 warm-up
5. auto-start match clock
6. 90 second game-break overlay
7. clock tap to pause/resume

Definition of done:

- timer behavior mirrors the current web scoring flow closely enough for live use

## File Ownership

### Native App Entry / State

- `mobile/ios/RcktScoreMobile/RcktScoreMobile/RcktScoreMobileApp.swift`
- `mobile/ios/RcktScoreMobile/RcktScoreMobile/ContentView.swift`
- `mobile/ios/RcktScoreMobile/RcktScoreMobile/State/AppContainer.swift`
- `mobile/ios/RcktScoreMobile/RcktScoreMobile/State/SessionStore.swift`

### API Layer

- `mobile/ios/RcktScoreMobile/RcktScoreMobile/Services/APIClient.swift`
- `mobile/ios/RcktScoreMobile/RcktScoreMobile/Services/AppConfig.swift`

### Models

- `mobile/ios/RcktScoreMobile/RcktScoreMobile/Models/APIEnvelope.swift`
- `mobile/ios/RcktScoreMobile/RcktScoreMobile/Models/UserSession.swift`
- `mobile/ios/RcktScoreMobile/RcktScoreMobile/Models/MatchSummary.swift`

### Views

- `mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/LoginView.swift`
- `mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/DashboardView.swift`
- `mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/MatchScoringView.swift`

## API Methods Needed For V1

### Already Present

1. `POST /login`
2. `GET /dashboard/{organization_id}`

### Present In Native Client

These methods are now present in `APIClient.swift`:

1. `GET /get_score/{match_id}`
2. `POST /score_point`
3. `POST /event_action`
4. `POST /undo_action`
5. `POST /end_match`
6. `POST /start_scheduled_match`

## Minimum Model Set Needed For Live Scoring

1. `MatchDetail`
2. `MatchState`
3. `MatchEvent`
4. `MatchEventPayload`
5. `GameHistoryEntry`
6. `MatchMutationResponse`

## Visual Rules For Native V1

1. Follow the current mobile web scoring layout before inventing a new native look
2. Prioritise speed and tap clarity over high information density
3. Keep player scores large and central
4. Keep destructive actions visually separate
5. Hide secondary details behind a toggle by default

## Verification Plan

### Functional

1. Login succeeds
2. Dashboard loads
3. Match opens
4. Score point updates backend state
5. Undo reverses last action
6. Stroke and let actions work
7. End match early completes the match

### UX

1. Score tap area is large enough for one-handed use
2. Names and scores do not jump while scoring
3. Timeline stays scrollable and does not expand the scoring area

## Immediate Next Step

Validate the native timer flow on-device and then decide whether the next iOS
increment should focus on:

1. WebSocket/live sync for multi-device scoring visibility
2. Native new-match setup
3. iPad/layout polish for larger screens
