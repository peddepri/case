#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
"${HERE}/toolbox.sh" "cd /workspace/infra/terraform && terraform $*"
