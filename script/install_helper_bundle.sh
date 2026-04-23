#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD_DIR="$SCRIPT_DIR/helper"

HELPER_BIN="$PAYLOAD_DIR/com.sobigrice.iFans.helper"
HELPER_PLIST="$PAYLOAD_DIR/com.sobigrice.iFans.helper.plist"
HELPER_LABEL="com.sobigrice.iFans.helper"
HELPER_DOMAIN="system/$HELPER_LABEL"

if [[ ! -x "$HELPER_BIN" ]]; then
  echo "Bundled oh fans helper binary is missing: $HELPER_BIN" >&2
  exit 1
fi

if [[ ! -f "$HELPER_PLIST" ]]; then
  echo "Bundled oh fans helper launchd plist is missing: $HELPER_PLIST" >&2
  exit 1
fi

ensure_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    sudo -v
  fi
}

run_as_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

disabled_service_line() {
  run_as_root launchctl print-disabled system 2>/dev/null \
    | awk -v label="$HELPER_LABEL" 'index($0, "\"" label "\"") { print; exit }'
}

wait_until_enabled() {
  local max_attempts=12
  local attempt=1
  local enable_output=""
  local state_line=""

  while (( attempt <= max_attempts )); do
    if ! enable_output="$(run_as_root launchctl enable "$HELPER_DOMAIN" 2>&1)"; then
      echo "辅助控件 enable 失败（第 ${attempt}/${max_attempts} 次）: $enable_output" >&2
    fi

    state_line="$(disabled_service_line || true)"
    if [[ "$state_line" != *"=> disabled"* ]]; then
      return 0
    fi

    sleep 0.5
    (( attempt++ ))
  done

  echo "辅助控件仍然处于 disabled 状态，无法继续 bootstrap。" >&2
  if [[ -n "$state_line" ]]; then
    echo "当前 launchctl print-disabled 命中: $state_line" >&2
  fi
  return 1
}

ensure_root

run_as_root install -d -o root -g wheel /Library/PrivilegedHelperTools
run_as_root install -d -o root -g wheel /Library/LaunchDaemons
run_as_root install -o root -g wheel -m 755 "$HELPER_BIN" /Library/PrivilegedHelperTools/com.sobigrice.iFans.helper
run_as_root install -o root -g wheel -m 644 "$HELPER_PLIST" /Library/LaunchDaemons/com.sobigrice.iFans.helper.plist
run_as_root launchctl bootout "$HELPER_DOMAIN" >/dev/null 2>&1 || true
wait_until_enabled
run_as_root launchctl bootstrap system /Library/LaunchDaemons/com.sobigrice.iFans.helper.plist
run_as_root launchctl kickstart -k "$HELPER_DOMAIN"
run_as_root launchctl print "$HELPER_DOMAIN" >/dev/null

echo "oh fans privileged helper installed from bundled payload."
