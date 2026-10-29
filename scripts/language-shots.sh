#!/usr/bin/env bash
# Throwaway: build PROD (Release) and STG for the simulator and list what each app carries.
set -euo pipefail
mkdir -p docs/screenshots/language
xcodegen generate
for config in Release Staging; do
  if ! xcodebuild build -project LifeHub.xcodeproj -scheme LifeHub-iOS -configuration $config \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO > build-$config.log 2>&1; then
    grep -E "error:|Sandbox|deny|BUILD FAILED|failed with" build-$config.log | sort -u | head -30 | while read -r l; do echo "::warning::$config $l"; done
    continue
  fi
  app=build/Build/Products/$config-iphonesimulator/LifeHub.app
  echo "::warning::$config PlugIns: $(ls "$app/PlugIns" | tr '\n' ' ')"
  echo "::warning::$config Watch: $(ls "$app/Watch" 2>/dev/null | tr '\n' ' ')"
  for t in LifeHub-iOS LifeHub-Widgets LifeHub-Notification LifeHub-ScreenTime LifeHub-Watch LifeHub-WatchWidgets; do
    e=$(xcodebuild -project LifeHub.xcodeproj -showBuildSettings -configuration $config -target $t 2>/dev/null \
      | awk -F' = ' '/ CODE_SIGN_ENTITLEMENTS =/{print $2; exit}')
    j=""; [ -n "$e" ] && j=$(plutil -convert json -o - "$e" | tr -d '\n')
    echo "::warning::$config $t $e $j"
  done
done
