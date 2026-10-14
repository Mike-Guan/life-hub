#!/usr/bin/env python3
"""Keeps each package's Localizable.xcstrings in step with the Chinese text in its source.

Issue #350. Chinese is the source language, so a key is the Chinese text itself. A Swift file that uses
`.localized` is moved over: every Chinese string literal in it, outside comments and without
interpolation, is a key. New keys are added with no translation; keys no longer in the source are
dropped; translations already there are kept.

    scripts/strings.py          rewrite the catalogs
    scripts/strings.py --check  exit 1 if a catalog is out of date
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PACKAGES = ["HubCore", "CompanionKit"]
# A one-line string literal with no interpolation, and a Chinese or Japanese character in it.
LITERAL = re.compile(r'"((?:[^"\\\n]|\\[^(])*)"')
CJK = re.compile(r"[\u3040-\u30ff\u4e00-\u9fff]")


def keys(sources: pathlib.Path) -> set[str]:
    found = set()
    for path in sources.rglob("*.swift"):
        text = path.read_text(encoding="utf-8")
        if ".localized" not in text:
            continue
        for line in text.splitlines():
            code = line.split("//")[0] if not line.lstrip().startswith("//") else ""
            for match in LITERAL.finditer(code):
                key = match.group(1).replace('\\"', '"').replace("\\\\", "\\")
                if CJK.search(key):
                    found.add(key)
    return found


def render(catalog: dict) -> str:
    return json.dumps(catalog, ensure_ascii=False, indent=2, separators=(",", " : "), sort_keys=True) + "\n"


def main() -> int:
    check = "--check" in sys.argv
    stale = []
    for package in PACKAGES:
        sources = ROOT / "Packages" / package / "Sources" / package
        path = sources / "Resources" / "Localizable.xcstrings"
        catalog = json.loads(path.read_text(encoding="utf-8"))
        old = catalog.get("strings", {})
        catalog["strings"] = {key: old.get(key, {"extractionState": "manual"}) for key in sorted(keys(sources))}
        text = render(catalog)
        if path.read_text(encoding="utf-8") != text:
            stale.append(path.relative_to(ROOT))
            if not check:
                path.write_text(text, encoding="utf-8")
    if check and stale:
        for path in stale:
            print(f"::error::{path} is out of date. Run 'make strings' and commit the result.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
