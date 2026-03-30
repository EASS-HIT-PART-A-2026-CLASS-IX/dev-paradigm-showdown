#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_backend_common.sh"

APP_ID="${FASTAPI_CLOUD_APP_ID:-$DEFAULT_FASTAPI_CLOUD_APP_ID}"

if [[ $# -gt 0 ]]; then
  APP_ID="$1"
  shift
fi

ensure_backend_venv

WHOAMI_OUTPUT="$("$FASTAPI_BIN" cloud whoami 2>&1 || true)"
if [[ "$WHOAMI_OUTPUT" == *"No credentials found"* ]]; then
  "$FASTAPI_BIN" login
fi

cd "$BACKEND_DIR"
exec "$FASTAPI_BIN" deploy --app-id "$APP_ID" "$@"
