#!/usr/bin/env bash
# Records 10 s of the iPhone home screen and the watch face in each mode, once per character, plus the
# watch working late, into build/recordings/, each with a still of its last frame. Motion stays on, so
# the clips show the real animation. Needs Xcode 26 and XcodeGen.
set -euo pipefail

modes=(work chill boxing money)
personas=(haku kuro)
seconds=10
out=build/recordings
mkdir -p "$out"
xcodegen generate

# Logs a timestamped line to the console and to progress.txt, so a stuck run shows where it stopped.
note() {
  echo "$(date -u +%H:%M:%S) $*" | tee -a "$out/progress.txt"
}

# Runs a command for at most `limit` seconds, then kills it.
bounded() {
  local limit=$1
  shift
  "$@" &
  local pid=$! waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if ((waited >= limit)); then
      note "timed out after ${limit}s: $*"
      kill -9 "$pid" 2>/dev/null || true
      return 1
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid"
}

# PREVIEW ONLY: stills of the watch mode chip with the widest names, per size and language.
devices=$(xcrun simctl list devices available -j |
  jq -r '[.devices | to_entries[] | select(.key | test("watchOS"))] | last | .value | map(select(.name | test("mm")))')
note "watches: $(echo "$devices" | jq -r '[.[].name] | join(", ")')"
pick() { echo "$devices" | jq -r "$1"; }
udids=(
  "$(pick '[.[] | select(.name | test("Ultra|SE") | not)] | sort_by(.name | capture("(?<m>[0-9]+)mm").m | tonumber) | first | .udid')"
  "$(pick '[.[] | select(.name | test("Ultra|SE") | not)] | sort_by(.name | capture("(?<m>[0-9]+)mm").m | tonumber) | last | .udid')"
  "$(pick '[.[] | select(.name | test("Ultra"))] | last | .udid')"
)
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
built=""
for watch_udid in "${udids[@]}"; do
  [[ -z "$watch_udid" || "$watch_udid" == "null" ]] && continue
  size=$(echo "$devices" | jq -r ".[] | select(.udid == \"$watch_udid\") | .name" | grep -o '[0-9]*mm' | head -1)
  xcrun simctl boot "$watch_udid" || true
  note "booting watch $size"
  bounded 300 xcrun simctl bootstatus "$watch_udid" -b || true
  if [[ -z "$built" ]]; then
    xcodebuild build -quiet -project LifeHub.xcodeproj -scheme LifeHub-Watch -configuration Debug \
      -destination "id=$watch_udid" -derivedDataPath build CODE_SIGNING_ALLOWED=NO
    watch_app=build/Build/Products/Debug-watchsimulator/LifeHubWatch.app
    codesign --force --deep --sign - "$watch_app"
    built=1
  fi
  xcrun simctl install "$watch_udid" "$watch_app"
  watch_bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$watch_app/Info.plist")
  data=$(xcrun simctl get_app_container "$watch_udid" "$watch_bundle" data)
  folders=("$data/Library/Application Support/$watch_bundle")
  while IFS= read -r line; do
    folders+=("${line#*$'\t'}")
  done < <(xcrun simctl get_app_container "$watch_udid" "$watch_bundle" groups 2>/dev/null || true)
  # language, locale, mode JSON, cards JSON, name
  shot() {
    local folder
    for folder in "${folders[@]}"; do
      mkdir -p "$folder"
      cat >"$folder/watch-payload.json" <<JSON
{"schemaVersion":1,"persona":"haku","snapshot":{"schemaVersion":1,"mode":$3,"since":"$now",
"energy":"okay","line":"","updatedAt":"$now"},"scenes":[],"cards":$4}
JSON
    done
    bounded 60 xcrun simctl launch --terminate-running-process "$watch_udid" "$watch_bundle" \
      -AppleLanguages "($1)" -AppleLocale "$2" >/dev/null || return 0
    sleep 5
    note "still $5"
    bounded 30 xcrun simctl io "$watch_udid" screenshot "$out/$size-$5.png" || true
  }
  shot zh-Hans zh_CN '"boxing"' '{"names":{},"identity":"art"}' zh-identity-art
  shot zh-Hans zh_CN null null zh-no-mode
  shot zh-Hans zh_CN '"chill"' '{"names":{"chill":"一二三四"}}' zh-renamed-8
  shot en en_US '"money"' null en-projects
  shot en en_US '"chill"' '{"names":{"chill":"WWWWWWWW"}}' en-renamed-8
  shot en en_US null null en-no-mode
  shot ja ja_JP '"chill"' '{"names":{"chill":"まったり"}}' ja-renamed-8
  shot ja ja_JP '"boxing"' '{"names":{},"identity":"art"}' ja-identity-art
  xcrun simctl shutdown "$watch_udid" || true
done
note "done"
ls -l "$out"
