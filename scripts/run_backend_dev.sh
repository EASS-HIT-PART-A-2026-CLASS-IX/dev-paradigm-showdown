#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_backend_common.sh"

ensure_backend_venv

BACKEND_PORT="${BACKEND_PORT:-8000}"
export CORS_ALLOW_ORIGINS="${CORS_ALLOW_ORIGINS:-$DEFAULT_CORS_ALLOW_ORIGINS}"

echo "Backend URL: http://127.0.0.1:${BACKEND_PORT}"
echo "CORS origins: ${CORS_ALLOW_ORIGINS}"

cd "$BACKEND_DIR"
exec "$FASTAPI_BIN" dev --host 127.0.0.1 --port "$BACKEND_PORT"
