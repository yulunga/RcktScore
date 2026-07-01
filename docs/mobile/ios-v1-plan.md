# iOS Launch Plan

## Purpose

This document turns the current native iOS build into a concrete launch plan for
an initial public release that is operationally aligned with the current mobile
web experience.

The release priority is:

1. club and club elite scoring flows
2. iPhone usability
3. iPad usability
4. personal-tier consistency where it overlaps with the same scorer journey

The goal is not 100% web parity across every screen. The goal is a release that
lets real scorers run matches confidently on iPhone and iPad without needing to
drop back to the web app for core club workflows.

## Current Position

The native app is now beyond a basic scorer prototype.

Already in place:

- organisation login
- persisted session
- register interest and help flows on login
- dashboard shell with `Home`, `Matches`, `History`, `Settings`, and `Need Help`
- active, scheduled, and recent match loading
- native start-new-match flow
- scheduled match start
- live scoring with stroke, let, undo, early end, serve-side changes
- warm-up, interval, and match timer flow
- basic history search
- native club settings sections for organisation details, users, and courts
- native organisation and court administration mutations through the existing backend

This means the release is now primarily a parity and hardening exercise rather
than a greenfield build.

### Completed Launch Phases

The following launch phases are now complete:

1. Phase 1: Data And API Parity
2. Phase 2: Club Settings

## Launch Decision

### Release When

Release once all `Must Have Before Launch` items are complete, manual testing is
green on iPhone and iPad, and the critical regression set is documented and
repeatable.

### Do Not Release If

- scorers still need the web app for critical club match administration
- in-match settings are only available on the web app
- settings/courts/users are incomplete for the intended club release audience
- session, scoring, or scheduled-match flows are not stable under repeat testing

## Parity Snapshot

### Strong

- login and session flow
- dashboard shell and small-screen styling direction
- new match creation flow
- live match scoring
- timer behavior
- native organisation details, users, and courts management

### Partial

- matches tab parity with web mobile
- history browsing and filtering
- deeper club settings breadth
- help and support flows

### Missing Or Not Release-Ready

- native in-match game settings editing
- spectator/display tooling parity
- release-grade automated and manual signoff coverage

## Must Have Before Launch

### 1. Club Settings Parity

The iOS app must support the club workflows that are most likely to block match
operations on event day.

Required:

1. organisation details view/edit
2. court list view
3. create/edit court
4. organisation users list view
5. add/edit user role where supported by backend permissions
6. game settings view/edit if those settings affect match setup or scoring

Definition of done:

- a club admin can perform the common day-to-day settings tasks from iPhone and
  iPad without switching to the web app

### 2. In-Match Settings Parity

The scorer must be able to manage the same key in-match controls as the web app.

Required:

1. native game settings overlay
2. match settings save/update flow
3. shirt colour editing where tier allows it
4. clear scheduled-match edit path from the iOS app

Definition of done:

- a scorer can change the important match configuration from within the app

### 3. Matches And History Parity

The post-login experience must match the current mobile-web information flow.

Required:

1. `Matches` screen shows all active first, then scheduled, in a clean vertical
   list
2. `History` screen shows completed matches only
3. history search supports player names and date text
4. scheduled match cards surface edit/start actions clearly

Definition of done:

- the iOS navigation model no longer feels materially behind mobile web

### 4. Release Hardening

Required:

1. graceful handling for session replacement and expired sessions
2. stable empty states and error states
3. loading-state polish on slower networks
4. no obviously broken iPad layouts in portrait or landscape
5. current mobile docs updated to match shipped scope

Definition of done:

- the app feels intentional and stable, not like a partial internal build

## Safe To Defer

These items should not block the first release unless the rollout audience says
they are mandatory.

1. root admin tools
2. full spectator-display configuration
3. WebSocket/live sync parity beyond the current refresh model
4. full offline scoring sync
5. deep notification center flows behind the dashboard bell
6. Android/native cross-platform work

## Recommended Delivery Order

### Phase 1: Data And API Parity

Goal:

- expand the iOS data layer so settings and in-match administration are
  possible

Required work:

1. extend `APIClient.swift` with organisation details, user, court, and match
   settings endpoints
2. expand iOS settings models beyond organisation summary plus courts
3. confirm tier gating remains aligned with web

Exit criteria:

- all required backend calls for launch-critical parity exist in the native
  client

Status:

- completed

### Phase 2: Club Settings

Goal:

- make the `Settings` tab useful for club admins

Required work:

1. organisation details UI
2. court management UI
3. users/roles UI
4. game settings UI if used operationally

Exit criteria:

- club admin can complete common settings tasks entirely from iOS

Status:

- completed for organisation details, user management, and court management
- deeper match-side configuration remains part of Phase 3 scorer parity work

### Phase 3: Scorer Parity

Goal:

- remove the remaining scorer-side reasons to switch back to web

Required work:

1. native in-match settings overlay
2. scheduled match edit flow
3. history and matches screen polish
4. any must-have spectator/display visibility if required for launch

Exit criteria:

- a scorer can create, edit, run, and complete a club match from iOS

### Phase 4: Release Hardening

Goal:

- turn a working app into a shippable app

Required work:

1. cleanup of edge-case UI states
2. regression pass on iPhone and iPad
3. release notes and docs refresh
4. final signoff checklist

Exit criteria:

- manual launch checklist passes cleanly

## Device Targets

### Primary

1. iPhone portrait
2. iPad portrait

### Secondary

1. iPad landscape

The design should continue to feel mobile-first. iPad should be polished enough
for live operational use, but not at the expense of slowing down the iPhone
release.

## Launch Testing Gate

### Functional Must-Pass

1. login
2. logout
3. session replacement handling
4. dashboard load
5. create immediate match
6. create scheduled match
7. start scheduled match
8. score live match
9. undo action
10. end match
11. history entry appears correctly
12. settings changes persist correctly

### UX Must-Pass

1. score tap targets are comfortable one-handed
2. scheduled and active lists are readable on iPhone and iPad
3. long names do not break key layouts
4. overlays can be dismissed cleanly
5. support/help flow is reachable when a user gets stuck

### Failure Conditions

Do not proceed to release if:

1. scoring can get stuck mid-match
2. scheduled matches cannot be edited or started reliably
3. settings screens are incomplete for the intended launch tier
4. there are session bugs that sign users out unexpectedly

## Final Release Recommendation

Ship the first native release as a **club-first scorer app** rather than as a
claim of total web parity.

Recommended positioning:

- strong native scorer workflow
- strong small-screen club dashboard
- enough settings/control for real club use
- clear list of intentionally deferred secondary features

## Immediate Next Step

Implement the launch-critical parity work in this order:

1. native in-match game settings and scheduled-match edit flow
2. matches and history polish against current mobile web behaviour
3. manual iPhone/iPad launch regression pass
4. release notes and final launch checklist review
