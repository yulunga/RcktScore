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
`RcktScoreMobile Local Tests`, and make sure **Shared** is unchecked. Then open
**Product > Scheme > Edit Scheme**, select **Test > Arguments**, and add the six
values under **Environment Variables**. Local schemes live under `xcuserdata`,
which this repository ignores. Never place passwords in the shared scheme.

For CI runs, inject the same variables from the CI secret store before running
`xcodebuild test`.

The test fails with a list of missing variable names when its credentials have
not been configured.
