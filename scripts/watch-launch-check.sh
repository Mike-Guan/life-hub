#!/usr/bin/env bash
# Launches the watch app on a watch simulator with a sample payload, once per character, and fails when the
# app quits or keeps the CPU busy. Run after the watch build in CI; screenshots go to build/watch-launch/.
# Usage: scripts/watch-launch-check.sh path/to/LifeHubWatch.app
set -euo pipefail

app=$1
out=build/watch-launch
mkdir -p "$out"

udid=$(xcrun simctl list devices available -j |
  jq -r '[.devices | to_entries[] | select(.key | test("watchOS")) | .value[]] | last | .udid')
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

now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
failed=false
for persona in haku kuro; do
  for folder in "${folders[@]}"; do
    mkdir -p "$folder"
    cat >"$folder/watch-payload.json" <<JSON
{"schemaVersion":1,"persona":"$persona","snapshot":{"schemaVersion":1,"mode":"work","since":"$now",
"energy":"okay","line":"上班中","updatedAt":"$now"}}
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
  before=$(ps -o cputime= -p "$pid" | awk -F'[:.]' '{print ($1 * 60 + $2) * 100 + $3}')
  sleep 10
  after=$(ps -o cputime= -p "$pid" | awk -F'[:.]' '{print ($1 * 60 + $2) * 100 + $3}')
  busy=$(((after - before) / 10))
  echo "$persona: CPU ${busy}% over 10 s"
  if ((busy >= 80)); then
    echo "::error::The watch app kept the CPU at ${busy}% with $persona; its first frame may never finish"
    failed=true
  fi
done
xcrun simctl terminate "$udid" "$bundle" || true
! $failed
