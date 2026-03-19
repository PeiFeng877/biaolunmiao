#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="${ROOT_DIR}/bianlunmiao-ios"

LANE="${1:-smoke-local}"
IOS_SCHEME="${IOS_UI_SCHEME:-BianLunMiao-UITestsOnly}"
IOS_DEVICE_NAME="${IOS_DEVICE_NAME:-iPhone 17 Pro}"
IOS_SIM_OS="${IOS_SIM_OS:-26.3.1}"
IOS_SMOKE_SHARDS="${IOS_UI_SMOKE_PARALLEL_SHARDS:-2}"
IOS_UI_DESTINATION="${IOS_UI_DESTINATION:-}"
TIMESTAMP="${IOS_UI_TIMESTAMP:-$(date '+%Y%m%d-%H%M%S')}"
RESULT_ROOT="${IOS_UI_RESULT_ROOT:-${ROOT_DIR}/artifacts/ios-ui-lanes/${LANE}/${TIMESTAMP}}"
DERIVED_DATA_PATH="${IOS_UI_DERIVED_DATA_PATH:-${RESULT_ROOT}/DerivedData}"

build_destination=""
declare -a default_destinations=()
code_signing_args=("CODE_SIGNING_ALLOWED=NO")

ensure_prerequisites() {
  if [[ ! -d "${IOS_DIR}" ]]; then
    echo "iOS directory not found: ${IOS_DIR}" >&2
    exit 1
  fi
  mkdir -p "${RESULT_ROOT}"
}

list_simulator_udids() {
  local exact
  exact="$(xcrun simctl list devices available iOS | awk -v os="${IOS_SIM_OS}" -v name="${IOS_DEVICE_NAME}" '
    $0 ~ ("-- iOS " os " --") { in_os = 1; next }
    $0 ~ /^--/ { in_os = 0 }
    in_os && index($0, name " (") {
      if ($0 !~ /unavailable/) {
        print
      }
    }
  ' | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')"

  if [[ -n "${exact}" ]]; then
    printf '%s\n' "${exact}"
    return
  fi

  xcrun simctl list devices available iOS | awk '
    /^-- iOS / { in_ios = 1; next }
    /^--/ { in_ios = 0 }
    in_ios && /iPhone/ && $0 !~ /unavailable/ {
      print
    }
  ' | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/'
}

prepare_simulator_destinations() {
  local requested="$1"
  default_destinations=()
  while IFS= read -r udid; do
    [[ -n "${udid}" ]] || continue
    default_destinations+=("${udid}")
    if [[ "${#default_destinations[@]}" -ge "${requested}" ]]; then
      break
    fi
  done < <(list_simulator_udids)
  if [[ "${#default_destinations[@]}" -eq 0 ]]; then
    echo "No available simulator found for ${IOS_DEVICE_NAME} iOS ${IOS_SIM_OS}" >&2
    exit 1
  fi
  build_destination="platform=iOS Simulator,id=${default_destinations[0]}"
}

prepare_device_destination() {
  if [[ -z "${IOS_UI_DESTINATION}" ]]; then
    echo "device-special lane requires IOS_UI_DESTINATION" >&2
    exit 1
  fi
  build_destination="${IOS_UI_DESTINATION}"
  default_destinations=("${IOS_UI_DESTINATION}")
  code_signing_args=()
}

boot_destination_if_needed() {
  local destination="$1"
  if [[ "${destination}" != platform=iOS\ Simulator,* ]]; then
    return
  fi

  local udid="${destination##*=}"
  xcrun simctl boot "${udid}" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "${udid}" -b >/dev/null
}

normalize_destination() {
  local destination="$1"
  if [[ "${destination}" == *=* ]]; then
    printf '%s\n' "${destination}"
    return
  fi
  printf 'platform=iOS Simulator,id=%s\n' "${destination}"
}

build_for_testing() {
  echo "==> build-for-testing (${LANE})"
  boot_destination_if_needed "${build_destination}"
  (
    cd "${IOS_DIR}"
    xcodebuild build-for-testing \
      -project BianLunMiao.xcodeproj \
      -scheme "${IOS_SCHEME}" \
      -destination "${build_destination}" \
      -parallel-testing-enabled NO \
      -maximum-parallel-testing-workers 1 \
      -derivedDataPath "${DERIVED_DATA_PATH}" \
      "${code_signing_args[@]}" \
      > "${RESULT_ROOT}/build-for-testing.log" 2>&1
  )
}

