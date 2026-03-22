#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="${ROOT_DIR}/bianlunmiao-ios"
FLOW_MODE="${1:-smoke-local}"
IOS_DEVICE_NAME="${IOS_DEVICE_NAME:-iPhone 17 Pro}"
IOS_SIM_OS="${IOS_SIM_OS:-26.3.1}"
IOS_BUNDLE_ID="${IOS_BUNDLE_ID:-com.wenwan.BianLunMiao}"
DERIVED_DATA_PATH="${IOS_MAESTRO_DERIVED_DATA_PATH:-${ROOT_DIR}/artifacts/ios-maestro/DerivedData}"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug-iphonesimulator/BianLunMiao.app"
MAESTRO_SHARDS="${MAESTRO_SHARDS:-1}"

if ! command -v maestro >/dev/null 2>&1; then
  echo "maestro CLI not found. Install: brew install mobile-dev-inc/tap/maestro" >&2
  exit 1
fi

resolve_simulator_udid() {
  local exact
  exact="$(xcrun simctl list devices available iOS | awk -v os="${IOS_SIM_OS}" -v name="${IOS_DEVICE_NAME}" '
    $0 ~ ("-- iOS " os " --") { in_os = 1; next }
    $0 ~ /^--/ { in_os = 0 }
    in_os && index($0, name " (") {
      print
      exit
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
      exit
    }
  ' | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/'
}

boot_and_install() {
  local udid="$1"
  mkdir -p "${DERIVED_DATA_PATH}"
  xcrun simctl boot "${udid}" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "${udid}" -b >/dev/null

  (
    cd "${IOS_DIR}"
    xcodebuild build \
      -project BianLunMiao.xcodeproj \
      -scheme BianLunMiao \
      -destination "platform=iOS Simulator,id=${udid}" \
      -derivedDataPath "${DERIVED_DATA_PATH}" \
      CODE_SIGNING_ALLOWED=NO \
      > "${ROOT_DIR}/artifacts/ios-maestro/build.log" 2>&1
  )

  xcrun simctl install "${udid}" "${APP_PATH}"
}

run_flows() {
  local udid="$1"
  local flows=()

  case "${FLOW_MODE}" in
    smoke-local)
      flows=(
        "${ROOT_DIR}/scripts/ios_maestro_smoke_login.yaml"
        "${ROOT_DIR}/scripts/ios_maestro_smoke_tabs.yaml"
      )
      ;;
    *)
      echo "Unsupported Maestro flow mode: ${FLOW_MODE}" >&2
      exit 1
      ;;
  esac

  if [[ "${MAESTRO_SHARDS}" -gt 1 ]]; then
    maestro --device "${udid}" test --shard-split "${MAESTRO_SHARDS}" "${flows[@]}"
  else
    maestro --device "${udid}" test "${flows[@]}"
  fi
}

main() {
  mkdir -p "${ROOT_DIR}/artifacts/ios-maestro"
  local udid
  udid="$(resolve_simulator_udid)"
  if [[ -z "${udid}" ]]; then
    echo "Unable to find simulator ${IOS_DEVICE_NAME} iOS ${IOS_SIM_OS}" >&2
    exit 1
  fi

  echo "Using simulator: ${udid}"
  boot_and_install "${udid}"
  run_flows "${udid}"
}

main "$@"
