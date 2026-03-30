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
  LOCAL_API_BASE_URL=...   # optional local target override
  REMOTE_API_BASE_URL=...  # optional remote target override
  LOCAL_BACKEND_LABEL=...
  REMOTE_BACKEND_LABEL=...
  DEFAULT_BACKEND_KEY=local|remote
  BACKEND_PORT=8000        # used by local mode only
EOF
}

resolve_local_api_base_url() {
  printf '%s' "${LOCAL_API_BASE_URL:-$DEFAULT_LOCAL_BACKEND_URL}"
}

resolve_remote_api_base_url() {
  case "$MODE" in
    local)
      printf '%s' "${REMOTE_API_BASE_URL:-$DEFAULT_CLOUD_BACKEND_URL}"
      ;;
    cloud)
      printf '%s' "${REMOTE_API_BASE_URL:-${API_BASE_URL:-$DEFAULT_CLOUD_BACKEND_URL}}"
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

resolve_local_backend_label() {
  printf '%s' "${LOCAL_BACKEND_LABEL:-Local FastAPI dev backend}"
}

resolve_remote_backend_label() {
  if [[ -n "${REMOTE_BACKEND_LABEL:-}" ]]; then
    printf '%s' "$REMOTE_BACKEND_LABEL"
    return
  fi

  if [[ -n "${BACKEND_LABEL:-}" && "$MODE" != "local" ]]; then
    printf '%s' "$BACKEND_LABEL"
    return
  fi

  case "$MODE" in
    http://*|https://*)
      printf '%s' "Custom backend"
      ;;
    *)
      printf '%s' "FastAPI Cloud backend"
      ;;
  esac
}

resolve_default_backend_key() {
  if [[ -n "${DEFAULT_BACKEND_KEY:-}" ]]; then
    case "$DEFAULT_BACKEND_KEY" in
      local|remote)
        printf '%s' "$DEFAULT_BACKEND_KEY"
        ;;
      *)
        printf '%s' "local"
        ;;
    esac
    return
  fi

  case "$MODE" in
    local)
      printf '%s' "local"
      ;;
    *)
      printf '%s' "remote"
      ;;
  esac
}

js_escape() {
  printf '%s' "$1" | sed "s/\\\\/\\\\\\\\/g; s/'/\\\\'/g"
}

LOCAL_API_BASE_URL="$(resolve_local_api_base_url)"
REMOTE_API_BASE_URL="$(resolve_remote_api_base_url)"
LOCAL_BACKEND_LABEL="$(resolve_local_backend_label)"
REMOTE_BACKEND_LABEL="$(resolve_remote_backend_label)"
DEFAULT_BACKEND_KEY="$(resolve_default_backend_key)"
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
  apiBaseUrl: '$(js_escape "$(
    if [[ "$DEFAULT_BACKEND_KEY" == "remote" ]]; then
      printf '%s' "$REMOTE_API_BASE_URL"
    else
      printf '%s' "$LOCAL_API_BASE_URL"
    fi
  )")',
  backendLabel: '$(js_escape "$(
    if [[ "$DEFAULT_BACKEND_KEY" == "remote" ]]; then
      printf '%s' "$REMOTE_BACKEND_LABEL"
    else
      printf '%s' "$LOCAL_BACKEND_LABEL"
    fi
  )")',
  defaultBackendKey: '$(js_escape "$DEFAULT_BACKEND_KEY")',
  backendTargets: [
    {
      key: 'local',
      label: '$(js_escape "$LOCAL_BACKEND_LABEL")',
      apiBaseUrl: '$(js_escape "$LOCAL_API_BASE_URL")',
    },
    {
      key: 'remote',
      label: '$(js_escape "$REMOTE_BACKEND_LABEL")',
      apiBaseUrl: '$(js_escape "$REMOTE_API_BASE_URL")',
    },
  ],
});
EOF

echo "Frontend URL: http://127.0.0.1:${FRONTEND_PORT}"
echo "Default backend: ${DEFAULT_BACKEND_KEY}"
echo "Local backend URL: ${LOCAL_API_BASE_URL:-/api}"
echo "Remote backend URL: ${REMOTE_API_BASE_URL}"

cd "$TMP_DIR"
exec python3 -m http.server "$FRONTEND_PORT" --bind 127.0.0.1
