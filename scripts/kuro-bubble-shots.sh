#!/usr/bin/env bash
# SCRATCH ONLY: the second character's thought bubble on the home screen and 家, on a Pro and an SE.
set -euo pipefail
out=docs/screenshots/kuro-bubble
mkdir -p "$out"
xcodegen generate
pro=$(xcrun simctl list devices available -j |
  jq -r '[.devices[][] | select(.name | test("^iPhone [0-9]+ Pro$"))] | last | .udid')
se=$(xcrun simctl create "Shots SE" com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation)
for d in "$pro" "$se"; do
  xcrun simctl boot "$d" || true
  xcrun simctl bootstatus "$d" -b
  xcrun simctl spawn "$d" defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
  xcrun simctl status_bar "$d" override --time 9:41 --batteryState charged --batteryLevel 100
done
xcodebuild build-for-testing -quiet -project LifeHub.xcodeproj -scheme CheckCard -configuration Debug \
  -destination "id=$pro" -derivedDataPath build CODE_SIGNING_ALLOWED=NO
app=build/Build/Products/Debug-iphonesimulator/LifeHub.app
codesign --force --deep --sign - "$app"
codesign --force --deep --sign - build/Build/Products/Debug-iphonesimulator/LifeHubUITests-Runner.app
bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")
args=(-screenshot-mode chill -screenshot-persona kuro -screenshot-energy low -screenshot-thought)
for pair in "pro:$pro" "se:$se"; do
  name=${pair%%:*}
  d=${pair#*:}
  xcrun simctl install "$d" "$app"
  xcrun simctl launch "$d" "$bundle" "${args[@]}"
  sleep 10
  xcrun simctl launch --terminate-running-process "$d" "$bundle" "${args[@]}"
  sleep 6
  xcrun simctl io "$d" screenshot "$out/$name-main.png"
  xcrun simctl terminate "$d" "$bundle" || true
  xcodebuild test-without-building -quiet -project LifeHub.xcodeproj -scheme CheckCard \
    -destination "id=$d" -derivedDataPath build \
    -only-testing:LifeHub-UITests/KuroBubbleShots/testOpenHome &
  test=$!
  tries=0
  until xcrun simctl spawn "$d" launchctl list | grep -q "UIKitApplication:$bundle"; do
    tries=$((tries + 1))
    ((tries > 240)) && { echo "app never started" >&2; exit 1; }
    sleep 0.5
  done
  sleep 12
  xcrun simctl io "$d" screenshot "$out/$name-home.png"
  wait "$test" || true
done
ls -l "$out"
