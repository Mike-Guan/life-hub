#!/usr/bin/env bash
# Draws the README images: the iOS and Mac home screen in each mode, into docs/screenshots/.
# Also the iOS memory page, settings, shop, wardrobe, unboxing and first-run setup for UI 审核, the last
# four on the smallest iPhone too.
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
  sleep 10
  xcrun simctl io "$udid" screenshot "$out/ios-$mode.png"
  # The same mode with KURO picked, for checking the second character before an install.
  xcrun simctl launch --terminate-running-process "$udid" "$bundle" -screenshot-mode "$mode" \
    -screenshot-persona kuro
  sleep 10
  xcrun simctl io "$udid" screenshot "$out/ios-kuro-$mode.png"
done
# Throwaway preview branch: only the home screen, on Pro above and SE here.
if se=$(xcrun simctl create "Screenshot SE" com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation); then
  xcrun simctl boot "$se"
  xcrun simctl bootstatus "$se" -b
  xcrun simctl spawn "$se" defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
  xcrun simctl status_bar "$se" override --time 9:41 --batteryState charged --batteryLevel 100
  xcrun simctl install "$se" "$ios_app"
  xcrun simctl launch "$se" "$bundle" -screenshot-mode chill
  sleep 10
  for mode in "${modes[@]}"; do
    for persona in haku kuro; do
      xcrun simctl launch --terminate-running-process "$se" "$bundle" -screenshot-mode "$mode" \
        -screenshot-persona "$persona"
      sleep 10
      xcrun simctl io "$se" screenshot "$out/ios-se-$persona-$mode.png"
    done
  done
fi
