#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_STABILITY_RUNS="${IOS_STABILITY_RUNS:-3}"

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
RESULT_ROOT="${ROOT_DIR}/artifacts/ios-stability/${TIMESTAMP}"

assert_prerequisites() {
  if [[ ! -x "${ROOT_DIR}/scripts/ios_ui_lane.sh" ]]; then
    echo "ios_ui_lane.sh not found or not executable" >&2
    exit 1
  fi
}

run_single_iteration() {
  local run_id="$1"
  local lane_root="${RESULT_ROOT}/run-${run_id}"

  echo "==> run ${run_id}/${IOS_STABILITY_RUNS}"
  IOS_UI_RESULT_ROOT="${lane_root}" \
    IOS_UI_TIMESTAMP="stability" \
    "${ROOT_DIR}/scripts/ios_ui_lane.sh" full-local || {
    echo "run ${run_id} failed"
    return 1
  }

  echo "run ${run_id} passed"
}

main() {
  assert_prerequisites
  mkdir -p "${RESULT_ROOT}"
  echo "Root: ${ROOT_DIR}"
  echo "Result root: ${RESULT_ROOT}"

  local run
  for run in $(seq 1 "$IOS_STABILITY_RUNS"); do
    run_single_iteration "$run"
  done

  echo "All ${IOS_STABILITY_RUNS} full-local stability runs passed."
  find "$RESULT_ROOT" -name '*.xcresult' | sort
}

main "$@"
