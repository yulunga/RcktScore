#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
output_path="${TMPDIR:-/tmp}/rcktscore-tennis-scenarios"
module_cache="${TMPDIR:-/tmp}/rcktscore-swift-module-cache"

xcrun swiftc \
  "$repo_root/mobile/ios/RcktScoreMobile/RcktScoreMobile/Models/MatchSummary.swift" \
  "$repo_root/mobile/ios/RcktScoreMobile/RcktScoreMobile/State/TennisScoringReducer.swift" \
  "$repo_root/testing/automated/mobile/TennisScoringReducerScenarioTests.swift" \
  -module-cache-path "$module_cache" \
  -o "$output_path"

"$output_path"
