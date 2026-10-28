#!/usr/bin/env bash
# Launches the watch app on a watch simulator with a sample payload, once per character, and fails when the
# app quits or keeps the CPU busy. Run after the watch build in CI; screenshots go to build/watch-launch/.
# Usage: scripts/watch-launch-check.sh path/to/LifeHubWatch.app
set -euo pipefail

app=$1
out=build/watch-launch
mkdir -p "$out"

# The newest watchOS runtime (older ones can't run the app), smallest screen first, where page 2 is tightest.
udid=$(xcrun simctl list devices available -j |
  jq -r '[.devices | to_entries[] | select(.key | test("watchOS"))
      | {v: (.key | [scan("[0-9]+")] | map(tonumber)), d: .value}
      | select(.d | length > 0)] | sort_by(.v) | last | .d // []
    | ([.[] | select(.name | test("40mm"))] + [.[] | select(.name | test("41mm"))]
      + [.[] | select(.name | test("42mm"))] + [last])
    | first | .udid')
echo "::notice::Watch simulator: $(xcrun simctl list devices | grep "$udid" | sed 's/^ *//')"
if [[ -z "$udid" || "$udid" == "null" ]]; then
  echo "::error::No watch simulator available"
  exit 1
fi
xcrun simctl boot "$udid" || true
xcrun simctl bootstatus "$udid" -b

codesign --force --deep --sign - "$app"
xcrun simctl install "$udid" "$app"
bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")

# Unsigned builds have no App Group, so the app falls back to Application Support/<bundle id>/.
data=$(xcrun simctl get_app_container "$udid" "$bundle" data)
folders=("$data/Library/Application Support/$bundle")
while IFS= read -r line; do
  folders+=("${line#*$'\t'}")
done < <(xcrun simctl get_app_container "$udid" "$bundle" groups 2>/dev/null || true)

# CPU time of `pid` in hundredths of a second; ps prints [hh:]mm:ss.cc.
cpu_centiseconds() {
  # cputime is mm:ss.cc or hh:mm:ss.cc.
  ps -o cputime= -p "$1" | awk -F'[:.]' '{s = 0; for (i = 1; i < NF; i++) s = s * 60 + $i; print s * 100 + $NF}'
}

now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
failed=false
for persona in haku kuro; do
  for folder in "${folders[@]}"; do
    mkdir -p "$folder"
    cat >"$folder/watch-payload.json" <<JSON
{"schemaVersion":1,"persona":"$persona","snapshot":{"schemaVersion":1,"mode":"work","since":"$now",
"energy":"okay","line":"今天会开得有点多，记得起来走两步，晚上早点回家睡觉","updatedAt":"$now"}}
JSON
  done
  pid=$(xcrun simctl launch --terminate-running-process "$udid" "$bundle" | awk '{print $NF}')
  sleep 20
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "::error::The watch app quit within 20 s of launch with $persona"
    failed=true
    continue
  fi
  xcrun simctl io "$udid" screenshot "$out/watch-$persona.png"
  # A hung first frame spins the main thread; a drawn page mostly waits for the next animation frame.
  before=$(cpu_centiseconds "$pid")
  sleep 10
  after=$(cpu_centiseconds "$pid")
  busy=$(((after - before) / 10))
  # A real watch is many times slower than this Mac, so the CPU used at launch is the number to watch.
  echo "::notice::$persona: ${before} cs CPU in the first 20 s, then ${busy}% over 10 s"
  if ((busy >= 80)); then
    echo "::error::The watch app kept the CPU at ${busy}% with $persona; its first frame may never finish"
    failed=true
  fi
  # Page 2 for the layout review; Debug builds open on it with -today-page.
  xcrun simctl launch --terminate-running-process "$udid" "$bundle" -today-page >/dev/null
  sleep 8
  xcrun simctl io "$udid" screenshot "$out/watch-$persona-today.png"
done
# Page 2 in Japanese and English with the longest lines so far, for the layout review (UI 审核, #439).
# Two hours in work mode makes the relative time long too.
since=$(date -u -v-125M +%Y-%m-%dT%H:%M:%SZ)
for sample in "ja|ja_JP|時計は進む。俺らは進まない。" "en|en_US|You got up 12 times this week. …Not that I'm counting."; do
  IFS='|' read -r lang locale line <<<"$sample"
  for folder in "${folders[@]}"; do
    cat >"$folder/watch-payload.json" <<JSON
{"schemaVersion":1,"persona":"haku","snapshot":{"schemaVersion":1,"mode":"work","since":"$since",
"energy":"okay","line":"$line","updatedAt":"$now"}}
JSON
  done
  xcrun simctl launch --terminate-running-process "$udid" "$bundle" -today-page \
    -AppleLanguages "($lang)" -AppleLocale "$locale" >/dev/null
  sleep 8
  xcrun simctl io "$udid" screenshot "$out/watch-haku-today-$lang.png"
done
# Before the iPhone has sent anything, for the layout review (UI 二组 交付差距 item 4).
for folder in "${folders[@]}"; do
  rm -f "$folder/watch-payload.json"
done
xcrun simctl launch --terminate-running-process "$udid" "$bundle" >/dev/null
sleep 8
xcrun simctl io "$udid" screenshot "$out/watch-first-run.png"
xcrun simctl terminate "$udid" "$bundle" || true
! $failed
