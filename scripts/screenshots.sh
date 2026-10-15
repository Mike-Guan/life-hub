#!/usr/bin/env bash
# Preview only (D5): the second preset character's longest line in each language over her two hats, on the SE.
set -euo pipefail
out=docs/screenshots
rm -rf "$out"
mkdir -p "$out"
xcodegen generate
se=$(xcrun simctl create "Screenshot SE" com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation)
xcrun simctl boot "$se" || true
xcrun simctl bootstatus "$se" -b
xcrun simctl spawn "$se" defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
xcrun simctl status_bar "$se" override --time 9:41 --batteryState charged --batteryLevel 100
xcodebuild build -quiet -project LifeHub.xcodeproj -scheme LifeHub-iOS -configuration Debug \
  -destination "id=$se" -derivedDataPath build CODE_SIGNING_ALLOWED=NO
app=build/Build/Products/Debug-iphonesimulator/LifeHub.app
codesign --force --deep --sign - "$app"
bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")
shot() {
  local name=$1
  shift
  xcrun simctl launch --terminate-running-process "$se" "$bundle" -screenshot-persona kuro "$@"
  sleep 9
  xcrun simctl io "$se" screenshot "$out/$name.png"
}
xcrun simctl install "$se" "$app"
xcrun simctl launch "$se" "$bundle" -screenshot-mode chill -screenshot-persona kuro
sleep 20
for pair in "rain:work:kuro.set.work.rain" "picnic:chill:kuro.set.chill.picnic" "ears:chill:"; do
  IFS=: read -r hat mode wearing <<<"$pair"
  wear=()
  [ -n "$wearing" ] && wear=(-screenshot-wearing "$wearing")
  shot "se-$hat-zh" -screenshot-mode "$mode" ${wear[@]+"${wear[@]}"} \
    -screenshot-line "……我们今天，真的不动了吗。" -AppleLanguages "(zh-Hans)" -languages.on NO
  shot "se-$hat-ja" -screenshot-mode "$mode" ${wear[@]+"${wear[@]}"} \
    -screenshot-line "玄関のバッグ、こっち見てる。" -AppleLanguages "(ja)" -AppleLocale ja_JP -languages.on YES
  shot "se-$hat-en" -screenshot-mode "$mode" ${wear[@]+"${wear[@]}"} \
    -screenshot-line "door's right there. …just asking." -AppleLanguages "(en)" -AppleLocale en_US \
    -languages.on YES
done
xcrun simctl delete "$se"
ls -l "$out"
