#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${ROOT_DIR}/artifacts/fc"
BUILD_DIR="${ARTIFACT_DIR}/build"
ZIP_PATH="${ARTIFACT_DIR}/bianlunmiao-api.zip"
PYTHON_IMAGE="${PYTHON_IMAGE:-python:3.10-slim-bookworm}"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

docker run --rm \
  --platform linux/amd64 \
  -v "${ROOT_DIR}:/src" \
  -v "${BUILD_DIR}:/out" \
  "${PYTHON_IMAGE}" \
  /bin/sh -lc '
    set -e
    apt-get update >/dev/null
    apt-get install -y --no-install-recommends zip >/dev/null
    python -m pip install --upgrade pip >/dev/null
    python -m pip install --no-cache-dir -t /out \
      "fastapi>=0.115.0" \
      "uvicorn[standard]>=0.30.0" \
      "sqlalchemy>=2.0.36" \
      "alembic>=1.14.0" \
      "psycopg2-binary>=2.9.10" \
      "python-jose[cryptography]>=3.3.0" \
      "passlib[bcrypt]>=1.7.4" \
      "pydantic-settings>=2.6.1" \
      "python-multipart>=0.0.20" \
      "httpx>=0.28.1" >/dev/null
    cp -R /src/app /out/app
    cp -R /src/alembic /out/migrations
    sed "s/^script_location = alembic$/script_location = migrations/" /src/alembic.ini >/out/alembic.ini
    cat >/out/bootstrap <<'"'"'BOOTSTRAP'"'"'
#!/bin/sh
set -eu
export PYTHONPATH="/code:${PYTHONPATH:-}"
export PATH="/var/fc/lang/python3.10/bin:/code:${PATH:-}"
cd /code
if [ "${RUN_MIGRATIONS_ON_BOOT:-false}" = "true" ]; then
  python3 -m alembic upgrade head
fi
exec python3 -m uvicorn app.main:app --host 0.0.0.0 --port "${FC_SERVER_PORT:-9000}"
BOOTSTRAP
    chmod +x /out/bootstrap
    cd /out
    zip -qr /out/bianlunmiao-api.zip .
  '

mv "${BUILD_DIR}/bianlunmiao-api.zip" "${ZIP_PATH}"
printf 'FC_ZIP_PATH=%s\n' "${ZIP_PATH}"
