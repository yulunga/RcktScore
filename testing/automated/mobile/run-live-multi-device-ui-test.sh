#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/../../.." && pwd)"
journey="${1:-tennis}"
credentials_file="${RCKTSCORE_UI_CREDENTIALS_FILE:-$project_root/testing/automated/mobile/ui-test-credentials.env}"
run_stamp="$(date +%Y%m%d-%H%M%S)"
result_root="${RCKTSCORE_UI_MULTI_RESULT_DIR:-/tmp/RcktScore-${journey}-MultiDevice-$run_stamp}"
continue_on_failure="${RCKTSCORE_UI_CONTINUE_ON_FAILURE:-0}"

case "$journey" in
    tennis)
        only_testing="RcktScoreMobileUITests/LiveTennisMatchJourneyUITests/testPersonalPlusCompletesSinglesAndDoublesJourneys"
        default_step_delay="0.2"
        ;;
    padel)
        only_testing="RcktScoreMobileUITests/LivePadelMatchJourneyUITests/testPersonalPlusCompletesStandardAndGoldenPointBestOfThreeJourneys"
        default_step_delay="0.2"
        ;;
    racket)
        only_testing="RcktScoreMobileUITests/LiveRacketMatchJourneyUITests/testPersonalPlusCreatesScoresCompletesAndLogsOut"
        default_step_delay="0.8"
        ;;
    *)
        echo "Usage: $0 [tennis|padel|racket]" >&2
        exit 2
        ;;
esac

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

if [[ -e "$result_root" ]]; then
    echo "Multi-device result directory already exists: $result_root" >&2
    echo "Choose a new RCKTSCORE_UI_MULTI_RESULT_DIR." >&2
    exit 2
fi

export TEST_RUNNER_HITNSCORE_UI_TEST_PERSONAL_PLUS_USERNAME="$username"
export TEST_RUNNER_HITNSCORE_UI_TEST_PERSONAL_PLUS_PASSWORD="$password"
export TEST_RUNNER_HITNSCORE_UI_TEST_STEP_DELAY="${RCKTSCORE_UI_STEP_DELAY:-$default_step_delay}"

# Entries are device name|runtime version|result label. Override with a
# semicolon-separated RCKTSCORE_UI_DEVICE_MATRIX using the same format.
device_matrix=(
    "iPhone 16e|18.6|iphone-16e-ios18-6"
    "iPhone 17 Pro|26.5|iphone-17-pro-ios26-5"
    "iPad Pro 11-inch (M5)|26.2|ipad-pro-11-ios26-2"
)

if [[ -n "${RCKTSCORE_UI_DEVICE_MATRIX:-}" ]]; then
    IFS=';' read -r -a device_matrix <<< "$RCKTSCORE_UI_DEVICE_MATRIX"
fi

mkdir -p "$result_root"
failed_devices=()
previous_udid=""

echo "LIVE MULTI-DEVICE TEST: $journey"
echo "Runs sequentially because every journey changes the same Personal Plus test account."
echo "Simulator will stay visible; each device gets its own Xcode result bundle in $result_root."

for entry in "${device_matrix[@]}"; do
    IFS='|' read -r device_name os_version result_label <<< "$entry"

    if [[ -z "$device_name" || -z "$os_version" || -z "$result_label" ]]; then
        echo "Invalid device matrix entry: $entry" >&2
        exit 2
    fi

    udid="$(xcrun simctl list devices available -j | /usr/bin/ruby -rjson -e '
        devices = JSON.parse(STDIN.read).fetch("devices")
        runtime_suffix = "iOS-#{ARGV[1].tr(".", "-")}"
        runtime = devices.keys.find { |key| key.end_with?(runtime_suffix) }
        device = runtime && devices.fetch(runtime).find do |candidate|
          candidate["name"] == ARGV[0] && candidate.fetch("isAvailable", true)
        end
        print(device["udid"]) if device
    ' "$device_name" "$os_version")"

    if [[ -z "$udid" ]]; then
        echo "Simulator is not installed: $device_name with iOS $os_version" >&2
        exit 2
    fi

    if [[ -n "$previous_udid" ]]; then
        xcrun simctl shutdown "$previous_udid" >/dev/null 2>&1 || true
    fi

    xcrun simctl boot "$udid" >/dev/null 2>&1 || true
    open -a Simulator
    xcrun simctl bootstatus "$udid" -b

    result_path="$result_root/$result_label.xcresult"
    log_path="$result_root/$result_label.log"

    echo
    echo "============================================================"
    echo "Running $journey on $device_name — iOS $os_version"
    echo "Watch the visible Simulator window."
    echo "Result: $result_path"
    echo "============================================================"

    set +e
    xcodebuild test \
        -project "$project_root/mobile/ios/RcktScoreMobile/RcktScoreMobile.xcodeproj" \
        -scheme RcktScoreMobile \
        -destination "platform=iOS Simulator,id=$udid" \
        -parallel-testing-enabled NO \
        -only-testing:"$only_testing" \
        -resultBundlePath "$result_path" \
        2>&1 \
        | sed -E '/"?(TEST_RUNNER_)?HITNSCORE_UI_TEST_[A-Z_]*(USERNAME|PASSWORD)"? =/d' \
        | tee "$log_path"
    test_status="${PIPESTATUS[0]}"
    set -e

    if [[ "$test_status" -ne 0 ]]; then
        failed_devices+=("$device_name (iOS $os_version)")
        echo "FAILED: $device_name on iOS $os_version" >&2
        echo "Inspect $result_path and $log_path." >&2
        if [[ "$continue_on_failure" != "1" ]]; then
            exit "$test_status"
        fi
    else
        echo "PASSED: $device_name on iOS $os_version"
    fi

    previous_udid="$udid"
done

echo
echo "Multi-device results: $result_root"
echo "The final Simulator remains booted for inspection."

if [[ "${#failed_devices[@]}" -gt 0 ]]; then
    echo "Failed destinations:" >&2
    for failed_device in "${failed_devices[@]}"; do
        echo "  - $failed_device" >&2
    done
    exit 1
fi

echo "All destinations passed."
