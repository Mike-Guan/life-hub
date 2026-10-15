#!/usr/bin/env bash
# Fails when app or package code uses a bouncy spring. UI 审核 (2026-10-13, 视觉现状 §2): every tap, hop and
# bubble eases back once and never springs past where it rests.
set -euo pipefail

hits=$(grep -rnE --include='*.swift' '\.bouncy\b|dampingFraction: *0\.[0-8]\b|extraBounce: *0\.[1-9]|bounce: *0\.[1-9]' Apps Packages || true)
if [[ -n "$hits" ]]; then
  echo "$hits"
  echo "::error::Use an ease-out or .smooth with no bounce (UI 审核 视觉现状 §2)."
  exit 1
fi
echo "No bouncy springs."
