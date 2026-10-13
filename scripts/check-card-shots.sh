#!/usr/bin/env bash
# Throwaway probe: does the home page scroll sideways?
set -euo pipefail
out=docs/screenshots/check-card
mkdir -p "$out"
xcodegen generate
udid=$(xcrun simctl list devices available -j |
  jq -r '[.devices[][] | select(.name | test("^iPhone [0-9]+ Pro$"))] | last | .udid')
xcrun simctl boot "$udid" || true
xcrun simctl bootstatus "$udid" -b
xcodebuild build-for-testing -quiet -project LifeHub.xcodeproj -scheme CheckCard -configuration Debug \
  -destination "id=$udid" -derivedDataPath build CODE_SIGNING_ALLOWED=NO
app=build/Build/Products/Debug-iphonesimulator/LifeHub.app
codesign --force --deep --sign - "$app"
codesign --force --deep --sign - build/Build/Products/Debug-iphonesimulator/LifeHubUITests-Runner.app
xcrun simctl install "$udid" "$app"
bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")
xcrun simctl privacy "$udid" grant all "$bundle" || true
TEST_RUNNER_PROBE_OUT="$PWD/$out" xcodebuild test-without-building -project LifeHub.xcodeproj -scheme CheckCard \
  -destination "id=$udid" -derivedDataPath build -only-testing:LifeHub-UITests/HomeSwipeProbe 2>&1 | tail -30 || true
ls -l "$out"
