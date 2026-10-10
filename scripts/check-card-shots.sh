#!/usr/bin/env bash
# Draws the "不对" card (Issue #236) for UI 审核: HAKU and KURO in each mode at each energy level with
# the card open, the reply after a correction, and a few in dark mode, into docs/screenshots/check-card/.
# Needs Xcode 26 and XcodeGen. Uses the Debug build's -screenshot-* launch arguments.
set -euo pipefail

out=docs/screenshots/check-card
mkdir -p "$out"
xcodegen generate

udid=$(xcrun simctl list devices available -j |
  jq -r '[.devices[][] | select(.name | test("^iPhone [0-9]+ Pro$"))] | last | .udid')
xcrun simctl boot "$udid" || true
xcrun simctl bootstatus "$udid" -b
# Reduce motion: the card appears without sliding, so every run draws the same frame.
xcrun simctl spawn "$udid" defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100
xcodebuild build -quiet -project LifeHub.xcodeproj -scheme LifeHub-iOS -configuration Debug \
  -destination "id=$udid" -derivedDataPath build CODE_SIGNING_ALLOWED=NO
app=build/Build/Products/Debug-iphonesimulator/LifeHub.app
codesign --force --deep --sign - "$app"
xcrun simctl install "$udid" "$app"
bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")

shoot() {
  local name=$1
  shift
  xcrun simctl launch --terminate-running-process "$udid" "$bundle" "$@"
  sleep 5
  xcrun simctl io "$udid" screenshot "$out/$name.png"
}

xcrun simctl ui "$udid" appearance light
# The first launch after install is slow; a throwaway shot keeps it out of the set.
shoot warmup -screenshot-mode work
rm -f "$out/warmup.png"
for persona in haku kuro; do
  for mode in work chill boxing money; do
    for energy in low okay full; do
      shoot "$persona-$mode-$energy" -screenshot-mode "$mode" -screenshot-persona "$persona" \
        -screenshot-energy "$energy" -screenshot-check open
    done
  done
  shoot "$persona-reply" -screenshot-mode chill -screenshot-persona "$persona" -screenshot-energy okay \
    -screenshot-check reply
done

xcrun simctl ui "$udid" appearance dark
for persona in haku kuro; do
  for energy in low full; do
    shoot "dark-$persona-chill-$energy" -screenshot-mode chill -screenshot-persona "$persona" \
      -screenshot-energy "$energy" -screenshot-check open
  done
done
xcrun simctl ui "$udid" appearance light

# A long press on HAKU opens the card (0.2 s fade), a tap on the dim layer closes it; then the same with
# reduce motion on. Apps/UITests does the touches; the recording starts once the app is up.
xcodebuild build-for-testing -quiet -project LifeHub.xcodeproj -scheme CheckCard -configuration Debug \
  -destination "id=$udid" -derivedDataPath build CODE_SIGNING_ALLOWED=NO
codesign --force --deep --sign - "$app"
codesign --force --deep --sign - build/Build/Products/Debug-iphonesimulator/LifeHubUITests-Runner.app
record() {
  local name=$1
  xcrun simctl terminate "$udid" "$bundle" || true
  xcodebuild test-without-building -quiet -project LifeHub.xcodeproj -scheme CheckCard \
    -destination "id=$udid" -derivedDataPath build &
  local test=$!
  local tries=0
  until xcrun simctl spawn "$udid" launchctl list | grep -q "UIKitApplication:$bundle"; do
    tries=$((tries + 1))
    if ((tries > 240)); then
      echo "The app never started for $name" >&2
      exit 1
    fi
    sleep 0.5
  done
  xcrun simctl io "$udid" recordVideo --force "$out/$name.mov" &
  local recorder=$!
  wait "$test"
  kill -INT "$recorder"
  wait "$recorder" || true
}
xcrun simctl spawn "$udid" defaults write com.apple.Accessibility ReduceMotionEnabled -bool false
record hold
xcrun simctl spawn "$udid" defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
record hold-reduce-motion
xcrun simctl terminate "$udid" "$bundle" || true
ls -l "$out"
