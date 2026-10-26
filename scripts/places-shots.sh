#!/usr/bin/env bash
# Throwaway (chore/places-shots): the Settings places card with both permission lines, on the iPhone SE,
# in zh, ja and en, for HAKU and the second character.
set -euo pipefail
out=docs/screenshots/places
mkdir -p "$out"
xcodegen generate
se=$(xcrun simctl create "Places SE" com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation)
xcrun simctl boot "$se"
xcrun simctl bootstatus "$se" -b
xcrun simctl status_bar "$se" override --time 9:41 --batteryState charged --batteryLevel 100
xcodebuild build -quiet -project LifeHub.xcodeproj -scheme LifeHub-iOS -configuration Debug \
  -destination "id=$se" -derivedDataPath build CODE_SIGNING_ALLOWED=NO
app=build/Build/Products/Debug-iphonesimulator/LifeHub.app
codesign --force --deep --sign - "$app"
xcrun simctl install "$se" "$app"
bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")
xcrun simctl launch "$se" "$bundle" -screenshot-settings places
sleep 10
for persona in haku kuro; do
  for lang in zh-Hans ja en; do
    on=YES
    [ "$lang" = zh-Hans ] && on=NO
    xcrun simctl launch --terminate-running-process "$se" "$bundle" -screenshot-settings places \
      -screenshot-persona "$persona" -languages.on "$on" -AppleLanguages "($lang)"
    sleep 5
    xcrun simctl io "$se" screenshot "$out/$persona-$lang.png"
  done
done
