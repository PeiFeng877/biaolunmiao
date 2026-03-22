#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

command -v node >/dev/null 2>&1 || {
  echo "[emas-openapi] 需要 Node.js 才能运行官方 MPServerless SDK" >&2
  exit 1
}

command -v pnpm >/dev/null 2>&1 || {
  echo "[emas-openapi] 需要 pnpm 才能安装和运行官方 MPServerless SDK" >&2
  exit 1
}

if [[ ! -d "$SKILL_DIR/node_modules/@alicloud/mpserverless20190615" ]]; then
  echo "[emas-openapi] 首次运行，正在安装官方 MPServerless SDK..." >&2
  pnpm --dir "$SKILL_DIR" install --silent
fi

exec node "$SCRIPT_DIR/emas_control_plane.cjs" "$@"
