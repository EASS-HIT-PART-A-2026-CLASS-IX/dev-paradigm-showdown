#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_backend_common.sh"

APP_ID="${FASTAPI_CLOUD_APP_ID:-}"

if [[ $# -gt 0 ]]; then
  APP_ID="$1"
  shift
fi

ensure_backend_venv

if [[ -z "${FASTAPI_CLOUD_TOKEN:-}" ]]; then
  WHOAMI_OUTPUT="$("$FASTAPI_BIN" cloud whoami 2>&1 || true)"
  if [[ "$WHOAMI_OUTPUT" == *"No credentials found"* ]]; then
    "$FASTAPI_BIN" login
  fi
fi

cd "$BACKEND_DIR"

if [[ -n "$APP_ID" ]]; then
  exec "$FASTAPI_BIN" deploy --app-id "$APP_ID" "$@"
fi

exec "$FASTAPI_BIN" deploy "$@"
