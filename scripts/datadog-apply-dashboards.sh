#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
DD_SITE=${DD_SITE:-datadoghq.com}
API_URL="https://api.${DD_SITE}"

if [ -z "${DD_API_KEY:-}" ] || [ -z "${DD_APP_KEY:-}" ]; then
  echo "DD_API_KEY e DD_APP_KEY são obrigatórios" >&2
  exit 1
fi

create_dashboard() {
  local file=$1
  echo "[datadog] criando dashboard a partir de $file"
  curl -sS -X POST "${API_URL}/api/v1/dashboard" \
    -H "DD-API-KEY: ${DD_API_KEY}" \
    -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
    -H 'Content-Type: application/json' \
    --data-binary @"${file}" | jq '.id, .title' || true
}

for f in $(ls -1 "${ROOT_DIR}/observabilidade/datadog/dashboards"/*.json); do
  create_dashboard "$f"
  sleep 1
done
