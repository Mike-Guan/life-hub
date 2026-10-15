#!/usr/bin/env python3
"""Adds a writers' delivery to the String Catalogs (Issue #350).

A delivery has a header line and one row per entry. Columns are split by tabs (.tsv) or `|` (.txt):
`table | key | translation | note [| source]`. The key is the Chinese source text; the table is Haku, Kuro
or Localizable. Rows replace any earlier translation of the same key in that language. Notes become the
entry's comment for the next writer.

`source` names the Swift files that use the line (`HakuLines.swift:69, CompanionLines.swift:28`). Each row
goes to the catalog of every target holding one of those files: a package's own table, or an app's
Localizable. Without a source column, rows go to `default-package`. A row is written to a catalog only
when its key is a string literal in that target's sources, so nothing stale lands (scripts/strings.py).

    scripts/import-strings.py <delivery> <language> [default-package]   (default HubCore)
"""
import collections
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TABLES = {"Haku", "Kuro", "Localizable"}
# Source folder -> folder holding its catalogs. Apps/Shared builds into the iOS app.
APPS = {
    "Apps/Shared": "Apps/iOS",
    "Apps/iOS": "Apps/iOS",
    "Apps/Widgets": "Apps/Widgets",
    "Apps/Notification": "Apps/Notification",
    "Apps/Watch": "Apps/Watch",
    "Apps/WatchWidgets": "Apps/WatchWidgets",
}
LITERAL = re.compile(r'"((?:[^"\\\n]|\\[^(])*)"')


def render(catalog: dict) -> str:
    return json.dumps(catalog, ensure_ascii=False, indent=2, separators=(",", " : "), sort_keys=True) + "\n"


def target_of(path: pathlib.Path) -> str | None:
    """The folder holding the catalogs for a Swift file, or None outside the shipped targets."""
    rel = path.relative_to(ROOT).as_posix()
    if "/Tests/" in rel:
        return None
    match = re.match(r"Packages/([^/]+)/Sources/\1/", rel)
    if match:
        return f"Packages/{match.group(1)}/Sources/{match.group(1)}/Resources"
    for sources, catalogs in APPS.items():
        if rel.startswith(sources + "/"):
            return catalogs
    return None


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    delivery, language = pathlib.Path(sys.argv[1]), sys.argv[2]
    default = sys.argv[3] if len(sys.argv) > 3 else "HubCore"
    sep = "\t" if delivery.suffix == ".tsv" else "|"

    files = collections.defaultdict(set)
    literals = collections.defaultdict(set)
    for path in sorted(ROOT.glob("*/**/*.swift")):
        target = target_of(path)
        if target is None:
            continue
        files[path.name].add(target)
        for match in LITERAL.finditer(path.read_text(encoding="utf-8")):
            literals[target].add(match.group(1).replace('\\"', '"').replace("\\\\", "\\"))

    catalogs: dict[pathlib.Path, dict] = {}
    written, skipped = collections.Counter(), []
    rows = delivery.read_text(encoding="utf-8").splitlines()[1:]
    for number, row in enumerate(rows, start=2):
        if not row.strip():
            continue
        cells = [cell.strip() for cell in row.split(sep, 4)]
        if cells[0] == "InfoPlist":
            # Usage descriptions go into InfoPlist.xcstrings by hand, next to project.yml.
            skipped.append(f"InfoPlist | {cells[1] if len(cells) > 1 else ''}")
            continue
        if len(cells) < 3 or cells[0] not in TABLES or not cells[1] or not cells[2]:
            print(f"{delivery.name}:{number}: expected 'table | key | translation | note', got {row!r}")
            return 1
        table, key, value = cells[:3]
        note = cells[3] if len(cells) > 3 else ""
        if len(cells) > 4:
            names = {part.strip().split(":")[0] for part in cells[4].split(",")}
            targets = {target for name in names for target in files.get(name, set())}
        else:
            targets = {f"Packages/{default}/Sources/{default}/Resources"}
        landed = False
        for folder in sorted(targets):
            if key not in literals[folder]:
                continue
            # Apps read one table; the character tables live only in the packages.
            name = table if folder.startswith("Packages/") else "Localizable"
            path = ROOT / folder / f"{name}.xcstrings"
            if path not in catalogs:
                if not path.exists():
                    continue
                catalogs[path] = json.loads(path.read_text(encoding="utf-8"))
            entry = catalogs[path].setdefault("strings", {}).setdefault(key, {})
            entry.setdefault("localizations", {})[language] = {"stringUnit": {"state": "translated", "value": value}}
            if note:
                entry["comment"] = note
            written[path.relative_to(ROOT).as_posix()] += 1
            landed = True
        if not landed:
            skipped.append(f"{table} | {key}")
    for path, catalog in catalogs.items():
        path.write_text(render(catalog), encoding="utf-8")
    for path, count in sorted(written.items()):
        print(f"{count:5} {path}")
    print(f"{len(skipped):5} rows with no matching literal in code (new text, or code still interpolates)")
    for line in skipped:
        print(f"      {line}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
