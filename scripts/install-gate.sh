#!/usr/bin/env bash
# Run on the Mac before every install to a real iPhone or watch. It stops unless the checkout is a clean
# sha on main, which is merged only with green CI. Install only when it prints "gate ok".
# Mike 2026-10-13: installs no longer wait for a per-build QA release or his 「装」; CI must be green.
# Usage: scripts/install-gate.sh <sha>
set -euo pipefail

if (($# != 1)); then
  echo "Usage: scripts/install-gate.sh <sha>" >&2
  exit 1
fi
sha=$1

stop() {
  echo "gate stop: $1. Do not install; tell the 工程 thread." >&2
  exit 1
}

[[ "$sha" =~ ^[0-9a-f]{7,40}$ ]] || stop "\"$sha\" is not a commit sha"
[[ -z "$(git status --porcelain)" ]] || stop "the checkout has local changes"
head=$(git rev-parse HEAD)
[[ "$head" == "$sha"* ]] || stop "the checkout is ${head:0:7}, not ${sha:0:7}"
git fetch --quiet origin main || stop "could not fetch main"
git merge-base --is-ancestor "$head" origin/main || stop "${sha:0:7} is not on main, so its CI is not known green"

out="$HOME/LifeHub-QA/install-${sha:0:7}"
mkdir -p "$out"
printf '%s\tsha %s\n' "$(date -u +%FT%TZ)" "$head" >>"$out/gate.txt"
echo "gate ok: ${head:0:7}. Install the same sha on the iPhone and the watch."
