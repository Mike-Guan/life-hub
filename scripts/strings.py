#!/usr/bin/env python3
"""Checks the packages' String Catalogs against their source (Issue #350).

Chinese is the source language, so a key is the Chinese text itself. Each package has one table per
character (Haku.xcstrings, Kuro.xcstrings) and Localizable.xcstrings for everything else. Translations
come from the writers; this script fails when a catalog holds a key that no longer appears as a string
literal in that package's source, so a reworded line can't keep a stale translation. It also fails when a
translation in any catalog has different placeholders from its key, since `String(format:)` would read the
wrong arguments.

    scripts/strings.py   exit 1 and name each stale key
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PACKAGES = ["HubCore", "CompanionKit"]
TABLES = ["Localizable", "Haku", "Kuro", "Short"]
# A one-line string literal with no interpolation.
LITERAL = re.compile(r'"((?:[^"\\\n]|\\[^(])*)"')
# A format placeholder such as %@, %1$@ or %lld; %% is a literal percent sign.
PLACEHOLDER = re.compile(r"%(?:(\d+)\$)?(@|lld|ld|d)")


def placeholders(text: str) -> list[str]:
    """The placeholder types in argument order, whether numbered or not."""
    found = PLACEHOLDER.findall(text.replace("%%", ""))
    if all(number for number, _ in found):
        found.sort(key=lambda match: int(match[0]))
    return [kind for _, kind in found]


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
            if not path.exists():
                continue
            catalog = json.loads(path.read_text(encoding="utf-8"))
            if catalog.get("sourceLanguage") != "zh-Hans":
                stale.append(f"{path.relative_to(ROOT)}: sourceLanguage must be zh-Hans")
            for key in catalog.get("strings", {}):
                if key not in known:
                    stale.append(f"{path.relative_to(ROOT)}: no source text {key!r}")
    for path in sorted(ROOT.glob("*/**/*.xcstrings")):
        catalog = json.loads(path.read_text(encoding="utf-8"))
        for key, entry in catalog.get("strings", {}).items():
            for language, localization in entry.get("localizations", {}).items():
                plural = localization.get("variations", {}).get("plural", {})
                # A plural's "one" form may spell the number out, so only "other" must keep every placeholder.
                unit = plural["other"] if plural else localization
                value = unit.get("stringUnit", {}).get("value", "")
                if placeholders(value) != placeholders(key):
                    stale.append(f"{path.relative_to(ROOT)}: {language} for {key!r} has other placeholders")
    for line in stale:
        print(f"::error::{line}")
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main())
