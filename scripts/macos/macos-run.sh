#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
make macos-install

echo "==> Launching /Applications/Aula F75 Driver.app"
open "/Applications/Aula F75 Driver.app"
