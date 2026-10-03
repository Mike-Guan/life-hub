#!/usr/bin/env bash
# Draws the README images: the iOS and Mac home screen in each mode, into docs/screenshots/.
# Needs Xcode 26 and XcodeGen. Uses the Debug build's -screenshot-mode launch argument.
set -euo pipefail

modes=(work chill boxing money)
out=docs/screenshots
mkdir -p "$out"
xcodegen generate

# iOS: build for the simulator, then launch each mode and screenshot it.
udid=$(xcrun simctl list devices available -j |
  jq -r '[.devices[][] | select(.name | test("^iPhone [0-9]+ Pro$"))] | last | .udid')
xcrun simctl boot "$udid" || true
xcrun simctl bootstatus "$udid" -b
# Reduce motion makes RUNNER hold its still pose, so every run draws the same frame.
xcrun simctl spawn "$udid" defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100
xcodebuild build -quiet -project LifeHub.xcodeproj -scheme LifeHub-iOS -configuration Debug \
  -destination "id=$udid" -derivedDataPath build CODE_SIGNING_ALLOWED=NO
ios_app=build/Build/Products/Debug-iphonesimulator/LifeHub.app
codesign --force --deep --sign - "$ios_app"
xcrun simctl install "$udid" "$ios_app"
bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$ios_app/Info.plist")
for mode in "${modes[@]}"; do
  xcrun simctl launch --terminate-running-process "$udid" "$bundle" -screenshot-mode "$mode"
  sleep 4
  xcrun simctl io "$udid" screenshot "$out/ios-$mode.png"
done
xcrun simctl terminate "$udid" "$bundle" || true

# Mac: launch each mode and capture just its window. The reduce motion write can be refused on
# some Macs; then RUNNER may be caught mid-blink.
defaults write com.apple.universalaccess reduceMotion -bool true || echo "Could not turn on reduce motion" >&2
xcodebuild build -quiet -project LifeHub.xcodeproj -scheme LifeHub-macOS -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO
mac_app=build/Build/Products/Debug/LifeHub.app
codesign --force --deep --sign - "$mac_app"
for mode in "${modes[@]}"; do
  "$mac_app/Contents/MacOS/LifeHub" -screenshot-mode "$mode" &
  pid=$!
  sleep 5
  window=$(swift scripts/window-id.swift "$pid")
  if [[ -z "$window" ]]; then
    echo "No window found for the Mac app in $mode mode" >&2
    kill "$pid"
    exit 1
  fi
  screencapture -x -o -l"$window" "$out/mac-$mode.png"
  kill "$pid"
  wait "$pid" || true
done
ls -l "$out"
