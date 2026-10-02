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

## Configure credentials in Xcode

For runs started inside Xcode, keep credentials in an unshared local scheme and
test plan. Do not add them to the shared `RcktScoreMobile` scheme.

### Create the local scheme and test plan

1. Open `mobile/ios/RcktScoreMobile/RcktScoreMobile.xcodeproj` in Xcode.
2. Choose **Product > Scheme > Manage Schemes**.
3. Select `RcktScoreMobile`, click **Duplicate Scheme**, and name the copy
   `RcktScoreMobile Local Tests`. The existing local scheme may instead appear
   as `Local Test RcktScoreMobile`; either name is suitable.
4. Make sure **Shared** is unchecked for the local scheme, select it from the
   scheme picker in Xcode's top toolbar, and close the schemes window.
5. Choose **Product > Test Plan > New Test Plan**. If a local test plan already
   exists, choose **Product > Test Plan** and select it instead.
6. Save a new plan with a name ending in `.local.xctestplan`, for example
   `RcktScoreMobile Local Tests.local.xctestplan`. This suffix is ignored by
   this repository.
7. Open **Product > Scheme > Edit Scheme**, select **Test**, and confirm the
   local test plan is selected and marked as the default plan.

### Add the environment variables

1. Choose **Product > Test Plan > Edit Test Plan**.
2. Select the **Configurations** tab, then select **Test Scheme Action** in the
   left-hand column.
3. Expand **Arguments** and click the **Environment Variables** row.
4. In the environment-variable table that appears, click the small **+**
   directly below that table. Do not use the **+** in the Project Navigator,
   Supported Destinations, or test-target list.
5. Add the six variable names listed at the top of this document without a
   `TEST_RUNNER_` prefix. Put the current rotated credential in the **Value**
   column and ensure the checkbox beside every row is enabled.
6. The live Paul-versus-Mark journey only consumes the two `PERSONAL_PLUS`
   variables, but retaining all six lets the other login tests use the same
   local plan.

If the variable table is not visible, hide Xcode's debug area with
**View > Debug Area > Hide Debug Area** (`Shift-Command-Y`) and enlarge the test
plan editor. Selecting the **Environment Variables** row again should reveal
the table and its own **+** button.

Never place passwords in the shared scheme or a committed test plan. Do not
share an `.xcresult` until it has been checked for launch diagnostics that may
contain environment values.

For command-line and CI runs, Xcode forwards variables into the test runner
using the `TEST_RUNNER_` prefix used by the example environment file. The test
loader accepts both the Test Plan names and their prefixed command-line form.

The test fails with a list of missing variable names when its credentials have
not been configured.

## Saved racket service-side regression

`RacketServiceSideTimelineUITests` is a deterministic, credential-free
Simulator test for the squash/racketball point-rail regression reported during
release testing. It opens the real scoring screen with a local fixture at
`R2`, changes the serving side to Left and verifies that the same marker becomes
`L2` rather than creating a duplicate. It then awards the server another point
and verifies that the rail contains `L2` followed by `R3`.

Run it from the repository root with:

```bash
testing/automated/mobile/run-racket-service-side-ui-test.sh
```

The runner uses the latest installed iOS runtime for the iPhone 17 Pro by
default and saves the full Xcode result bundle, including three permanent
screenshots, to `/tmp/RcktScore-RacketServiceSide.xcresult`. Set
`RCKTSCORE_UI_RESULT_PATH` to a new path for each retained run, or
`RCKTSCORE_UI_DESTINATION` to another installed Simulator destination.

The scenario forces the app offline and uses local fixture data. It does not
need the six login variables, call the live API, or modify production data. In
Xcode it appears under
`RcktScoreMobileUITests/Tests/Scoring/RacketServiceSideTimelineUITests` and can
be rerun with the test diamond beside the method.

## Watchable live match journey

`LiveRacketMatchJourneyUITests` uses the Personal Plus test account and the
real backend. It signs in, creates a Squash match for Paul versus Mark as Best
of 1 / PAR-11, skips warm-up, chooses Paul as first server, exercises service
transfers, verifies the `R2` to `L2` replacement, records a let, verifies
`L2`/`R3`, undoes and replays the point, completes the match 11-2, returns to
the dashboard and signs out. Twelve retained screenshots document the journey.

This test creates a real completed match in the test account. It deliberately
fails before creation if the Personal Plus account already has an active match,
so it never ends unrelated work automatically.

### Run and watch the live journey in Xcode

1. Rotate any credential that has appeared in a console or result-bundle log,
   then update the ignored local test plan as described above.
2. Make sure the Personal Plus test account has no active match. The test stops
   before creating anything if it detects one.
3. Select the local test scheme in Xcode's top toolbar.
4. Select an installed iPhone Simulator, such as **iPhone 17 Pro**, from the
   destination picker. Do not select a connected physical iPhone.
5. Open the Simulator with **Xcode > Open Developer Tool > Simulator** and keep
   it visible beside Xcode.
6. In the test plan's **Tests** tab, select `RcktScoreMobileUITests` and disable
   **Execute in Parallel** or **Parallelizable** if that option is displayed.
   This prevents Xcode from putting the visual run in a background clone.
7. In the Project Navigator open
   `RcktScoreMobileUITests/Tests/Scoring/LiveRacketMatchJourneyUITests.swift`.
8. Click the diamond in the editor gutter beside
   `testPersonalPlusCreatesScoresCompletesAndLogsOut`. This runs only the live
   journey; **Product > Test** may run the entire test plan.
9. Watch the Simulator. The test logs in, creates Paul versus Mark, performs
   the scoring checks, finishes 11-2, returns to the dashboard, and logs out.

To slow the visual run, add `HITNSCORE_UI_TEST_STEP_DELAY` to the same local
test plan and set its value to a number of seconds from `0` to `5`; `2` is a
comfortable demonstration speed. The default is `0.8` seconds.

After the run, open Xcode's **Report Navigator** (`Command-9`), select the most
recent test report, expand `LiveRacketMatchJourneyUITests`, and select the test
method. Its activity log and twelve screenshot attachments provide the saved
evidence. A green diamond/tick means the complete journey passed; a red failure
shows the exact step and retains the screenshots captured before that point.

The first successful sign-in on a fresh Simulator may display Apple's
**Save Password** prompt over the dashboard. The test automatically selects
**Not Now** before it opens **Start New Match**. If an older build of the test
stops with `dashboard.startNewMatchButton` reported as not hittable, select
**Not Now** manually, rebuild the UI-test target, and rerun the method. Do not
select **Save Password** for shared test-account credentials.

If Xcode still launches a background Simulator clone, use the command-line
runner below. It explicitly disables parallel testing while using the selected
Simulator destination.

For the command line, populate the ignored
`testing/automated/mobile/ui-test-credentials.env`, keep Simulator visible, and
run:

```bash
RCKTSCORE_UI_RESULT_PATH=/tmp/RcktScore-LiveRacketMatch-$(date +%Y%m%d-%H%M%S).xcresult \
  testing/automated/mobile/run-live-racket-match-ui-test.sh
```

The default pause is 0.8 seconds between visible checkpoints and scoring
actions. Set `RCKTSCORE_UI_STEP_DELAY=2` for a slower demonstration. Parallel
testing is disabled so Xcode uses the selected visible Simulator rather than a
background clone. The runner filters credential-variable lines from Xcode's
console diagnostics, but credentials must still be rotated immediately if they
are ever printed or included in a shared result bundle.
