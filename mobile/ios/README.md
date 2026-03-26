# iOS Workspace

This directory is the home for the native iOS app.

Recommended next build steps for the iOS developer:

1. Create the Xcode app target and workspace in this directory
2. Point the app at the existing deployed API base URL per environment
3. Use the API and match lifecycle documentation from:
   - `docs/backend-api.md`
   - `docs/technical-walkthrough.md`
4. Build the first mobile flow around organisation user login, dashboard, and
   live match scoring

Suggested native structure:

- `RcktScoreMobile.xcworkspace/`
- `RcktScoreMobile.xcodeproj/`
- `RcktScoreMobile/`
- `RcktScoreMobileTests/`
- `RcktScoreMobileUITests/`

This repo currently provides the folder scaffold and mobile documentation so a
native developer can start cleanly in the same repository.

