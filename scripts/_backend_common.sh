#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
BACKEND_VENV="$BACKEND_DIR/.venv"
FASTAPI_BIN="$BACKEND_VENV/bin/fastapi"
DEFAULT_FASTAPI_CLOUD_APP_ID="121bd167-fec8-4436-a565-4b8d677dd9e3"
DEFAULT_CORS_ALLOW_ORIGINS="http://127.0.0.1:3000,http://localhost:3000,http://127.0.0.1:3001,http://localhost:3001,http://127.0.0.1:5173,http://localhost:5173,http://127.0.0.1:4173,http://localhost:4173,http://127.0.0.1:5500,http://localhost:5500,http://127.0.0.1:8080,http://localhost:8080"

ensure_backend_venv() {
  (
    cd "$BACKEND_DIR"
    if [[ ! -x "$FASTAPI_BIN" ]]; then
      uv venv .venv --python 3.12
    fi
    uv pip install --python .venv/bin/python -r requirements.txt
  )
}
