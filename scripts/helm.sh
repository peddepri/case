#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
"${HERE}/toolbox.sh" "helm $*"
