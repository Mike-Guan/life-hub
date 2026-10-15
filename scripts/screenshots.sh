#!/usr/bin/env bash
# Preview only (#392): Japanese font shots on Pro Max and SE, plus one Chinese SE home.
set -euo pipefail
out=docs/screenshots
rm -rf "$out"
mkdir -p "$out"
xcodegen generate
pro=$(xcrun simctl list devices available -j |
  jq -r '[.devices[][] | select(.name | test("^iPhone [0-9]+ Pro Max$"))] | last | .udid')
se=$(xcrun simctl create "Screenshot SE" com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation)
for d in "$pro" "$se"; do
  xcrun simctl boot "$d" || true
  xcrun simctl bootstatus "$d" -b
  xcrun simctl spawn "$d" defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
  xcrun simctl status_bar "$d" override --time 9:41 --batteryState charged --batteryLevel 100
done
xcodebuild build -quiet -project LifeHub.xcodeproj -scheme LifeHub-iOS -configuration Debug \
  -destination "id=$pro" -derivedDataPath build CODE_SIGNING_ALLOWED=NO
app=build/Build/Products/Debug-iphonesimulator/LifeHub.app
codesign --force --deep --sign - "$app"
bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")
ja=(-AppleLanguages "(ja)" -AppleLocale ja_JP -languages.on YES)
shot() {
  local device=$1 name=$2
  shift 2
  xcrun simctl launch --terminate-running-process "$device" "$bundle" "$@"
  sleep 6
  xcrun simctl io "$device" screenshot "$out/$name.png"
}
for pair in "$pro:promax" "$se:se"; do
  d=${pair%%:*}
  p=${pair##*:}
  xcrun simctl install "$d" "$app"
  xcrun simctl launch "$d" "$bundle" -screenshot-growth shop "${ja[@]}"
  sleep 12
  shot "$d" "$p-ja-home" -screenshot-mode chill "${ja[@]}"
  shot "$d" "$p-ja-home-line" -screenshot-mode chill -screenshot-line "门口那个包，在看你。" "${ja[@]}"
  shot "$d" "$p-ja-home-line2" -screenshot-mode chill -screenshot-line "表在走，我们没走。" "${ja[@]}"
  shot "$d" "$p-ja-shop" -screenshot-growth shop -screenshot-persona haku "${ja[@]}"
  shot "$d" "$p-ja-settings" -screenshot-settings card "${ja[@]}"
  shot "$d" "$p-ja-onboarding-persona" -screenshot-onboarding persona "${ja[@]}"
  shot "$d" "$p-ja-onboarding-intro" -screenshot-onboarding intro "${ja[@]}"
  shot "$d" "$p-ja-wardrobe-art" -screenshot-growth wardrobe -screenshot-identity art "${ja[@]}"
done
shot "$se" "se-zh-home" -screenshot-mode chill -AppleLanguages "(zh-Hans)" -AppleLocale zh_CN -languages.on NO
shot "$se" "se-zh-home-line" -screenshot-mode chill -screenshot-line "门口那个包，在看你。" \
  -AppleLanguages "(zh-Hans)" -AppleLocale zh_CN -languages.on NO
xcrun simctl delete "$se"
ls -l "$out"
