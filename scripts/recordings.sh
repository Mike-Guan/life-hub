#!/usr/bin/env bash
# Records 10 s of the iPhone home screen and the watch face in each mode, once per character, into
# build/recordings/. Motion stays on, so the clips show the real animation. Needs Xcode 26 and XcodeGen.
set -euo pipefail

modes=(work chill boxing money)
personas=(haku kuro)
seconds=10
out=build/recordings
mkdir -p "$out"
xcodegen generate

# Records `seconds` of the simulator `udid` into `file`.
record() {
  xcrun simctl io "$1" recordVideo --codec=h264 --force "$2" &
  local pid=$!
  sleep "$seconds"
  kill -INT "$pid"
  wait "$pid" || true
}

# iPhone: the Debug build's -screenshot-mode home screen.
udid=$(xcrun simctl list devices available -j |
  jq -r '[.devices[][] | select(.name | test("^iPhone [0-9]+ Pro$"))] | last | .udid')
xcrun simctl boot "$udid" || true
xcrun simctl bootstatus "$udid" -b
xcrun simctl spawn "$udid" defaults write com.apple.Accessibility ReduceMotionEnabled -bool false
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100
xcodebuild build -quiet -project LifeHub.xcodeproj -scheme LifeHub-iOS -configuration Debug \
  -destination "id=$udid" -derivedDataPath build CODE_SIGNING_ALLOWED=NO
ios_app=build/Build/Products/Debug-iphonesimulator/LifeHub.app
codesign --force --deep --sign - "$ios_app"
xcrun simctl install "$udid" "$ios_app"
bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$ios_app/Info.plist")
for persona in "${personas[@]}"; do
  for mode in "${modes[@]}"; do
    xcrun simctl launch --terminate-running-process "$udid" "$bundle" -screenshot-mode "$mode" \
      -screenshot-persona "$persona"
    sleep 3
    record "$udid" "$out/ios-$persona-$mode.mp4"
  done
done
xcrun simctl terminate "$udid" "$bundle" || true
xcrun simctl shutdown "$udid" || true

# Watch: the app shows the payload the iPhone would send, so write one per mode and character.
watch_udid=$(xcrun simctl list devices available -j |
  jq -r '[.devices | to_entries[] | select(.key | test("watchOS")) | .value[]] | last | .udid')
if [[ -z "$watch_udid" || "$watch_udid" == "null" ]]; then
  echo "::warning::No watch simulator available, skipping watch clips"
  ls -l "$out"
  exit 0
fi
xcrun simctl boot "$watch_udid" || true
xcrun simctl bootstatus "$watch_udid" -b
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
for persona in "${personas[@]}"; do
  for mode in "${modes[@]}"; do
    for folder in "${folders[@]}"; do
      mkdir -p "$folder"
      cat >"$folder/watch-payload.json" <<JSON
{"schemaVersion":1,"persona":"$persona","snapshot":{"schemaVersion":1,"mode":"$mode","since":"$now",
"energy":"okay","line":"","updatedAt":"$now"}}
JSON
    done
    xcrun simctl launch --terminate-running-process "$watch_udid" "$watch_bundle" >/dev/null
    sleep 4
    record "$watch_udid" "$out/watch-$persona-$mode.mp4"
  done
done
ls -l "$out"
