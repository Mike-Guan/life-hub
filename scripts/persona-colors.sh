#!/usr/bin/env bash
# Fails when app code paints a mode color without saying whose. Each character has her own mode colors
# (`Mode.color(for:)`); the bare `Mode.color` is HAKU's and showed up on KURO's cards twice (10-07, 10-08).
# A line that is HAKU's on purpose ends with a `// HAKU only:` comment saying why.
set -euo pipefail

hits=$(grep -rnP --include='*.swift' '(\bmode\??|Mode\.\w+|\.mode\??)\.color\b(?!\s*\()' Apps | grep -v '// HAKU only:' || true)
if [[ -n "$hits" ]]; then
  echo "$hits"
  echo "::error::Use Mode.color(for: persona) in app code, or end the line with '// HAKU only: <why>'."
  exit 1
fi
echo "Every mode color in app code names its character."
