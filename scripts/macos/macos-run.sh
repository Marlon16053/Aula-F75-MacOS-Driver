#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
"${ROOT_DIR}/scripts/macos/macos-app.sh"

APP_BUNDLE="${ROOT_DIR}/build/Aula F75 Driver.app"
echo "==> Launching ${APP_BUNDLE}"
open "$APP_BUNDLE"
