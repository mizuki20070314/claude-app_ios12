#!/usr/bin/env bash
# シミュレータで各画面を起動してスクリーンショットを撮る。個別の失敗でジョブ全体は落とさない。
set -u

APP_PATH="${APP_PATH:-build-sim/Build/Products/Debug-iphonesimulator/ClaudeApp.app}"
OUTDIR="${OUTDIR:-screenshots}"
SCREENS="${SCREENS:-onboarding home chat sidebar models settings projects project_detail search artifact dark_chat dark_home}"
BUNDLE_ID="com.mizuki.claudeios12"
WAIT="${WAIT:-5}"

mkdir -p "$OUTDIR"

echo "== runtimes =="; xcrun simctl list runtimes
# 最新の iOS ランタイム (Xcode 16.4 なら iOS 18.x)
RUNTIME_ID="$(xcrun simctl list runtimes -j | python3 -c '
import json,sys
rs=[r for r in json.load(sys.stdin)["runtimes"] if r.get("platform","iOS")=="iOS" and r.get("isAvailable")]
rs.sort(key=lambda r: [int(x) for x in r["version"].split(".")])
print(rs[-1]["identifier"] if rs else "")')"
echo "Runtime: $RUNTIME_ID"
[ -z "$RUNTIME_ID" ] && { echo "No iOS runtime" >&2; exit 0; }

pick_type() { # $1 = regex
  xcrun simctl list devicetypes -j | python3 -c '
import json,sys,re
pat=re.compile(sys.argv[1])
ts=[t for t in json.load(sys.stdin)["devicetypes"] if pat.search(t["name"])]
print(ts[-1]["identifier"] if ts else "")' "$1"
}

IPHONE_TYPE="$(pick_type '^iPhone SE')"
IPAD_TYPE="$(pick_type '^iPad mini')"
echo "iPhone type: $IPHONE_TYPE"; echo "iPad type: $IPAD_TYPE"

shoot() { # $1 label, $2 devicetype
  local label="$1" dtype="$2" udid
  [ -z "$dtype" ] && { echo "skip $label (no device type)"; return; }
  udid="$(xcrun simctl create "Shot-$label" "$dtype" "$RUNTIME_ID" 2>&1 | tail -n 1)"
  echo "$label udid=$udid"
  xcrun simctl boot "$udid" >/dev/null 2>&1
  xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1
  xcrun simctl status_bar "$udid" override --time "9:41" --batteryState charged --batteryLevel 100 >/dev/null 2>&1
  if ! xcrun simctl install "$udid" "$APP_PATH"; then echo "Install failed on $label" >&2; return; fi
  for screen in $SCREENS; do
    xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1
    if ! xcrun simctl launch "$udid" "$BUNDLE_ID" -screenshot "$screen" >/dev/null 2>&1; then
      echo "Launch failed: $label $screen" >&2; continue
    fi
    sleep "$WAIT"
    xcrun simctl io "$udid" screenshot "$OUTDIR/${label}_${screen}.png" >/dev/null 2>&1 \
      && echo "Screenshot ok: ${label}_${screen}" || echo "Screenshot failed: $label $screen" >&2
  done
  # クラッシュログ (あれば)
  find ~/Library/Logs/DiagnosticReports -name 'ClaudeApp*' -newer "$APP_PATH" -exec sh -c 'echo "=== CRASH $1"; head -80 "$1"' _ {} \; 2>/dev/null
  xcrun simctl shutdown "$udid" >/dev/null 2>&1
}

shoot iPhoneSE "$IPHONE_TYPE"
shoot iPadMini "$IPAD_TYPE"
ls -la "$OUTDIR"
echo "Done"
