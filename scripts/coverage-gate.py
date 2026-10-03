#!/usr/bin/env python3
"""Fail when line coverage of a package's Sources/ drops below a threshold.

Usage: scripts/coverage-gate.py <package path> <minimum percent>
Run after `swift test --enable-code-coverage` for that package.
"""
import json
import os
import subprocess
import sys


def main() -> int:
    package, minimum = sys.argv[1], float(sys.argv[2])
    path = subprocess.check_output(
        ["swift", "test", "--package-path", package, "--show-codecov-path"], text=True
    ).strip()
    with open(path) as handle:
        report = json.load(handle)

    sources = os.path.realpath(os.path.join(package, "Sources")) + os.sep
    covered = total = 0
    rows = []
    for data in report["data"]:
        for entry in data["files"]:
            name = os.path.realpath(entry["filename"])
            if not name.startswith(sources):
                continue
            lines = entry["summary"]["lines"]
            covered += lines["covered"]
            total += lines["count"]
            rows.append((lines["percent"], name[len(sources):]))

    for percent, name in sorted(rows):
        print(f"{percent:6.1f}%  {name}")
    overall = 100.0 * covered / total if total else 100.0
    print(f"Total line coverage for {package}: {overall:.1f}% (minimum {minimum:.0f}%)")
    if overall < minimum:
        print(f"::error::{package} line coverage {overall:.1f}% is below {minimum:.0f}%")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
