#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/../../.." && pwd)"
credentials_file="${RCKTSCORE_UI_CREDENTIALS_FILE:-$project_root/testing/automated/mobile/ui-test-credentials.env}"
result_path="${RCKTSCORE_UI_RESULT_PATH:-/tmp/RcktScore-LiveRacketMatch.xcresult}"
destination="${RCKTSCORE_UI_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro,OS=latest}"

if [[ -f "$credentials_file" ]]; then
    set -a
    source "$credentials_file"
    set +a
fi

username="${HITNSCORE_UI_TEST_PERSONAL_PLUS_USERNAME:-${TEST_RUNNER_HITNSCORE_UI_TEST_PERSONAL_PLUS_USERNAME:-}}"
password="${HITNSCORE_UI_TEST_PERSONAL_PLUS_PASSWORD:-${TEST_RUNNER_HITNSCORE_UI_TEST_PERSONAL_PLUS_PASSWORD:-}}"

if [[ -z "$username" || -z "$password" ]]; then
    echo "Missing Personal Plus UI-test credentials." >&2
    echo "Populate $credentials_file or export the two HITNSCORE_UI_TEST_PERSONAL_PLUS variables." >&2
    exit 2
fi

if [[ -e "$result_path" ]]; then
    echo "Result bundle already exists: $result_path" >&2
    echo "Choose a new RCKTSCORE_UI_RESULT_PATH or remove the old temporary result bundle." >&2
    exit 2
fi

export TEST_RUNNER_HITNSCORE_UI_TEST_PERSONAL_PLUS_USERNAME="$username"
export TEST_RUNNER_HITNSCORE_UI_TEST_PERSONAL_PLUS_PASSWORD="$password"
export TEST_RUNNER_HITNSCORE_UI_TEST_STEP_DELAY="${RCKTSCORE_UI_STEP_DELAY:-0.8}"

echo "LIVE TEST: this creates and completes Paul v Mark in the Personal Plus test account."
echo "Keep Simulator visible to watch the journey. Screenshots and logs will be saved to $result_path."

set +e
xcodebuild test \
    -project "$project_root/mobile/ios/RcktScoreMobile/RcktScoreMobile.xcodeproj" \
    -scheme RcktScoreMobile \
    -destination "$destination" \
    -parallel-testing-enabled NO \
    -only-testing:RcktScoreMobileUITests/LiveRacketMatchJourneyUITests/testPersonalPlusCreatesScoresCompletesAndLogsOut \
    -resultBundlePath "$result_path" \
    2>&1 | sed -E '/"?(TEST_RUNNER_)?HITNSCORE_UI_TEST_[A-Z_]*(USERNAME|PASSWORD)"? =/d'
test_status="${PIPESTATUS[0]}"
set -e

if [[ "$test_status" -ne 0 ]]; then
    echo "Live UI test failed. Inspect the redacted console output and $result_path." >&2
    exit "$test_status"
fi

echo "Saved Xcode result bundle: $result_path"
