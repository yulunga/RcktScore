# Android App Parity Plan

## Purpose

This is a practical, high-level plan for adding a native Android app that has
the same user-visible capabilities as the current native iOS app.

It is a plan only. There is no Android project or Android implementation in the
repository yet.

"Identical" should mean the same accounts, entitlements, matches, scoring
rules, offline guarantees, and settings outcomes. The Android interface should
still follow Android conventions rather than copying SwiftUI layouts pixel for
pixel.

## Recommended Direction

Build a native Kotlin app in `mobile/android/` using:

- Jetpack Compose and Material 3 for UI
- a single-activity app with Compose navigation
- screen-level `ViewModel` classes exposing immutable `StateFlow` UI state
- repositories between ViewModels and network/local storage
- Kotlin coroutines for asynchronous work
- Room for the cached active match and ordered offline-action queue
- DataStore for non-sensitive preferences
- Android Keystore plus `BiometricPrompt` for the optional saved-session unlock
- WorkManager for durable reconnect/background synchronisation where appropriate
- Google Play Billing for Android Personal Plus purchases

This follows current [Android architecture recommendations](https://developer.android.com/topic/architecture/recommendations),
including a distinct UI layer, repository-backed data layer, unidirectional
data flow, Compose, ViewModels, coroutines, and flows.

Do not start by converting the whole mobile product to a cross-platform UI
framework. The iOS client is already substantial and stable enough to act as a
behavioural reference. Native Kotlin is the shortest route to predictable
Android behaviour without destabilising iOS. Shared executable scoring logic
could be evaluated later, after parity tests exist on both platforms.

## Sources Of Truth

Use these in this order when Android behaviour is unclear:

1. the backend response and authorization rules
2. the current iOS implementation
3. the web app, where it exposes the same flow
4. product documentation

Important references:

- `docs/backend-api.md`
- `docs/technical-walkthrough.md`
- `mobile/ios/RcktScoreMobile/RcktScoreMobile/Services/APIClient.swift`
- `mobile/ios/RcktScoreMobile/RcktScoreMobile/Models/`
- `mobile/ios/RcktScoreMobile/RcktScoreMobile/State/SessionStore.swift`
- `mobile/ios/RcktScoreMobile/RcktScoreMobile/State/OfflineMatchStore.swift`
- `mobile/ios/RcktScoreMobile/RcktScoreMobile/State/RacketPointRailReducer.swift`
- `mobile/ios/RcktScoreMobile/RcktScoreMobile/State/TennisScoringReducer.swift`
- `mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/`
- `mobile/ios/RcktScoreMobile/RcktScoreMobileUITests/`

The iOS source should be used as a behaviour specification, not translated
line by line. First write down request payloads, response models, state
transitions, error states, and acceptance scenarios; then implement those in
Kotlin.

## Basic Build Steps

### 1. Freeze The Parity Checklist

Before creating screens, record every currently supported iOS journey and its
expected result. The Android v1 parity scope should include:

- login, active-session conflict handling, and organisation selection
- expiring session restore and optional biometric unlock
- Home, Matches, Analytics, Settings, and Need Help navigation
- current, scheduled, and historic match lists with plan-aware gates
- notification inbox and cross-device read state
- Personal Free and Personal Plus entitlements
- Personal Plus performance reporting
- native setup for squash, racketball, tennis, and enabled doubles Padel
- player/referee lookup, courts, colours, handicaps, Golden Point, timers, and
  tennis/Padel lineup options
- match start, scheduling, scheduled activation, scoring, undo, early end, and
  completed summary
- sport-specific historic match display
- one previously opened active match available offline, with queued scoring
  actions replayed in order
- profile, subscription, association switching, racket-sport visibility,
  game-timer defaults, account deletion, club administration, password reset,
  feedback, privacy, and help flows that are live on iOS
- Personal Plus purchase and restore through Google Play once the Android
  billing backend is ready

Do not add root-admin tools or Tournament Manager merely for mobile parity;
those are not part of the current iOS product. Do not claim realtime live sync
or push notifications as Android requirements while they remain incomplete on
iOS.

### 2. Scaffold The Android App

Create one Android application module under `mobile/android/`, with environment
configuration for development, staging, and production API base URLs. Keep
secrets out of source control and use build configuration only for public
environment values.

Suggested package areas:

```text
mobile/android/app/src/main/java/.../
  app/             application, navigation, dependency wiring
  core/network/    API envelope, auth interceptor, error mapping
  core/database/   Room database, cached match, queued actions
  core/security/   encrypted session and biometric access
  data/            API services and repositories
  domain/          scoring reducers and reusable use cases
  feature/auth/
  feature/home/
  feature/matches/
  feature/scoring/
  feature/history/
  feature/analytics/
  feature/settings/
  feature/help/
  billing/
```

Start with phone portrait as the primary layout, then add compact/expanded
adaptive layouts for tablets and foldables. Support light mode, dark mode,
large text, screen readers, and minimum touch-target sizes from the start.

### 3. Port The API Contract, Not The Swift Types

Recreate the request and response models from the live JSON contract. Preserve:

- the `{ success, data, error, meta }` response envelope
- server error codes and human-readable messages
- snake-case JSON field names
- nullable and optional fields exactly as the backend sends them
- `Authorization: Bearer <token>` authentication and session invalidation
  behaviour
- `organization_id` scoping on tenant-aware requests
- `client_action_id` UUIDs on mutable match actions

Build contract tests from captured, anonymised JSON fixtures. These fixtures
should decode in both happy-path and error-path cases. Do not infer scoring
state from labels when the backend supplies a structured value.

### 4. Implement Session And Account Flows

Match iOS login behaviour before building scoring:

1. log in using the backend mobile client contract
2. handle `organizationSelection` and save the chosen membership
3. handle the active-session conflict and explicit force-logout retry
4. store the session token encrypted with an Android Keystore-backed key
5. enforce the server-provided expiry locally
6. clear local access when the backend returns invalid/expired-session errors
7. implement association switching without mixing cached tenant data
8. add optional biometric/device-credential unlock with `BiometricPrompt`

Biometrics should only unlock an unexpired encrypted backend session; they must
not replace backend authentication. Follow Android's
[biometric authentication guidance](https://developer.android.com/identity/sign-in/biometric-auth).

### 5. Build Read-Only Product Flows

Implement the dashboard and read-only screens next: notifications, match lists,
history, analytics, profile, and organisation settings. This validates
navigation, plan gates, membership scoping, model decoding, loading/error
states, and adaptive layouts before scoring mutations are introduced.

The backend remains authoritative for Personal Free/Plus history limits,
performance availability, enabled sports, and permissions. Android may hide
unavailable controls, but must not recreate entitlement rules locally.

### 6. Build Match Setup And Online Scoring

Port match setup in this order:

1. squash and racketball
2. tennis singles
3. tennis doubles
4. Padel doubles

Then implement online scoring actions and presentation. Keep sport reducers
separate, following the existing iOS split between racket point-rail logic and
tennis-style scoring. Padel should reuse the tennis-style engine behaviour but
retain its receiving-partner choice at Golden Point.

The server response after every accepted action is authoritative. The Android
screen should render backend-authored scores, server/receiver, court side,
games, sets, timeline events, breaks, and completion state.

### 7. Add Offline Scoring Parity

Replicate the current, deliberately narrow iOS guarantee:

- cache one active match only after it has been opened online
- bind the cache to both account and organisation
- allow supported scoring actions to update an optimistic local projection
- persist every queued action and its UUID before showing it as safely queued
- survive process death and device restart
- replay actions in creation order when connectivity returns
- remove an action only after the server accepts it
- preserve actions added while an earlier replay is in progress
- show the underlying API/network failure when synchronisation stops
- rely on backend `match_action_receipts` to make UUID retries idempotent

Use Room transactions for the match snapshot and action queue. WorkManager can
request durable replay, but the repository must also trigger immediate replay
when the foreground app reconnects. Do not expand Android offline scope beyond
iOS during the parity phase.

### 8. Implement Settings And Administration

Add the remaining iOS-backed flows using the same backend permission checks:

- self-profile edit and password-reset request
- subscription page and club enquiries
- two-confirmation personal-account deletion
- membership/association switching
- organisation details
- organisation-user create, edit, role update, and delete
- court create, edit, delete, and display-code access
- enabled racket sports and per-sport timed-break defaults
- feedback, help, privacy, and sign out

Local profile photos should remain explicitly device-local until the product
has shared server-side photo storage.

### 9. Add Google Play Billing As A Separate Backend Workstream

The existing subscription backend verifies Apple-signed StoreKit transactions;
it cannot securely accept Google Play purchases as-is. Android billing parity
therefore needs:

1. Personal Plus products/base plans in Play Console
2. Google Play Billing in the Android client
3. stable, privacy-safe account/profile identifiers attached to purchases
4. authenticated backend endpoints accepting purchase tokens
5. server-side verification through the Google Play Developer API
6. Real-time developer notifications for renewals, cancellation, grace,
   account hold, expiry, refund, and revocation
7. scheduled reconciliation and an append-only entitlement audit
8. purchase acknowledgement only after the backend has safely associated and
   verified the purchase
9. restore and cross-device entitlement tests

Keep `personal_plan` server-authoritative and provider-neutral. Apple and Google
subscription records should feed the same entitlement result without one
provider overwriting a still-valid entitlement from the other. Google's
[backend integration guidance](https://developer.android.com/google/play/billing/backend)
and [subscription lifecycle](https://developer.android.com/google/play/billing/lifecycle/subscriptions)
should be treated as required design references.

### 10. Test, Harden, And Release In Stages

Use three levels of verification:

- unit tests for JSON mapping, ViewModels, entitlement presentation, session
  expiry, and every scoring reducer transition
- repository/integration tests for authentication, tenant switching, Room
  persistence, ordered replay, retry/idempotency, and billing state mapping
- Compose UI tests for the complete journeys already represented by iOS UI
  tests: login, racket scoring/service-side changes, tennis deuce/tiebreak,
  Padel, completion, and logout

Run manual device tests on at least a small phone, a common modern phone, and a
tablet, including dark mode, large font, rotation, process death, Airplane Mode,
poor connectivity, session expiry, and multi-organisation switching.

Release through Play Console internal testing first, then closed testing, then
a staged production rollout. Add crash reporting and privacy-safe operational
telemetry before widening the rollout.

## Backend Decisions Required Before Development Gets Far

### Android Sport Availability

The backend currently exposes `web_app` and `mobile_app` session types, while
platform sport controls are named for web and iOS. Choose one approach before
Android setup is implemented:

- **Recommended for initial parity:** Android uses `mobile_app` and shares the
  existing mobile/iOS sport-availability list. Rename user-facing/admin wording
  to "mobile" when practical.
- **Use only if separate rollout control is required:** add a distinct Android
  sport-access column and contract, then update session payloads, root-admin
  controls, organisation/member overrides, documentation, and tests.

Do not silently send Android as `web_app`; that could expose a different set of
sports and would make mobile session behaviour inconsistent.

### Subscription Ownership Across Stores

Decide how one account behaves when it has Apple and Google subscriptions, or
moves between iPhone and Android. A safe rule is: Personal Plus remains active
while any verified provider entitlement is active, while cancellation and
refund events affect only their own provider record.

### Notifications

Inbox polling and cross-device read state can ship at parity immediately.
Firebase Cloud Messaging should be a later cross-platform notification project
unless push is implemented for iOS at the same time; otherwise Android would
have a capability the iOS parity target does not yet have.

## Suggested Delivery Milestones

1. **Foundation:** project, configuration, API envelope, login, membership
   selection, secure session, navigation.
2. **Read parity:** dashboard, matches, history, analytics, notifications,
   settings reads.
3. **Match parity:** setup, scheduling, squash/racketball scoring, tennis, Padel,
   historic match views.
4. **Offline parity:** one-match cache, reducers, ordered replay, process-death
   recovery, idempotency tests.
5. **Account parity:** settings writes, club administration, help, deletion,
   accessibility and tablet polish.
6. **Commercial parity:** Play Billing plus backend verification, lifecycle,
   audit, restore, and reconciliation.
7. **Release hardening:** end-to-end regression, security/privacy review,
   internal/closed testing, staged rollout.

Each milestone should be releasable to internal testers and should finish with
its parity checklist passing, rather than leaving many partially connected
screens.

## Android V1 Release Gate

Do not call Android equivalent to iOS until all of the following are true:

- the same account sees the same plan, organisations, enabled sports, matches,
  performance data, and notification read state on both platforms
- all four supported sports can be configured, scored, undone, ended, reopened,
  and viewed historically with matching backend state
- an offline match survives process death and replays once, in order, without
  duplicate points
- tenant switching cannot reveal the previous organisation's cached data
- session expiry and replacement cannot leave a usable stale token
- Android purchases are verified server-side and restore correctly on another
  device
- phone/tablet, dark mode, large-text, TalkBack, and poor-network checks pass
- no screen advertises unfinished root-admin, realtime, push, or broader offline
  capabilities

## Documentation To Update During Implementation

When Android work begins, update these alongside each shipped capability:

- this plan and `docs/mobile/README.md`
- `docs/backend-api.md` for any client-type, sport-access, or billing changes
- `docs/technical-walkthrough.md` for lifecycle and replay changes
- `docs/troubleshooting.md` for Android build, session, sync, and billing issues
- `AGENTS.md` so it continues to describe only what is actually implemented
- a new Android build/signing/release guide once the project exists
