#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="${ROOT_DIR}/bianlunmiao-ios"

IOS_DEVICE_NAME="${IOS_DEVICE_NAME:-iPhone 17 Pro}"
IOS_SIM_OS="${IOS_SIM_OS:-26.2}"
IOS_STABILITY_RUNS="${IOS_STABILITY_RUNS:-3}"
DESTINATION="platform=iOS Simulator,name=${IOS_DEVICE_NAME},OS=${IOS_SIM_OS}"

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
RESULT_ROOT="${ROOT_DIR}/artifacts/ios-stability/${TIMESTAMP}"
DERIVED_DATA_PATH="${RESULT_ROOT}/DerivedData"

resolve_udid() {
  xcrun simctl list devices available iOS | awk -v os="$IOS_SIM_OS" -v name="$IOS_DEVICE_NAME" '
    $0 ~ ("-- iOS " os " --") { in_os = 1; next }
    $0 ~ /^--/ { in_os = 0 }
    in_os && index($0, name " (") {
      print
      exit
    }
  ' | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/'
}

assert_prerequisites() {
  if [[ ! -d "$IOS_DIR" ]]; then
    echo "iOS directory not found: $IOS_DIR" >&2
    exit 1
  fi
}

prepare_build_artifacts() {
  mkdir -p "$RESULT_ROOT"
  echo "==> build-for-testing"
  (
    cd "$IOS_DIR"
    xcodebuild build-for-testing \
      -project BianLunMiao.xcodeproj \
      -scheme BianLunMiao \
      -destination "$DESTINATION" \
      -parallel-testing-enabled NO \
      -maximum-parallel-testing-workers 1 \
      -derivedDataPath "$DERIVED_DATA_PATH" \
      CODE_SIGNING_ALLOWED=NO \
      > "${RESULT_ROOT}/build-for-testing.log" 2>&1
  )
}

run_single_iteration() {
  local run_id="$1"
  local udid="$2"
  local result_bundle="${RESULT_ROOT}/run-${run_id}.xcresult"
  local log_file="${RESULT_ROOT}/run-${run_id}.log"

  echo "==> run ${run_id}/${IOS_STABILITY_RUNS}"
  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  xcrun simctl erase "$udid" >/dev/null 2>&1 || true
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b >/dev/null

  (
    cd "$IOS_DIR"
    xcodebuild test-without-building \
      -project BianLunMiao.xcodeproj \
      -scheme BianLunMiao \
      -destination "$DESTINATION" \
      -parallel-testing-enabled NO \
      -maximum-parallel-testing-workers 1 \
      -derivedDataPath "$DERIVED_DATA_PATH" \
      -skip-testing:BianLunMiaoUITests/BianLunMiaoUITests/testLaunchPerformance \
      -skip-testing:BianLunMiaoUITests/BianLunMiaoUITestsLaunchTests \
      -resultBundlePath "$result_bundle" \
      CODE_SIGNING_ALLOWED=NO \
      > "$log_file" 2>&1
  ) || {
    echo "run ${run_id} failed, showing tail log:"
    tail -n 120 "$log_file" || true
    return 1
  }

  echo "run ${run_id} passed"
}

main() {
  assert_prerequisites
  local udid
  udid="$(resolve_udid)"
  if [[ -z "$udid" ]]; then
    echo "Unable to locate simulator UDID for ${IOS_DEVICE_NAME} iOS ${IOS_SIM_OS}" >&2
    exit 1
  fi

  echo "Root: $ROOT_DIR"
  echo "iOS: $IOS_DIR"
  echo "Destination: $DESTINATION"
  echo "Simulator UDID: $udid"
  echo "Result root: $RESULT_ROOT"

  prepare_build_artifacts

  local run
  for run in $(seq 1 "$IOS_STABILITY_RUNS"); do
    run_single_iteration "$run" "$udid"
  done

  echo "All ${IOS_STABILITY_RUNS} full-regression runs passed."
  echo "xcresult bundles:"
  find "$RESULT_ROOT" -name '*.xcresult' -maxdepth 1 | sort
}

main "$@"
