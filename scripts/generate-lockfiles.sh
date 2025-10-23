#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

run_in_node() {
  "$ROOT_DIR/scripts/node.sh" "$@"
}

echo "[locks] Gerando package-lock.json (backend)"
run_in_node "cd /workspace/app/backend && npm install --package-lock-only"

echo "[locks] Gerando package-lock.json (frontend)"
run_in_node "cd /workspace/app/frontend && npm install --package-lock-only"

if [ -d "$ROOT_DIR/app/mobile" ]; then
  echo "[locks] Gerando package-lock.json (mobile)"
  run_in_node "cd /workspace/app/mobile && npm install --package-lock-only"
fi

echo "[locks] Concluído. Agora você pode commitar os lockfiles."
