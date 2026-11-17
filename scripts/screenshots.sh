#!/usr/bin/env bash
set -u
set -o pipefail

APP_PATH="${APP_PATH:-build-sim/Build/Products/Debug-iphonesimulator/ClaudeApp.app}"
OUTDIR="${OUTDIR:-screenshots}"
SCREENS="${SCREENS:-onboarding home chat sidebar models settings projects search dark_chat}"

mkdir -p "$OUTDIR"

IPHONE_TYPE="iPhone SE (3rd generation)"
IPAD_TYPE="$(xcrun simctl list devicetypes | grep -i 'iPad mini' | head -n 1 | sed -E 's/^[[:space:]]*//; s/ \([^)]*\)$//')"

if [ -z "$IPAD_TYPE" ]; then
  echo "No iPad mini device type found" >&2
  exit 1
fi

RUNTIME_ID="$(xcrun simctl list runtimes | grep -i 'iOS' | grep -iv 'unavailable' | tail -n 1 | sed -n 's/.*- \(com\.apple\.CoreSimulator\.SimRuntime\.[A-Za-z0-9._-]*\).*/\1/p')"
if [ -z "$RUNTIME_ID" ]; then
  echo "No iOS runtime found" >&2
  exit 1
fi

echo "iPhone type: $IPHONE_TYPE"
echo "iPad type: $IPAD_TYPE"
echo "Runtime: $RUNTIME_ID"

boot_device() {
  local dtype="$1"
  local udid
  udid="$(xcrun simctl create "ClaudeShot-$(date +%s)-$RANDOM" "$dtype" "$RUNTIME_ID" 2>/dev/null)" || udid=""
  if [ -z "$udid" ]; then
    echo "Failed to create simulator for $dtype" >&2
    return 1
  fi
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b 2>/dev/null || true
  xcrun simctl status_bar "$udid" override --time "9:41" 2>/dev/null || true
  echo "$udid"
}

run_on_device() {
  local label="$1"
  local udid="$2"
  echo "Installing on $label ($udid)"
  if ! xcrun simctl install "$udid" "$APP_PATH"; then
    echo "Install failed on $label" >&2
    return 0
  fi
  for screen in $SCREENS; do
    echo "Capturing $label / $screen"
    xcrun simctl launch --terminate-running-process "$udid" com.mizuki.claudeios12 -screenshot "$screen" >/dev/null 2>&1 || echo "Launch failed: $label $screen" >&2
    sleep 4
    if ! xcrun simctl io "$udid" screenshot "$OUTDIR/${label}_${screen}.png" 2>/dev/null; then
      echo "Screenshot failed: $label $screen" >&2
    fi
  done
}

IPHONE_UDID="$(boot_device "$IPHONE_TYPE")"
if [ -n "$IPHONE_UDID" ]; then
  run_on_device "iPhoneSE" "$IPHONE_UDID"
fi

IPAD_UDID="$(boot_device "$IPAD_TYPE")"
if [ -n "$IPAD_UDID" ]; then
  run_on_device "iPadMini" "$IPAD_UDID"
fi

echo "Done"
