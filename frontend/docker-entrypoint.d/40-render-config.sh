#!/bin/sh
set -eu

: "${FRONTEND_API_BASE_URL:=}"
: "${FRONTEND_BACKEND_LABEL:=Local Docker backend}"

envsubst '${FRONTEND_API_BASE_URL} ${FRONTEND_BACKEND_LABEL}' \
  < /usr/share/nginx/html/config.template.js \
  > /usr/share/nginx/html/config.js
