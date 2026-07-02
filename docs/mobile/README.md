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
  subscription/profile/association pages, password-reset access, and club-admin
  organisation/user/court/racket-sport controls
- native help flows for feedback and password reset
- dashboard offline handling now suppresses the old persistent fetch-error
  banner when the device is offline

What it does not yet match perfectly:

- multi-organisation membership selection when `/login` returns
  `organizationSelection`
- final iPhone-first polish of the scoring screen and secondary controls
- native notification-center flows behind the dashboard bell
- full implementation behind the native settings `Association`, `Game Settings`,
  `Reporting`, and `Stats` placeholder pages
- offline history and offline scoring sync
- documented CI/archive/release pipeline
- completed realtime/WebSocket sync
- release-grade automated or manual signoff coverage

Current iOS should be treated as an active client implementation, but not yet as
a fully packaged mobile release program.
