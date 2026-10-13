#!/bin/sh
# Checks that every app and extension built under the given product folders carries a privacy manifest
# that declares no tracking and no collected data. Run after the simulator builds in CI.
# Usage: scripts/privacy-check.sh <products folder>...
set -eu

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <products folder>..." >&2
  exit 2
fi

failed=0
count=0
for bundle in $(find "$@" \( -name '*.app' -o -name '*.appex' \) -type d); do
  count=$((count + 1))
  manifest="$bundle/PrivacyInfo.xcprivacy"
  if [ ! -f "$manifest" ]; then
    echo "::error::$bundle has no PrivacyInfo.xcprivacy"
    failed=1
    continue
  fi
  tracking=$(plutil -extract NSPrivacyTracking raw "$manifest")
  collected=$(plutil -extract NSPrivacyCollectedDataTypes raw "$manifest")
  if [ "$tracking" != "false" ] || [ "$collected" != "0" ]; then
    echo "::error::$manifest must declare no tracking and no collected data (tracking=$tracking, types=$collected)"
    failed=1
  else
    echo "ok $manifest"
  fi
done

if [ "$count" -eq 0 ]; then
  echo "::error::no app or extension found under $*"
  exit 1
fi
exit "$failed"
