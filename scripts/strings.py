#!/usr/bin/env python3
"""Checks the packages' String Catalogs against their source (Issue #350).

Chinese is the source language, so a key is the Chinese text itself. Each package has one table per
character (Haku.xcstrings, Kuro.xcstrings) and Localizable.xcstrings for everything else. Translations
come from the writers; this script fails when a catalog holds a key that no longer appears as a string
literal in that package's source, so a reworded line can't keep a stale translation.

    scripts/strings.py   exit 1 and name each stale key
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PACKAGES = ["HubCore", "CompanionKit"]
TABLES = ["Localizable", "Haku", "Kuro"]
# A one-line string literal with no interpolation.
LITERAL = re.compile(r'"((?:[^"\\\n]|\\[^(])*)"')


def literals(sources: pathlib.Path) -> set[str]:
    found = set()
    for path in sources.rglob("*.swift"):
        for match in LITERAL.finditer(path.read_text(encoding="utf-8")):
            found.add(match.group(1).replace('\\"', '"').replace("\\\\", "\\"))
    return found


def main() -> int:
    stale = []
    for package in PACKAGES:
        sources = ROOT / "Packages" / package / "Sources" / package
        known = literals(sources)
        for table in TABLES:
            path = sources / "Resources" / f"{table}.xcstrings"
            catalog = json.loads(path.read_text(encoding="utf-8"))
            if catalog.get("sourceLanguage") != "zh-Hans":
                stale.append(f"{path.relative_to(ROOT)}: sourceLanguage must be zh-Hans")
            for key in catalog.get("strings", {}):
                if key not in known:
                    stale.append(f"{path.relative_to(ROOT)}: no source text {key!r}")
    for line in stale:
        print(f"::error::{line}")
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main())
