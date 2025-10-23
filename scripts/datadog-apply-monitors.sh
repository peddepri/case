#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
DD_SITE=${DD_SITE:-datadoghq.com}
API_URL="https://api.${DD_SITE}"

if [ -z "${DD_API_KEY:-}" ] || [ -z "${DD_APP_KEY:-}" ]; then
  echo "DD_API_KEY e DD_APP_KEY são obrigatórios" >&2
  exit 1
fi

MON_FILE="${ROOT_DIR}/observabilidade/datadog/monitors/monitors.json"

if [ ! -f "$MON_FILE" ]; then
  echo "Arquivo de monitores não encontrado: $MON_FILE" >&2
  exit 1
fi

echo "[datadog] criando monitores a partir de $MON_FILE"
curl -sS -X POST "${API_URL}/api/v1/monitor/batch" \
  -H "DD-API-KEY: ${DD_API_KEY}" \
  -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
  -H 'Content-Type: application/json' \
  --data-binary @"${MON_FILE}" | jq '.' || true
