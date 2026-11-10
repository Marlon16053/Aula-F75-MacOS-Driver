#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
"${ROOT_DIR}/scripts/macos/macos-app.sh"

STAGE_DIR="$(mktemp -d /tmp/aula-f75-dmg.XXXXXX)"
DMG_PATH="${ROOT_DIR}/build/Aula-F75-Driver-macOS.dmg"

cp -R "${ROOT_DIR}/build/Aula F75 Driver.app" "${STAGE_DIR}/"
ln -s /Applications "${STAGE_DIR}/Applications"

rm -f "$DMG_PATH"
hdiutil create -volname "Aula F75 Driver" -srcfolder "$STAGE_DIR" -ov -format UDZO "$DMG_PATH"
rm -rf "$STAGE_DIR"

echo "==> DMG ready: ${DMG_PATH}"
