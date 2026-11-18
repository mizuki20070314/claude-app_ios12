#!/usr/bin/env bash
# シミュレータで各画面を起動してスクリーンショットを撮る。個別の失敗でジョブ全体は落とさない。
set -u

APP_PATH="${APP_PATH:-build-sim/Build/Products/Debug-iphonesimulator/ClaudeApp.app}"
OUTDIR="${OUTDIR:-screenshots}"
SCREENS="${SCREENS:-onboarding account_login home chat sidebar models settings projects project_detail search artifact dark_chat dark_home code_sessions code_session}"
BUNDLE_ID="com.mizuki.claudeios12"
WAIT="${WAIT:-5}"

mkdir -p "$OUTDIR"

xcrun simctl list runtimes -j > /tmp/runtimes.json
# 使用中の Xcode の SDK と同じメジャーの iOS ランタイムを優先 (Xcode 16.4 → iOS 18.x)
SDK_MAJOR="$(xcrun --sdk iphonesimulator --show-sdk-version | cut -d. -f1)"
RUNTIME_ID="$(python3 - "$SDK_MAJOR" <<'PY'
import json,sys
major=sys.argv[1]
rs=[r for r in json.load(open("/tmp/runtimes.json"))["runtimes"] if r.get("platform","iOS")=="iOS" and r.get("isAvailable")]
key=lambda r:[int(x) for x in r["version"].split(".")]
same=[r for r in rs if r["version"].split(".")[0]==major]
pool=sorted(same or rs,key=key)
print(pool[-1]["identifier"] if pool else "")
PY
)"
echo "SDK major: $SDK_MAJOR / Runtime: $RUNTIME_ID"
[ -z "$RUNTIME_ID" ] && { echo "No iOS runtime" >&2; exit 0; }

pick_type() { # $1 = regex — ランタイムがサポートするデバイスから選ぶ
  python3 - "$RUNTIME_ID" "$1" <<'PY'
import json,sys,re
rid,pat=sys.argv[1],re.compile(sys.argv[2])
for r in json.load(open("/tmp/runtimes.json"))["runtimes"]:
    if r["identifier"]==rid:
        ts=[t for t in r.get("supportedDeviceTypes",[]) if pat.search(t["name"])]
        print(ts[-1]["identifier"] if ts else "")
PY
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
    if ! xcrun simctl launch "$udid" "$BUNDLE_ID" -screenshot "$screen" -AppleLanguages "(${APP_LANG:-ja})" -AppleLocale "${APP_LOCALE:-ja_JP}" >/dev/null 2>&1; then
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
