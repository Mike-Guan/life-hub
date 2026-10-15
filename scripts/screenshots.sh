#!/usr/bin/env bash
# Preview only (D5): the longest line in each language over HAKU, three bubble variants, SE and Pro Max.
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
shot() {
  local device=$1 name=$2
  shift 2
  xcrun simctl launch --terminate-running-process "$device" "$bundle" "$@"
  sleep 6
  xcrun simctl io "$device" screenshot "$out/$name.png"
}
for pair in "$se:se" "$pro:promax"; do
  d=${pair%%:*}
  p=${pair##*:}
  xcrun simctl install "$d" "$app"
  xcrun simctl launch "$d" "$bundle" -screenshot-mode chill
  sleep 12
  for v in a b c; do
    for mode in chill work; do
      shot "$d" "$p-$v-$mode-zh" -screenshot-mode "$mode" -bubble-variant "$v" \
        -screenshot-line "拳套有点味道。不是我的问题。" -AppleLanguages "(zh-Hans)" -languages.on NO
      shot "$d" "$p-$v-$mode-ja" -screenshot-mode "$mode" -bubble-variant "$v" \
        -screenshot-line "時計は進む。俺らは進まない。" -AppleLanguages "(ja)" -AppleLocale ja_JP -languages.on YES
      shot "$d" "$p-$v-$mode-en" -screenshot-mode "$mode" -bubble-variant "$v" \
        -screenshot-line "Something's coming up. Get up and get ready?" -AppleLanguages "(en)" -AppleLocale en_US \
        -languages.on YES
    done
  done
done
xcrun simctl delete "$se"
ls -l "$out"
