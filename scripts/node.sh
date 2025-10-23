#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
COMPOSE_FILE="${ROOT_DIR}/docker-compose.tools.yml"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker é necessário. Inicie o Docker Desktop." >&2
  exit 1
fi

# Build node service image if needed (pull happens automatically on run)
exec docker compose -f "$COMPOSE_FILE" run --rm node "$@"
