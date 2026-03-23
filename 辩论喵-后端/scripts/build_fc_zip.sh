#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${ROOT_DIR}/artifacts/fc"
BUILD_DIR="${ARTIFACT_DIR}/build"
ZIP_PATH="${ARTIFACT_DIR}/bianlunmiao-api.zip"
PYTHON_IMAGE="${PYTHON_IMAGE:-python:3.10-slim-buster}"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

docker run --rm \
  --platform linux/amd64 \
  -v "${ROOT_DIR}:/src" \
  "${PYTHON_IMAGE}" \
  /bin/sh -lc '
    set -e
    rm -rf /tmp/build
    mkdir -p /tmp/build
    python -m pip install --upgrade pip >/dev/null
    python -m pip install --no-cache-dir -t /tmp/build \
      "fastapi>=0.115.0" \
      "uvicorn[standard]>=0.30.0" \
      "sqlalchemy>=2.0.36" \
      "alembic>=1.14.0" \
      "psycopg2-binary>=2.9.10" \
      "alibabacloud_dypnsapi20170525>=2.0.0" \
      "alibabacloud_tea_openapi>=0.3.13" \
      "cryptography==43.0.3" \
      "python-jose[cryptography]>=3.3.0" \
      "passlib[bcrypt]>=1.7.4" \
      "pydantic-settings>=2.6.1" \
      "python-multipart>=0.0.20" \
      "httpx>=0.28.1" >/dev/null
    cp -R /src/app /tmp/build/app
    cp -R /src/alembic /tmp/build/migrations
    sed "s/^script_location = alembic$/script_location = migrations/" /src/alembic.ini >/tmp/build/alembic.ini
    cat >/tmp/build/bootstrap <<'"'"'BOOTSTRAP'"'"'
#!/bin/sh
set -eu
export PYTHONPATH="/code:${PYTHONPATH:-}"
export PATH="/var/fc/lang/python3.10/bin:/code:${PATH:-}"
cd /code
if [ "${RUN_MIGRATIONS_ON_BOOT:-false}" = "true" ]; then
  python3 -m alembic upgrade head
fi
if [ "${RUN_ADMIN_BOOTSTRAP:-false}" = "true" ]; then
  python3 -m app.ops.reset_admin
fi
exec python3 -m uvicorn app.main:app --host 0.0.0.0 --port "${FC_SERVER_PORT:-9000}"
BOOTSTRAP
    chmod +x /tmp/build/bootstrap
    cd /tmp/build
    mkdir -p /src/artifacts/fc/build
    python -m zipfile -c /src/artifacts/fc/build/bianlunmiao-api.zip .
  '

mv "${BUILD_DIR}/bianlunmiao-api.zip" "${ZIP_PATH}"
printf 'FC_ZIP_PATH=%s\n' "${ZIP_PATH}"
