#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND_DIR="$ROOT_DIR/frontend"
MODE="${1:-local}"
FRONTEND_PORT="${FRONTEND_PORT:-3000}"
DEFAULT_LOCAL_BACKEND_URL="http://127.0.0.1:${BACKEND_PORT:-8000}"
DEFAULT_CLOUD_BACKEND_URL="https://yalla-balagan.fastapicloud.dev"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run_frontend.sh local
  ./scripts/run_frontend.sh cloud
  ./scripts/run_frontend.sh https://custom-api.example.com

Environment:
  FRONTEND_PORT=3000
  API_BASE_URL=...         # optional override
  BACKEND_LABEL=...        # optional UI label override
  BACKEND_PORT=8000        # used by local mode only
EOF
}

resolve_api_base_url() {
  case "$MODE" in
    local)
      printf '%s' "${API_BASE_URL:-$DEFAULT_LOCAL_BACKEND_URL}"
      ;;
    cloud)
      printf '%s' "${API_BASE_URL:-$DEFAULT_CLOUD_BACKEND_URL}"
      ;;
    http://*|https://*)
      printf '%s' "$MODE"
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
}

resolve_backend_label() {
  if [[ -n "${BACKEND_LABEL:-}" ]]; then
    printf '%s' "$BACKEND_LABEL"
    return
  fi

  case "$MODE" in
    local)
      printf '%s' "Local FastAPI dev backend"
      ;;
    cloud)
      printf '%s' "FastAPI Cloud backend"
      ;;
    *)
      printf '%s' "Custom backend"
      ;;
  esac
}

js_escape() {
  printf '%s' "$1" | sed "s/\\\\/\\\\\\\\/g; s/'/\\\\'/g"
}

API_BASE_URL="$(resolve_api_base_url)"
BACKEND_LABEL="$(resolve_backend_label)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

cp "$FRONTEND_DIR/index.html" "$TMP_DIR/index.html"
cp "$FRONTEND_DIR/app.js" "$TMP_DIR/app.js"
cp "$FRONTEND_DIR/styles.css" "$TMP_DIR/styles.css"

cat > "$TMP_DIR/config.js" <<EOF
window.APP_CONFIG = Object.freeze({
  apiBaseUrl: '$(js_escape "$API_BASE_URL")',
  backendLabel: '$(js_escape "$BACKEND_LABEL")',
});
EOF

echo "Frontend URL: http://127.0.0.1:${FRONTEND_PORT}"
echo "API base URL: ${API_BASE_URL}"

cd "$TMP_DIR"
exec python3 -m http.server "$FRONTEND_PORT" --bind 127.0.0.1
