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
and verifies that the rail contains `L2` followed by `R3`. At the initial 2-2
state it also verifies that the bottom-dock **Action** control keeps its own
`scoring.actionButton` identity, is hittable and opens the Match Actions sheet.

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

This test creates a real completed match in the dedicated Personal Plus test
account. If an earlier test run left that personal account with an active
match, the journey resumes it, selects **End Match Early**, waits for the
completed state and returns to the dashboard before creating the fresh Paul
versus Mark match. Two additional recovery screenshots are retained when this
path is needed. Do not point these Personal Plus test variables at an account
whose matches need to be preserved.

### Run and watch the live journey in Xcode

1. Rotate any credential that has appeared in a console or result-bundle log,
   then update the ignored local test plan as described above.
2. Use a dedicated Personal Plus test account. An active personal match left by
   a failed run will be ended automatically before the new journey starts.
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

## Live tennis match journey

`LiveTennisMatchJourneyUITests` is the tennis-specific Personal Plus journey.
It signs in, creates Paul versus Mark as singles Best of 3, selects Paul to
serve and Mark to receive, explicitly disables **Timed breaks**, and exercises
these singles scoring paths:

- a love service game;
- a deuce game with advantage returning to deuce;
- a first set that reaches 6-6;
- a tiebreak that reaches 6-6 before Paul wins it 8-6; and
- a 6-0 second set that completes the match 2-0.

It then creates a Best of 3 doubles match for Paul/Peter versus Mark/Matt,
enables **Golden Point** and **Timed breaks**, explicitly chooses the opening
server and receiver, verifies tennis Golden Point uses the normal 40-40 side
without an additional receiver choice, wins the deciding point, verifies and
skips the changeover and set-break overlays, completes the match 6-0, 6-0, and
logs out. Eleven retained screenshots record the major checkpoints. Like the
squash journey, this test uses the real backend, creates two real completed
matches, ends an existing active personal match during recovery, and must only
use a dedicated disposable test account.

Run it from the repository root after configuring the ignored credentials
file:

```bash
RCKTSCORE_UI_RESULT_PATH=/tmp/RcktScore-LiveTennisMatch-$(date +%Y%m%d-%H%M%S).xcresult \
  testing/automated/mobile/run-live-tennis-match-ui-test.sh
```

In Xcode, run the test diamond beside
`testPersonalPlusCompletesSinglesAndDoublesJourneys` in
`Tests/Scoring/LiveTennisMatchJourneyUITests.swift`. The command-line default
pause is 0.2 seconds per completed game or screenshot checkpoint; set
`RCKTSCORE_UI_STEP_DELAY` to make the visible journey slower.

## Live padel match journey

`LivePadelMatchJourneyUITests` is the padel-specific Personal Plus journey.
Padel must be enabled for the test account. It signs in and creates two
four-player Best of 3 matches with timed breaks explicitly disabled. The first
uses standard advantage scoring, exercises deuce and advantage, and finishes
6-0, 6-0. The second enables Golden Point, reaches 40-40, verifies the receiver
player choice, selects the receiving team's second player, and also finishes
6-0, 6-0 before the test signs out.

Ten retained screenshots record the major checkpoints. This test uses the real
backend, creates two real completed matches, ends an existing active personal
match during recovery, and must only use a dedicated disposable test account.

Run it from the repository root after configuring the ignored credentials
file:

```bash
RCKTSCORE_UI_RESULT_PATH=/tmp/RcktScore-LivePadelMatch-$(date +%Y%m%d-%H%M%S).xcresult \
  testing/automated/mobile/run-live-padel-match-ui-test.sh
```

In Xcode, run the test diamond beside
`testPersonalPlusCompletesStandardAndGoldenPointBestOfThreeJourneys` in
`Tests/Scoring/LivePadelMatchJourneyUITests.swift`.
