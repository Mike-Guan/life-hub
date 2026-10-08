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

# Records `seconds` of the simulator `udid` into `name`.mp4, then a still into `name`.png.
record() {
  note "recording $2"
  xcrun simctl io "$1" recordVideo --codec=h264 --force "$2.mp4" &
  local pid=$! waited=0
  sleep "$seconds"
  kill -INT "$pid" 2>/dev/null || true
  # Writing the file can take a moment; a recorder that never stops must not hold up the rest.
  while kill -0 "$pid" 2>/dev/null && ((waited < 20)); do
    sleep 1
    waited=$((waited + 1))
  done
  kill -9 "$pid" 2>/dev/null || true
  bounded 30 xcrun simctl io "$1" screenshot "$2.png" || true
}

# iPhone: the Debug build's -screenshot-mode home screen.
udid=$(xcrun simctl list devices available -j |
  jq -r '[.devices[][] | select(.name | test("^iPhone [0-9]+ Pro$"))] | last | .udid')
xcrun simctl boot "$udid" || true
note "booting iPhone"
bounded 300 xcrun simctl bootstatus "$udid" -b || true
xcrun simctl spawn "$udid" defaults write -g AppleLanguages -array zh-Hans
xcrun simctl spawn "$udid" defaults write -g AppleLocale zh_CN
xcrun simctl spawn "$udid" defaults write com.apple.Accessibility ReduceMotionEnabled -bool false
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100
note "building iPhone app"
xcodebuild build -quiet -project LifeHub.xcodeproj -scheme LifeHub-iOS -configuration Debug \
  -destination "id=$udid" -derivedDataPath build CODE_SIGNING_ALLOWED=NO
ios_app=build/Build/Products/Debug-iphonesimulator/LifeHub.app
codesign --force --deep --sign - "$ios_app"
xcrun simctl install "$udid" "$ios_app"
bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$ios_app/Info.plist")
for persona in "${personas[@]}"; do
  for mode in "${modes[@]}"; do
    bounded 60 xcrun simctl launch --terminate-running-process "$udid" "$bundle" -screenshot-mode "$mode" \
      -screenshot-persona "$persona" || continue
    sleep 3
    record "$udid" "$out/ios-$persona-$mode"
  done
done
xcrun simctl terminate "$udid" "$bundle" || true
xcrun simctl shutdown "$udid" || true

# Watch: the app shows the payload the iPhone would send, so write one per mode and character.
watch_udid=$(xcrun simctl list devices available -j |
  jq -r '[.devices | to_entries[] | select(.key | test("watchOS")) | .value[]] | last | .udid')
if [[ -z "$watch_udid" || "$watch_udid" == "null" ]]; then
  echo "::warning::No watch simulator available, skipping watch clips"
  note "done"
ls -l "$out"
  exit 0
fi
xcrun simctl boot "$watch_udid" || true
note "booting watch"
bounded 300 xcrun simctl bootstatus "$watch_udid" -b || true
xcrun simctl spawn "$watch_udid" defaults write -g AppleLanguages -array zh-Hans
xcrun simctl spawn "$watch_udid" defaults write -g AppleLocale zh_CN
note "building watch app"
xcodebuild build -quiet -project LifeHub.xcodeproj -scheme LifeHub-Watch -configuration Debug \
  -destination "id=$watch_udid" -derivedDataPath build CODE_SIGNING_ALLOWED=NO
watch_app=build/Build/Products/Debug-watchsimulator/LifeHubWatch.app
codesign --force --deep --sign - "$watch_app"
xcrun simctl install "$watch_udid" "$watch_app"
watch_bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$watch_app/Info.plist")

# Unsigned builds have no App Group, so the app falls back to Application Support/<bundle id>/.
data=$(xcrun simctl get_app_container "$watch_udid" "$watch_bundle" data)
folders=("$data/Library/Application Support/$watch_bundle")
while IFS= read -r line; do
  folders+=("${line#*$'\t'}")
done < <(xcrun simctl get_app_container "$watch_udid" "$watch_bundle" groups 2>/dev/null || true)

now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
later=$(date -u -v+2H +%Y-%m-%dT%H:%M:%SZ)
# Writes a payload for `persona` in `mode`, with `scenes` JSON, launches the app and records it as `name`.
watch_clip() {
  local folder
  for folder in "${folders[@]}"; do
    mkdir -p "$folder"
    cat >"$folder/watch-payload.json" <<JSON
{"schemaVersion":1,"persona":"$1","snapshot":{"schemaVersion":1,"mode":"$2","since":"$now",
"energy":"okay","line":"","updatedAt":"$now"},"scenes":$3}
JSON
  done
  bounded 60 xcrun simctl launch --terminate-running-process "$watch_udid" "$watch_bundle" >/dev/null || return 0
  sleep 4
  record "$watch_udid" "$out/$4"
}
for persona in "${personas[@]}"; do
  for mode in "${modes[@]}"; do
    watch_clip "$persona" "$mode" "[]" "watch-$persona-$mode"
  done
    # HAKU shows it as the overtime moment, KURO from overtimeUntil; the iPhone sends both.
  watch_clip "$persona" work \
    "[{\"from\":\"$now\",\"scene\":{\"moment\":\"overtime\",\"overtimeUntil\":\"$later\"}}]" \
    "watch-$persona-overtime"
done
note "done"
ls -l "$out"
