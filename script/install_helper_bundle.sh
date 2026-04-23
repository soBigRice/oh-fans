#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD_DIR="$SCRIPT_DIR/helper"

HELPER_BIN="$PAYLOAD_DIR/com.sobigrice.iFans.helper"
HELPER_PLIST="$PAYLOAD_DIR/com.sobigrice.iFans.helper.plist"

if [[ ! -x "$HELPER_BIN" ]]; then
  echo "Bundled oh fans helper binary is missing: $HELPER_BIN" >&2
  exit 1
fi

if [[ ! -f "$HELPER_PLIST" ]]; then
  echo "Bundled oh fans helper launchd plist is missing: $HELPER_PLIST" >&2
  exit 1
fi

sudo install -d -o root -g wheel /Library/PrivilegedHelperTools
sudo install -d -o root -g wheel /Library/LaunchDaemons
sudo install -o root -g wheel -m 755 "$HELPER_BIN" /Library/PrivilegedHelperTools/com.sobigrice.iFans.helper
sudo install -o root -g wheel -m 644 "$HELPER_PLIST" /Library/LaunchDaemons/com.sobigrice.iFans.helper.plist
sudo launchctl bootout system/com.sobigrice.iFans.helper >/dev/null 2>&1 || true
sudo launchctl bootstrap system /Library/LaunchDaemons/com.sobigrice.iFans.helper.plist
sudo launchctl kickstart -k system/com.sobigrice.iFans.helper

echo "oh fans privileged helper installed from bundled payload."
