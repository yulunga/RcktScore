# Mobile Docs

This folder contains current mobile-platform notes for the native iOS app that
ships from the same repository as the web and backend code.

Current documents:

- `setup.md`
- `signing.md`
- `build.md`
- `release-notes.md`
- `ios-v1-plan.md`

## Current iOS State

The native iOS project exists in `mobile/ios/RcktScoreMobile/` and includes a
real app target and scheme.

What the current app does:

- organisation-user login against the shared v2 backend
- persisted session state with `mobile_app` client-type sessions
- active-session conflict handling with force-logout retry
- TestFlight-style device builds have already been used for live app testing
- dashboard tabs for `Home`, `Matches`, `History`, `Settings`, and `Need Help`
- dashboard loading for active, scheduled, and recent matches
- native start-new-match flow with sport picker, player/referee lookups, court
  selection, handicap setup, and scheduled-match fallback when a court is busy
- native sport selection currently exposes the implemented and enabled sports
  only: squash, racketball, and tennis
- native live scoring with warm-up, first-server selection, match timer,
  score/stroke/let actions, undo, early end, serve-side changes, in-match game
  settings, tennis scoring presentation, and court display-code visibility
- native historic-match view with grouped point timeline and match/game timing
- native settings with plan-aware account menus, local profile photo picking,
  subscription/profile/association pages, self-profile editing, password-reset
  access, association switching, an About page for app version/build visibility,
  sign-out access, and club-admin
  organisation/user/court/racket-sport controls
- each native settings menu row now opens its own page with standard back navigation
- native help flows for feedback and password reset
- dashboard offline handling now suppresses the old persistent fetch-error
  banner when the device is offline
- native login now presents an organisation chooser when the same email belongs
  to multiple approved clubs/accounts
- start-new-match now respects dark mode styling and allows personal-tier
  squash/racketball handicap setup
- tennis match setup now supports singles/doubles switching, and the live tennis
  scorer now runs a 5-minute warm-up before opening serve/receive selection

What it does not yet match perfectly:

- final iPhone-first polish of the scoring screen and secondary controls
- native notification-center flows behind the dashboard bell
- full implementation behind the native settings `Game Settings`, `Reporting`,
  `Stats`, and deeper federation-style association pages
- central/shared profile-photo storage across devices and users
- offline history and offline scoring sync
- documented CI/archive/release pipeline
- completed realtime/WebSocket sync
- release-grade automated or manual signoff coverage

Current iOS should be treated as an active client implementation, but not yet as
a fully packaged mobile release program.
