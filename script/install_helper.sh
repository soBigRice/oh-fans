#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT_DIR/script/build_helper.sh"

HELPER_BIN="$ROOT_DIR/build/helper/com.sobigrice.iFans.helper"
HELPER_PLIST="$ROOT_DIR/build/helper/com.sobigrice.iFans.helper.plist"

sudo install -d -o root -g wheel /Library/PrivilegedHelperTools
sudo install -d -o root -g wheel /Library/LaunchDaemons
sudo install -o root -g wheel -m 755 "$HELPER_BIN" /Library/PrivilegedHelperTools/com.sobigrice.iFans.helper
sudo install -o root -g wheel -m 644 "$HELPER_PLIST" /Library/LaunchDaemons/com.sobigrice.iFans.helper.plist
sudo launchctl bootout system/com.sobigrice.iFans.helper >/dev/null 2>&1 || true
sudo launchctl bootstrap system /Library/LaunchDaemons/com.sobigrice.iFans.helper.plist
sudo launchctl kickstart -k system/com.sobigrice.iFans.helper

echo "oh fans privileged helper installed."
echo "Validate with: ./build/helper/helper_smoke_test handshake"
