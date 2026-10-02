#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/../../.." && pwd)"
result_path="${RCKTSCORE_UI_RESULT_PATH:-/tmp/RcktScore-RacketServiceSide.xcresult}"
destination="${RCKTSCORE_UI_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro,OS=latest}"

if [[ -e "$result_path" ]]; then
    echo "Result bundle already exists: $result_path" >&2
    echo "Choose a new RCKTSCORE_UI_RESULT_PATH or remove the old temporary result bundle." >&2
    exit 2
fi

xcodebuild test \
    -project "$project_root/mobile/ios/RcktScoreMobile/RcktScoreMobile.xcodeproj" \
    -scheme RcktScoreMobile \
    -destination "$destination" \
    -only-testing:RcktScoreMobileUITests/RacketServiceSideTimelineUITests/testManualLeftServeReplacesR2AndPersistsWhenServerScores \
    -resultBundlePath "$result_path"

echo "Saved Xcode result bundle: $result_path"
