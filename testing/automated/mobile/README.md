# Native tennis scenario tests

Run from the repository root:

```bash
testing/automated/mobile/run-tennis-scenarios.sh
```

The script compiles the production `MatchState` model and
`TennisScoringReducer` with a small native scenario runner. It covers standard
deuce, No-Ad receiver choice, 6-6 and extended tiebreaks, the final-set
10-point match tiebreak, match completion, singles/doubles service rotation,
undo snapshots, and ordered offline replay without requiring a simulator.

# Live tennis UI journey

Run the tennis-specific end-to-end journey from the repository root:

```bash
testing/automated/mobile/run-live-tennis-match-ui-test.sh
```

This opt-in test uses the Personal Plus credentials from the ignored
`testing/automated/mobile/ui-test-credentials.env` file. It signs in to the
real app and backend, creates a singles Best of 3 tennis match, tests a deuce
game, reaches 6-6 in the first set, proves the tiebreak requires a two-point
margin by completing it 8-6, wins the second set 6-0, verifies match
completion, then creates a Best of 3 doubles match with **Golden Point** and
**Timed breaks** enabled. Tennis Golden Point automatically uses the normal
40-40 side without a receiver-choice prompt. The doubles journey wins that
deciding point, verifies and skips changeover and set-break overlays, completes
the match 6-0, 6-0, and signs out.

The journey creates two real completed matches. If the account already has an
active personal match, the test ends that match early before starting. Use a
dedicated test account whose match history can safely be changed.

The default result bundle is `/tmp/RcktScore-LiveTennisMatch.xcresult`.
Override the Simulator, result path, or visual pacing with
`RCKTSCORE_UI_DESTINATION`, `RCKTSCORE_UI_RESULT_PATH`, and
`RCKTSCORE_UI_STEP_DELAY` respectively.

# Live padel UI journey

Run the padel-specific end-to-end journey from the repository root:

```bash
testing/automated/mobile/run-live-padel-match-ui-test.sh
```

This opt-in test uses the same ignored Personal Plus credentials file as the
other live journeys. Padel must be enabled for that account. It signs in and
creates two four-player Best of 3 padel matches with timed breaks explicitly
disabled:

- the first uses standard advantage scoring and exercises a deuce game before
  completing 6-0, 6-0;
- the second enables Golden Point, reaches 40-40, verifies both receiving-team
  players are offered, selects the second receiver, wins the deciding point,
  and completes 6-0, 6-0.

The journey creates two real completed matches and then signs out. If the
account already has an active personal match, the test ends it early before
starting. Use a dedicated test account whose match history can safely change.

The default result bundle is `/tmp/RcktScore-LivePadelMatch.xcresult`. Override
the Simulator, result path, credentials file, or visual pacing with the same
`RCKTSCORE_UI_*` variables used by the tennis journey.

# Visible multi-device UI journey

Run one live journey sequentially across a small iPhone, a current-size iPhone,
and an iPad:

```bash
testing/automated/mobile/run-live-multi-device-ui-test.sh tennis
testing/automated/mobile/run-live-multi-device-ui-test.sh padel
testing/automated/mobile/run-live-multi-device-ui-test.sh racket
```

The default matrix is:

- iPhone 16e, iOS 18.6;
- iPhone 17 Pro, iOS 26.5; and
- iPad Pro 11-inch (M5), iOS 26.2.

The installed iOS 17.0 simulators are intentionally excluded because the
app's deployment target is iOS 17.6.

The runner is intentionally sequential because the live journeys all mutate
the same Personal Plus test account. It boots each exact Simulator, opens the
Simulator app so the journey can be watched, disables parallel testing, and
saves separate `.xcresult` and console-log files for every destination. The
last Simulator remains booted after the run.

Override the matrix with semicolon-separated `device|OS|label` entries:

```bash
RCKTSCORE_UI_DEVICE_MATRIX='iPhone 17 Pro|26.5|iphone-17-pro;iPad mini (A17 Pro)|26.2|ipad-mini' \
  testing/automated/mobile/run-live-multi-device-ui-test.sh padel
```

Set `RCKTSCORE_UI_CONTINUE_ON_FAILURE=1` to continue to later destinations
after a failure. Result bundles open directly in Xcode. Xcode's normal test
diamond still runs only the currently selected destination; use this runner
when one command should cover the whole visible device matrix.
