#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCH="${ARCH:-$(uname -m)}"
CONFIG="${CONFIG:-release}"
APP_NAME="Aula F75 Driver"
APP_BUNDLE="${ROOT_DIR}/build/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

"${ROOT_DIR}/scripts/macos/macos-build.sh"

BIN_PATH="${ROOT_DIR}/.build/out/Products/Release/AulaF75Driver"
if [[ ! -x "$BIN_PATH" ]]; then
  BIN_PATH="${ROOT_DIR}/.build/${ARCH}-apple-macosx/${CONFIG}/AulaF75Driver"
fi
if [[ ! -x "$BIN_PATH" ]]; then
  BIN_PATH="${ROOT_DIR}/.build/${CONFIG}/AulaF75Driver"
fi

echo "==> Packaging ${APP_BUNDLE}"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "${MACOS_DIR}/AulaF75Driver"
chmod +x "${MACOS_DIR}/AulaF75Driver"
cp "${ROOT_DIR}/Info.plist" "${CONTENTS_DIR}/Info.plist"

xattr -cr "$APP_BUNDLE" || true
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

echo "==> App bundle ready: ${APP_BUNDLE}"
