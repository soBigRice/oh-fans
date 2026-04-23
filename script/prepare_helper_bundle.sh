#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${1:?missing helper bundle output directory}"
HELPER_DIR="$OUTPUT_DIR/helper"
HELPER_BIN="$HELPER_DIR/com.sobigrice.iFans.helper"
HELPER_PLIST="$HELPER_DIR/com.sobigrice.iFans.helper.plist"

COMMON_SOURCES=(
  "$ROOT_DIR/iFans/Hardware/PrivilegedHelperBridge.swift"
  "$ROOT_DIR/iFans/Hardware/SMCBridge.swift"
  "$ROOT_DIR/iFans/Models/FanControlModels.swift"
  "$ROOT_DIR/iFans/Hardware/SMCBridgeBackend.c"
)

mkdir -p "$HELPER_DIR"

install -m 755 "$ROOT_DIR/script/install_helper_bundle.sh" "$OUTPUT_DIR/install_helper.sh"

xcrun swiftc \
  -swift-version 5 \
  -framework Foundation \
  -framework IOKit \
  -import-objc-header "$ROOT_DIR/iFans/Hardware/SMCBridgeBackend.h" \
  "$ROOT_DIR/helper/PrivilegedHelperMain.swift" \
  "${COMMON_SOURCES[@]}" \
  -o "$HELPER_BIN"

cat > "$HELPER_PLIST" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.sobigrice.iFans.helper</string>
  <key>MachServices</key>
  <dict>
    <key>com.sobigrice.iFans.helper</key>
    <true/>
  </dict>
  <key>ProgramArguments</key>
  <array>
    <string>/Library/PrivilegedHelperTools/com.sobigrice.iFans.helper</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
PLIST
