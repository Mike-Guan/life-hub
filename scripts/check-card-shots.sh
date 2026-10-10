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

# The card fading in and out (0.2 s), then the same with reduce motion on.
record() {
  local name=$1
  xcrun simctl launch --terminate-running-process "$udid" "$bundle" -screenshot-mode chill \
    -screenshot-persona haku -screenshot-energy low -screenshot-check cycle
  xcrun simctl io "$udid" recordVideo --force "$out/$name.mov" &
  local recorder=$!
  sleep 5
  kill -INT "$recorder"
  wait "$recorder" || true
}
xcrun simctl spawn "$udid" defaults write com.apple.Accessibility ReduceMotionEnabled -bool false
record cycle
xcrun simctl spawn "$udid" defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
record cycle-reduce-motion
xcrun simctl terminate "$udid" "$bundle" || true
ls -l "$out"
