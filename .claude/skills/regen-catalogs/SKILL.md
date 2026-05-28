---
name: regen-catalogs
description: Refresh the derivable sections of docs/catalog-{cards,enemies,relics}.md (and optionally equipment) from the JSON content so the catalogs stop drifting from reality. Use after adding/editing cards, enemies, relics, or equipment, or whenever a catalog's "Last updated" date or counts look stale. Invoke as /regen-catalogs [cards|enemies|relics|equipment|all].
disable-model-invocation: true
---

# Regenerating content catalogs

The `docs/catalog-*.md` files mix two kinds of content:

1. **Derivable facts** — total counts, rarity/type breakdowns, the summary table, and on-disk art presence. These go stale the moment `/new-content` runs and are tedious/error-prone to update by hand across 167+ JSON files.
2. **Hand-authored prose** — per-item flavor and design notes ("Anti-mortar / anti-boss tool", "Tactical Toolkit — Control", encounter-pool layouts). These are NOT in the JSON and must be preserved.

This skill regenerates (1) deterministically and leaves (2) intact. The generator is **read-only** — it prints to stdout and never writes — so you do the merge with judgment.

## Steps

1. **Run the generator** for the requested target (default `all`):
   ```bash
   PYTHONIOENCODING=utf-8 python scripts/gen_catalogs.py all
   ```
   Targets: `cards`, `enemies`, `relics`, `equipment`, `all`. It scans the JSON dirs and checks the real PNG paths on disk for the Art/Icon column.

2. **Merge the fresh blocks into the catalog files** (`docs/catalog-cards.md`, `docs/catalog-enemies.md`, `docs/catalog-relics.md`). For each catalog, replace ONLY these sections with the generator output:
   - the header `**Last updated:**` line (set to today) and the `**Total …:**` line
   - `## Quick stats`
   - `## Summary table`

   Leave every other section as-is — `## Paths`, `## Per-… details`, `## Encounter pools`, `## Supported … types`, checklists. Do not delete prose for an item just because it isn't in the generated table; only the table rows are machine-owned.

3. **Reconcile prose with the new reality.** For each NEW item the generator lists that has no `## Per-… details` entry yet, add a short prose stub (one line is fine). For each item the generator NO LONGER lists (deleted JSON), remove its stale prose entry.

4. **Act on the generator's warnings:**
   - Enemy **`UNLISTED`** tier = the JSON exists but is in no encounter pool / roster / boss table in `run_manager.gd`, so it will never spawn. Flag this to the user — it's almost always a wiring bug (the [[new-content]] skill's enemy wiring step was skipped).
   - Art/Icon **❌** = the JSON points at a PNG path that doesn't exist on disk (placeholder not yet replaced). Note it; don't "fix" art — Codex owns PNGs per ADR-0005.
   - Tier is a regex best-effort read of `run_manager.gd`; if a tier looks wrong, verify against the source before trusting it.

5. **Equipment** has no hand-authored catalog today. If asked for `equipment`, offer to create `docs/catalog-equipment.md` from the generated block (it's fully derivable — no prose to preserve).

6. **Do NOT run the smoke test or touch any `.gd`/`.json`** — this is a docs-only refresh. Just save the catalog markdown.

## Why a script instead of counting by hand

There are 30+ cards, 13 enemies, 10 relics, 21 equipment items, and that grows every content wave. Eyeballing counts across that many files is exactly how the catalogs drifted (e.g. cards said "17" when there were 30). The script is the source of truth for the numbers; you own the prose and the wiring callouts.
