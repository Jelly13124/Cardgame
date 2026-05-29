"""
i18n audit (read-only). Reports translation gaps so the overnight run and the
morning review can see what's done:

  1. CSV rows whose `zh` cell is empty or identical to `en` (likely untranslated).
     Identical is allowed for a short allowlist of intentionally-same strings
     (proper names / language labels) — those are reported separately as "same".
  2. UI .gd files (battle_scene/ + run_system/, excluding addons/) that still
     contain a user-facing `.text = "<has ASCII letters>"` not wrapped in a
     translation call (tr(/Settings.t(/TranslationServer.translate().

Exit code is always 0 — this reports, it does not gate.

Usage: python scripts/i18n_audit.py
"""

from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRANS_DIR = ROOT / "assets" / "translations"
CODE_DIRS = [ROOT / "battle_scene", ROOT / "run_system"]

# Strings that are intentionally identical across en/zh (don't flag as missing).
SAME_OK = {"English", "中文"}

# A .text assignment whose value contains at least one ASCII letter.
TEXT_ASSIGN = re.compile(r'\.text\s*=\s*"([^"]*[A-Za-z][^"]*)"')
WRAPPED = ("tr(", "Settings.t(", "TranslationServer.translate(")


def audit_csvs() -> tuple[int, int]:
    missing = 0
    same = 0
    print("== CSV translation gaps ==")
    for csv_path in sorted(TRANS_DIR.glob("*.csv")):
        rows_missing: list[str] = []
        rows_same: list[str] = []
        with csv_path.open(encoding="utf-8", newline="") as f:
            reader = csv.reader(f)
            header = next(reader, None)
            if not header or len(header) < 3:
                continue
            for row in reader:
                if len(row) < 3 or not row[0].strip():
                    continue
                key, en, zh = row[0], row[1], row[2]
                if zh.strip() == "":
                    rows_missing.append(key)
                elif zh.strip() == en.strip() and en.strip() not in SAME_OK:
                    rows_same.append(key)
        if rows_missing:
            missing += len(rows_missing)
            print(f"  [{csv_path.name}] {len(rows_missing)} empty zh: {', '.join(rows_missing[:8])}"
                  + (" …" if len(rows_missing) > 8 else ""))
        if rows_same:
            same += len(rows_same)
            print(f"  [{csv_path.name}] {len(rows_same)} zh==en (review): "
                  + ", ".join(rows_same[:8]) + (" …" if len(rows_same) > 8 else ""))
    print(f"  TOTAL empty-zh: {missing}; zh==en: {same}")
    return missing, same


def audit_hardcoded() -> int:
    hits = 0
    print("== Hardcoded UI strings still in .gd (not wrapped in a translation call) ==")
    for base in CODE_DIRS:
        for gd in base.rglob("*.gd"):
            if "addons" in gd.parts:
                continue
            for i, line in enumerate(gd.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                s = line.strip()
                if s.startswith("#"):
                    continue
                m = TEXT_ASSIGN.search(line)
                if not m:
                    continue
                if any(w in line for w in WRAPPED):
                    continue
                hits += 1
                rel = gd.relative_to(ROOT).as_posix()
                print(f"  {rel}:{i}: {m.group(1)[:48]}")
    print(f"  TOTAL hardcoded UI .text: {hits}")
    return hits


def main() -> int:
    miss, same = audit_csvs()
    print()
    hard = audit_hardcoded()
    print()
    print(f"SUMMARY: empty-zh={miss}  zh==en(review)={same}  hardcoded-ui={hard}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
