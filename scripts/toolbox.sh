#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
COMPOSE_FILE="${ROOT_DIR}/docker-compose.tools.yml"

# Ensure docker is available
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required. Please install/start Docker Desktop." >&2
  exit 1
fi

# Build tools image if missing
if ! docker image inspect case-tools:latest >/dev/null 2>&1; then
  docker compose -f "$COMPOSE_FILE" build tools
fi

# Run arbitrary command in tools container
if [ "$#" -eq 0 ]; then
  docker compose -f "$COMPOSE_FILE" run --rm tools bash
else
  docker compose -f "$COMPOSE_FILE" run --rm tools "$@"
fi
