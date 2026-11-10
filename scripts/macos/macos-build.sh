#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCH="${ARCH:-$(uname -m)}"
CONFIG="${CONFIG:-release}"

choose_macos_sdk() {
  local probe_file
  probe_file="$(mktemp /tmp/aula-swiftui-probe.XXXXXX.swift)"
  cat > "$probe_file" <<'SWIFT'
import SwiftUI
struct ProbeView: View {
  @State private var flag = false
  var body: some View { EmptyView() }
}
SWIFT

  local candidates=()
  if [[ -n "${SDKROOT:-}" && -d "${SDKROOT}" ]]; then
    candidates+=("${SDKROOT}")
  fi
  for sdk in /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk; do
    [[ -d "$sdk" ]] && candidates+=("$sdk")
  done

  for sdk in "${candidates[@]}"; do
    if xcrun swiftc -typecheck "$probe_file" -target "${ARCH}-apple-macosx14.0" -sdk "$sdk" >/dev/null 2>&1; then
      rm -f "$probe_file"
      echo "$sdk"
      return 0
    fi
  done

  rm -f "$probe_file"
  xcrun --sdk macosx --show-sdk-path
}

SDK_PATH="$(choose_macos_sdk)"
echo "==> Building AulaF75Driver ($CONFIG, $ARCH) with SDK: $(basename "$SDK_PATH")"

cd "$ROOT_DIR"
swift build --sdk "$SDK_PATH" -c "$CONFIG" --arch "$ARCH"
BIN_DIR="$(swift build --sdk "$SDK_PATH" -c "$CONFIG" --arch "$ARCH" --show-bin-path)"
echo "==> Build complete: ${BIN_DIR}/AulaF75Driver"
