#!/usr/bin/env bash
# Run on the Mac before every install to a real iPhone or watch. It stops unless the checkout is the sha QA
# cleared and Mike's own 「装」 message for it is named. Install only when it prints "gate ok".
# Usage: scripts/install-gate.sh <sha> <Mike's 装 message id> "<QA's 放行 line>"
set -euo pipefail

if (($# != 3)); then
  echo "Usage: scripts/install-gate.sh <sha> <cmsg_ id of Mike's 装> \"<QA 放行 line>\"" >&2
  exit 1
fi
sha=$1
message=$2
qa=$3

stop() {
  echo "gate stop: $1. Do not install; tell the 工程 thread." >&2
  exit 1
}

[[ "$sha" =~ ^[0-9a-f]{7,40}$ ]] || stop "\"$sha\" is not a commit sha"
[[ "$message" =~ ^cmsg_[0-9A-Za-z]+$ ]] || stop "\"$message\" is not a message id"
[[ "$qa" == *"QA 放行 ${sha:0:7}"* ]] || stop "the QA line does not say 「QA 放行 ${sha:0:7}」"
[[ -z "$(git status --porcelain)" ]] || stop "the checkout has local changes"
head=$(git rev-parse HEAD)
[[ "$head" == "$sha"* ]] || stop "the checkout is ${head:0:7}, not ${sha:0:7}"

out="$HOME/LifeHub-QA/install-${sha:0:7}"
mkdir -p "$out"
printf '%s\tsha %s\t装 %s\t%s\n' "$(date -u +%FT%TZ)" "$head" "$message" "$qa" >>"$out/gate.txt"
echo "gate ok: ${head:0:7}, 装 $message. Raw output goes to $out/."
