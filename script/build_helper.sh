#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/helper"
OUTPUT="$BUILD_DIR/com.sobigrice.iFans.helper"
SMOKE_OUTPUT="$BUILD_DIR/helper_smoke_test"

COMMON_SOURCES=(
  "$ROOT_DIR/iFans/Hardware/PrivilegedHelperBridge.swift"
  "$ROOT_DIR/iFans/Hardware/SMCBridge.swift"
  "$ROOT_DIR/iFans/Models/FanControlModels.swift"
  "$ROOT_DIR/iFans/Hardware/SMCBridgeBackend.c"
)

mkdir -p "$BUILD_DIR"
rm -f "$OUTPUT" "$SMOKE_OUTPUT"

xcrun swiftc \
  -swift-version 5 \
  -target arm64-apple-macos26.4 \
  -framework Foundation \
  -framework IOKit \
  -import-objc-header "$ROOT_DIR/iFans/Hardware/SMCBridgeBackend.h" \
  "$ROOT_DIR/helper/PrivilegedHelperMain.swift" \
  "${COMMON_SOURCES[@]}" \
  -o "$OUTPUT"

xcrun swiftc \
  -swift-version 5 \
  -target arm64-apple-macos26.4 \
  -framework Foundation \
  -framework IOKit \
  -import-objc-header "$ROOT_DIR/iFans/Hardware/SMCBridgeBackend.h" \
  "$ROOT_DIR/script/helper_smoke_test.swift" \
  "$ROOT_DIR/iFans/Hardware/AppleSiliconHardwareProvider.swift" \
  "$ROOT_DIR/iFans/Hardware/HardwareProvider.swift" \
  "${COMMON_SOURCES[@]}" \
  -o "$SMOKE_OUTPUT"

PLIST_PATH="$BUILD_DIR/com.sobigrice.iFans.helper.plist"
cat > "$PLIST_PATH" <<'PLIST'
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

echo "helper binary: $OUTPUT"
echo "smoke binary: $SMOKE_OUTPUT"
echo "launchd plist: $PLIST_PATH"
