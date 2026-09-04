# iOS Workspace

This directory is the home for the active native iOS app.

Current workspace:

- `RcktScoreMobile.xcodeproj`
- `RcktScoreMobile/`
- scheme: `RcktScoreMobile`

Current app coverage:

- organisation-user login and persisted session
- multi-organisation membership selection and association switching
- optional Face ID / Touch ID unlock for an unexpired saved local session
- dashboard, matches, history, settings, and help tabs
- native match setup and scheduled-match start
- squash, racketball, and tennis live scoring plus historic-match views
- one-match offline scoring cache with ordered reconnect synchronisation and duplicate-action protection
- club organisation/user/court management
- racket-sport visibility controls
- lightweight UI smoke-test target in `RcktScoreMobileUITests/`

Useful app entry points:

- `RcktScoreMobile/ContentView.swift`
- `RcktScoreMobile/State/AppContainer.swift`
- `RcktScoreMobile/State/OfflineMatchStore.swift`
- `RcktScoreMobile/Services/APIClient.swift`
- `RcktScoreMobile/Views/LoginView.swift`
- `RcktScoreMobile/Views/DashboardView.swift`
- `RcktScoreMobile/Views/StartNewMatchView.swift`
- `RcktScoreMobile/Views/MatchScoringView.swift`
- `RcktScoreMobile/Views/HistoricMatchView.swift`

Supporting repo docs:

- `docs/mobile/README.md`
- `docs/mobile/ios-v1-plan.md`
- `docs/backend-api.md`
- `docs/technical-walkthrough.md`
- `docs/troubleshooting.md`

Current priority:

- finish iPhone/iPad UX hardening, regression signoff, and release-pipeline
  documentation without changing the shared backend scoring contracts
