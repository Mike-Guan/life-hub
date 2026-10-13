#!/usr/bin/env bash
# Run on the Mac before every install to a real iPhone or watch. It stops unless the checkout is a clean
# sha on main whose release run passed. Install only when it prints "gate ok".
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
# A PR's CI ran on its own head, not on the squashed commit. The release run on main is what built this sha.
# A newer merge cancels it, so a cancelled run means: pick a later sha whose run passed.
command -v gh >/dev/null || stop "gh is not installed, so the release run can't be checked"
run=$(gh run list --commit "$head" --workflow release.yml --limit 1 \
  --json databaseId,status,conclusion -q '.[0] // empty | "\(.databaseId) \(.status) \(.conclusion)"') ||
  stop "could not read the release run"
[[ -n "$run" ]] || stop "${sha:0:7} has no release run yet"
read -r run_id run_status run_conclusion <<<"$run"
link="https://github.com/Mike-Guan/life-hub/actions/runs/$run_id"
[[ "$run_status" == completed ]] || stop "the release run is $run_status: $link"
[[ "$run_conclusion" == success ]] || stop "the release run ended $run_conclusion: $link"

out="$HOME/LifeHub-QA/install-${sha:0:7}"
mkdir -p "$out"
printf '%s\tsha %s\trun %s\n' "$(date -u +%FT%TZ)" "$head" "$link" >>"$out/gate.txt"
echo "gate ok: ${head:0:7}, release run $link. Install the same sha on the iPhone and the watch."