run_tests() {
  local destination="$1"
  local result_bundle="$2"
  local log_file="$3"
  shift 3
  local tests=("$@")
  local only_testing_args=()
  local test_id

  for test_id in "${tests[@]}"; do
    only_testing_args+=("-only-testing:${test_id}")
  done

  boot_destination_if_needed "${destination}"
  (
    cd "${IOS_DIR}"
    env BLM_UI_TEST_EXECUTION_LANE="${LANE}" \
      xcodebuild test-without-building \
        -project BianLunMiao.xcodeproj \
        -scheme "${IOS_SCHEME}" \
        -destination "${destination}" \
        -parallel-testing-enabled NO \
        -maximum-parallel-testing-workers 1 \
        -derivedDataPath "${DERIVED_DATA_PATH}" \
        -resultBundlePath "${result_bundle}" \
        "${only_testing_args[@]}" \
        "${code_signing_args[@]}" \
        > "${log_file}" 2>&1
  )
}

run_serial_lane() {
  local lane_name="$1"
  shift
  local tests=("$@")
  local result_bundle="${RESULT_ROOT}/${lane_name}.xcresult"
  local log_file="${RESULT_ROOT}/${lane_name}.log"
  local destination

  destination="$(normalize_destination "${default_destinations[0]}")"

  echo "==> lane ${lane_name}"
  run_tests "${destination}" "${result_bundle}" "${log_file}" "${tests[@]}" || {
    echo "lane ${lane_name} failed, log tail:" >&2
    tail -n 120 "${log_file}" || true
    return 1
  }
}

run_smoke_local_sharded() {
  local tests=(
    "BianLunMiaoUITests/BianLunMiaoSmokeLocalUITests/testSmokeLaunchesMockDataHome"
    "BianLunMiaoUITests/BianLunMiaoSmokeLocalUITests/testSmokeSignedOutShowsLoginGate"
    "BianLunMiaoUITests/BianLunMiaoSmokeLocalUITests/testSmokeMockDataCanReachMainTabs"
  )

  local shard_count="${IOS_SMOKE_SHARDS}"
  if [[ "${#default_destinations[@]}" -lt 2 || "${shard_count}" -lt 2 ]]; then
    run_serial_lane "smoke-local" "${tests[@]}"
    return
  fi

  local shard1=("${tests[0]}" "${tests[1]}")
  local shard2=("${tests[2]}")
  local result1="${RESULT_ROOT}/smoke-local-shard-1.xcresult"
  local result2="${RESULT_ROOT}/smoke-local-shard-2.xcresult"
  local log1="${RESULT_ROOT}/smoke-local-shard-1.log"
  local log2="${RESULT_ROOT}/smoke-local-shard-2.log"

  echo "==> lane smoke-local (2 shards)"
  run_tests "platform=iOS Simulator,id=${default_destinations[0]}" "${result1}" "${log1}" "${shard1[@]}" &
  local pid1=$!
  run_tests "platform=iOS Simulator,id=${default_destinations[1]}" "${result2}" "${log2}" "${shard2[@]}" &
  local pid2=$!

  local failed=0
  wait "${pid1}" || failed=1
  wait "${pid2}" || failed=1
  if [[ "${failed}" -ne 0 ]]; then
    echo "smoke-local shard failed" >&2
    tail -n 120 "${log1}" || true
    tail -n 120 "${log2}" || true
    return 1
  fi
}

main() {
  ensure_prerequisites

  case "${LANE}" in
    smoke-local|full-local|local-remote|stg-smoke|specialized)
      prepare_simulator_destinations 2
      ;;
    device-special)
      prepare_device_destination
      ;;
    *)
      echo "Unsupported lane: ${LANE}" >&2
      exit 1
      ;;
  esac

  echo "Root: ${ROOT_DIR}"
  echo "iOS: ${IOS_DIR}"
  echo "Lane: ${LANE}"
  echo "Scheme: ${IOS_SCHEME}"
  echo "Result root: ${RESULT_ROOT}"
  echo "DerivedData: ${DERIVED_DATA_PATH}"

  build_for_testing

  case "${LANE}" in
    smoke-local)
      run_smoke_local_sharded
      ;;
    full-local)
      run_serial_lane "full-local" \
        "BianLunMiaoUITests/BianLunMiaoSmokeLocalUITests" \
        "BianLunMiaoUITests/BianLunMiaoFunctionalUITests"
      ;;
    local-remote)
      run_serial_lane "local-remote" "BianLunMiaoUITests/BianLunMiaoLocalRemoteUITests"
      ;;
    stg-smoke)
      run_serial_lane "stg-smoke" "BianLunMiaoUITests/BianLunMiaoSTGSmokeUITests"
      ;;
    device-special)
      run_serial_lane "device-special" "BianLunMiaoUITests/BianLunMiaoDeviceSpecialUITests"
      ;;
    specialized)
      run_serial_lane "specialized" \
        "BianLunMiaoUITests/BianLunMiaoSpecializedUITests" \
        "BianLunMiaoUITests/BianLunMiaoUITestsLaunchTests"
      ;;
  esac

  echo "Lane ${LANE} passed."
}

main "$@"
