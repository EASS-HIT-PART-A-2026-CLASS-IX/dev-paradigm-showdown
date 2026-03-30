#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/_backend_common.sh"

CLOUD_BACKEND_URL="${CLOUD_BACKEND_URL:-}"
FRONTEND_PORT_CANDIDATES=(3000 3001 5173 4173 5500 8080)
BACKEND_PORT_CANDIDATES=(8010 8011 8012 8013 8014 8015)

TMP_DIR="$(mktemp -d)"
BACKEND_PID=""
FRONTEND_PID=""
FRONTEND_PORT=""
BACKEND_PORT=""

cleanup() {
  if [[ -n "$FRONTEND_PID" ]]; then
    kill "$FRONTEND_PID" 2>/dev/null || true
    wait "$FRONTEND_PID" 2>/dev/null || true
  fi

  if [[ -n "$BACKEND_PID" ]]; then
    kill "$BACKEND_PID" 2>/dev/null || true
    wait "$BACKEND_PID" 2>/dev/null || true
  fi

  rm -rf "$TMP_DIR"
}

port_in_use() {
  lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
}

pick_free_port() {
  local port
  for port in "$@"; do
    if ! port_in_use "$port"; then
      printf '%s\n' "$port"
      return 0
    fi
  done

  return 1
}

wait_for_url() {
  local url="$1"
  local attempt

  for attempt in $(seq 1 40); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done

  return 1
}

show_log() {
  local title="$1"
  local path="$2"

  if [[ -f "$path" ]]; then
    echo
    echo "$title"
    sed -n '1,200p' "$path"
  fi
}

stop_frontend() {
  if [[ -n "$FRONTEND_PID" ]]; then
    kill "$FRONTEND_PID" 2>/dev/null || true
    wait "$FRONTEND_PID" 2>/dev/null || true
    FRONTEND_PID=""
  fi
}

start_backend_dev() {
  local log_path="$TMP_DIR/backend-dev.log"

  BACKEND_PORT="$(pick_free_port "${BACKEND_PORT_CANDIDATES[@]}")"
  BACKEND_PORT="$BACKEND_PORT" "$ROOT_DIR/scripts/run_backend_dev.sh" >"$log_path" 2>&1 &
  BACKEND_PID=$!

  if ! wait_for_url "http://127.0.0.1:${BACKEND_PORT}/health"; then
    show_log "Backend dev log:" "$log_path" >&2
    return 1
  fi

  echo "Local backend: http://127.0.0.1:${BACKEND_PORT}"
}

start_frontend_local_mode() {
  local log_path="$TMP_DIR/frontend-local.log"

  FRONTEND_PORT="$(pick_free_port "${FRONTEND_PORT_CANDIDATES[@]}")"
  BACKEND_PORT="$BACKEND_PORT" FRONTEND_PORT="$FRONTEND_PORT" \
    "$ROOT_DIR/scripts/run_frontend.sh" local >"$log_path" 2>&1 &
  FRONTEND_PID=$!

  if ! wait_for_url "http://127.0.0.1:${FRONTEND_PORT}/"; then
    show_log "Frontend local-mode log:" "$log_path" >&2
    return 1
  fi

  echo "Local frontend (local backend mode): http://127.0.0.1:${FRONTEND_PORT}"
}

start_frontend_cloud_mode() {
  local log_path="$TMP_DIR/frontend-cloud.log"

  FRONTEND_PORT="$(pick_free_port "${FRONTEND_PORT_CANDIDATES[@]}")"
  FRONTEND_PORT="$FRONTEND_PORT" API_BASE_URL="$CLOUD_BACKEND_URL" \
    BACKEND_LABEL="FastAPI Cloud backend" \
    "$ROOT_DIR/scripts/run_frontend.sh" cloud >"$log_path" 2>&1 &
  FRONTEND_PID=$!

  if ! wait_for_url "http://127.0.0.1:${FRONTEND_PORT}/"; then
    show_log "Frontend cloud-mode log:" "$log_path" >&2
    return 1
  fi

  echo "Local frontend (cloud backend mode): http://127.0.0.1:${FRONTEND_PORT}"
}

run_smoke() {
  local label="$1"

  echo
  echo "Testing: $label"
  E2E_BASE_URL="http://127.0.0.1:${FRONTEND_PORT}" python3 "$ROOT_DIR/scripts/e2e_smoke.py"
}

check_cloud_consistency() {
  echo
  echo "Probing cloud consistency: ${CLOUD_BACKEND_URL}"
  CLOUD_BACKEND_URL="$CLOUD_BACKEND_URL" python3 - <<'PY'
import json
import os
import sys
import time
import urllib.request

base_url = os.environ["CLOUD_BACKEND_URL"].rstrip("/")
headers = {
    "Accept": "application/json",
    "User-Agent": "Mozilla/5.0 (compatible; DevParadigmShowdownConsistencyProbe/1.0)",
}


def fetch_paradigms():
    request = urllib.request.Request(f"{base_url}/api/paradigms", headers=headers)
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.loads(response.read().decode())


initial = fetch_paradigms()
target = initial[0]
target_id = target["id"]
values = [target["votes"]]

for _ in range(7):
    time.sleep(0.2)
    paradigms = fetch_paradigms()
    current = next(item for item in paradigms if item["id"] == target_id)
    values.append(current["votes"])

print(f"Observed votes for id {target_id}: {values}")

if len(set(values)) != 1:
    sys.stderr.write(
        "Cloud consistency check failed. "
        "The deployed backend is serving different vote counts across repeated reads, "
        "which usually means SQLite is still being used per instance instead of a shared DATABASE_URL.\n"
    )
    raise SystemExit(1)
PY
}

trap cleanup EXIT

ensure_backend_venv

start_backend_dev
start_frontend_local_mode
run_smoke "local frontend -> local FastAPI dev backend"

if [[ -z "$CLOUD_BACKEND_URL" ]]; then
  echo
  echo "Skipping cloud backend checks because CLOUD_BACKEND_URL is not set."
  echo "Set CLOUD_BACKEND_URL=https://your-app.fastapicloud.dev to test your deployed backend."
  echo
  echo "Local backend mode passed."
  exit 0
fi

stop_frontend
start_frontend_cloud_mode
run_smoke "local frontend -> FastAPI Cloud backend"
check_cloud_consistency

echo
echo "Both backend modes passed."
