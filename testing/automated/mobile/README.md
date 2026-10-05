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
**Timed breaks** enabled. The doubles journey exercises a deciding Golden
Point with a receiver-court choice, verifies and skips changeover and set-break
overlays, completes the match 6-0, 6-0, and signs out.

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
- the second enables Golden Point, reaches 40-40, selects the receiver's Deuce
  court, wins the deciding point, and completes 6-0, 6-0.

The journey creates two real completed matches and then signs out. If the
account already has an active personal match, the test ends it early before
starting. Use a dedicated test account whose match history can safely change.

The default result bundle is `/tmp/RcktScore-LivePadelMatch.xcresult`. Override
the Simulator, result path, credentials file, or visual pacing with the same
`RCKTSCORE_UI_*` variables used by the tennis journey.
