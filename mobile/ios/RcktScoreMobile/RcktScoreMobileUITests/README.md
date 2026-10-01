# Native UI-test credentials

The login smoke tests read their accounts from environment variables so real
usernames and passwords are never committed to Git.

Required variables:

- `HITNSCORE_UI_TEST_CLUB_ESSENTIALS_USERNAME`
- `HITNSCORE_UI_TEST_CLUB_ESSENTIALS_PASSWORD`
- `HITNSCORE_UI_TEST_PERSONAL_USERNAME`
- `HITNSCORE_UI_TEST_PERSONAL_PASSWORD`
- `HITNSCORE_UI_TEST_PERSONAL_PLUS_USERNAME`
- `HITNSCORE_UI_TEST_PERSONAL_PLUS_PASSWORD`

For command-line runs, copy
`testing/automated/mobile/ui-test-credentials.env.example` to
`testing/automated/mobile/ui-test-credentials.env`, fill in the rotated values,
then load them before running the test:

```bash
source testing/automated/mobile/ui-test-credentials.env
xcodebuild test -project mobile/ios/RcktScoreMobile/RcktScoreMobile.xcodeproj \
  -scheme RcktScoreMobile -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

The real credentials file is ignored by Git.

For runs started inside Xcode, first use **Product > Scheme > Manage Schemes**
to duplicate `RcktScoreMobile`, rename the duplicate to
`RcktScoreMobile Local Tests`, and make sure **Shared** is unchecked.

With that local scheme selected:

1. Choose **Product > Scheme > Edit Test Plan**.
2. When Xcode asks where to save it, use a name ending in
   `.local.xctestplan`, such as `RcktScoreMobile Local Tests.local.xctestplan`.
   This repository ignores that suffix.
3. Open the test plan's **Configurations** tab.
4. Under **Environment Variables**, add the six unprefixed variable names
   listed above and their rotated values.
5. Confirm `RcktScoreMobileUITests` is included in the test plan, then run
   **Product > Test**.

Never place passwords in the shared scheme or a committed test plan.

For command-line and CI runs, Xcode forwards variables into the test runner
using the `TEST_RUNNER_` prefix used by the example environment file. The test
loader accepts both the Test Plan names and their prefixed command-line form.

The test fails with a list of missing variable names when its credentials have
not been configured.
