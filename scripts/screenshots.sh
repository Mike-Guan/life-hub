#!/usr/bin/env bash
# preview/ branch only: shop two-tab shots for UI 审核 (#508).
set -euo pipefail
out=docs/screenshots
mkdir -p "$out"
xcodegen generate
udid=$(xcrun simctl list devices available -j |
  jq -r '[.devices[][] | select(.name | test("^iPhone [0-9]+ Pro$"))] | last | .udid')
xcrun simctl boot "$udid" || true
xcrun simctl bootstatus "$udid" -b
xcrun simctl spawn "$udid" defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100
xcodebuild build -quiet -project LifeHub.xcodeproj -scheme LifeHub-iOS -configuration Debug \
  -destination "id=$udid" -derivedDataPath build CODE_SIGNING_ALLOWED=NO
ios_app=build/Build/Products/Debug-iphonesimulator/LifeHub.app
codesign --force --deep --sign - "$ios_app"
bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$ios_app/Info.plist")
shots() {
  local device=$1 prefix=$2
  xcrun simctl install "$device" "$ios_app"
  xcrun simctl launch "$device" "$bundle" -screenshot-growth shop -screenshot-persona haku
  sleep 10
  for lang in zh-Hans; do
    for screen in shop shop-room; do
      xcrun simctl launch --terminate-running-process "$device" "$bundle" -screenshot-growth "$screen" \
        -screenshot-persona haku -AppleLanguages "($lang)" -languages.on YES
      sleep 4
      xcrun simctl io "$device" screenshot "$out/$prefix-$screen-$lang.png"
    done
  done
}
shots "$udid" ios
if se=$(xcrun simctl create "Screenshot SE" com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation); then
  xcrun simctl boot "$se"
  xcrun simctl bootstatus "$se" -b
  xcrun simctl spawn "$se" defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
  xcrun simctl status_bar "$se" override --time 9:41 --batteryState charged --batteryLevel 100
  shots "$se" ios-se
fi
