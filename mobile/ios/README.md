# iOS Workspace

This directory is the home for the active native iOS app.

Current workspace:

- `RcktScoreMobile.xcodeproj`
- `RcktScoreMobile/`
- scheme: `RcktScoreMobile`

Current app coverage:

- organisation-user login and persisted session
- dashboard, matches, history, settings, and help tabs
- native match setup and scheduled-match start
- live scoring and historic-match views
- club organisation/user/court management

Useful app entry points:

- `RcktScoreMobile/ContentView.swift`
- `RcktScoreMobile/State/AppContainer.swift`
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

- redesign the iPhone scoring experience without changing the shared backend
  scoring contracts
