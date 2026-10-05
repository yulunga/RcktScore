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
completion, and signs out. It explicitly leaves the **Timed breaks** setup
option off so the scoring journey does not pause at changeovers or set breaks.

The journey creates a real completed match. If the account already has an
active personal match, the test ends that match early before starting. Use a
dedicated test account whose match history can safely be changed.

The default result bundle is `/tmp/RcktScore-LiveTennisMatch.xcresult`.
Override the Simulator, result path, or visual pacing with
`RCKTSCORE_UI_DESTINATION`, `RCKTSCORE_UI_RESULT_PATH`, and
`RCKTSCORE_UI_STEP_DELAY` respectively.
