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
