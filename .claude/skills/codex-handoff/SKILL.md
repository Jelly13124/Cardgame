---
name: codex-handoff
description: Draft the two-file art contract that hands a content wave to Codex per ADR-0005 — docs/asset-spec-<slice>.md (the authoritative per-PNG work order) and docs/codex-prompt-<slice>.md (the copy-paste briefing). Use after shipping a batch of cards/enemies/relics/equipment whose art is still placeholder, when you need Codex to generate the real PNGs. Invoke as /codex-handoff <slice-name>.
disable-model-invocation: true
---

# Handing art off to Codex

Per **ADR-0005**, Claude owns code/JSON/docs and Codex owns every PNG under
`battle_scene/assets/images/**` and `run_system/assets/images/**`. The hand-off is
a **contract doc** Claude writes; Codex reads it and produces the assets. Writing
this contract (including theme direction and neon accent per item) is Claude's job —
generating the pixels is not.

Produce TWO files for the slice. Match the structure of the existing pair
`docs/asset-spec-content-expansion.md` + `docs/codex-prompt-content-expansion.md`
(read them as the canonical template before writing).

## Step 1 — Find what actually needs art

Don't guess which items are still on placeholders. The catalog generator marks
on-disk art presence:

```bash
PYTHONIOENCODING=utf-8 python scripts/gen_catalogs.py all
```

Every row with **❌** in the Art/Icon column is a missing PNG → it belongs in this
hand-off. Cross-check the item's JSON `front_image` / `sprite` / `icon` / `sprite_id`
to get the exact output path Codex must hit. (A ✅ row already has art — do NOT ask
Codex to regenerate it unless the user explicitly wants a redo.)

## Step 2 — Write `docs/asset-spec-<slice>.md` (the work order)

Sections, in order:

0. **Style Preamble (Non-Negotiable)** — paste the mandatory anchor VERBATIM (see
   below). Then the palette guidance + reference image path
   `docs/art/hardcore-128-pixel-wasteland-reference.png`.
1. **Pipeline Reminders** — the frame-size/path table (below) + the standing rules
   (magenta `#FF00FF` chroma key → transparent PNG; icons are item-only; card art is
   composition-only; enemies face LEFT, heroes face RIGHT; exact output paths;
   don't write `.import`; drop `pipeline-meta.json` + `prompt-used.txt` in
   `generated_sheet/`).
2..N. **One section per category** present in this slice (Cards / Enemies /
   Equipment / Relics). Each item gets a row: `id | title | effect summary | theme |
   neon accent | output path`. The **theme** (1 sentence of visual direction) and the
   **single neon accent color** are yours to author per item. Pull the effect summary
   from the catalog so the art matches the mechanic. Group set items (e.g. an
   equipment set) and add a cohesion checklist.
last-2. **Delivery order** — highest-visibility first (cards → enemies → equipment → relics).
last-1. **What NOT to do** — no editing `.gd`/`.tscn`/`.json`; no inventing/renaming ids;
   no UI frames/badges/text baked in; no frame-size changes; no committing `.import`
   or API keys / secrets (read any external-service credentials from an env var, never commit them).
last. **Acceptance** — exact path exists, correct dims, transparent bg (no magenta
   leftover), silhouette reads at in-game scale, one neon accent only, set cohesion.

### Mandatory style anchor (paste verbatim)

```
hardcore wasteland sprite art, detailed fully-rendered game sprite, bold dark outlines,
rich controlled shading with clear highlight-mid-shadow, warm rust / leather / brass / dark-steel / dusty-tan palette,
salvaged scrap metal with bolts dents tubes and cracked glass, worn leather and patched cloth,
one small glowing neon accent, authored at 128px native (192px bosses) for in-game readability,
transparent background, match the Cowboy Bill reference fidelity, not lo-fi pixel art, not flat
```

For combat-unit sheets also append:
```
side view, full body, shared baseline, consistent scale, hero faces right or enemy faces left,
4 attack frames, attack frame 0 doubles as the static rest pose, no separate idle animation
```

**Ground truth (always include):** point Codex at Cowboy Bill (`battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_portrait.png`) as the fidelity reference — a detailed, fully-rendered sprite, NOT lo-fi pixel art. When wording conflicts with how Bill looks, Bill wins. (See ADR-0011 / `art-style-reference.md`.)

### Frame-size / output-path table

| Asset type | Frame size | Frames | Output path |
|---|---|---|---|
| Card art       | 512×320 | 1 | `battle_scene/assets/images/cards/player/{card_id}.png` |
| Equipment icon | 128×128 | 1 | `battle_scene/assets/images/equipment/{item_id}.png` |
| Relic icon     | 128×128 | 1 | `run_system/assets/images/relics/{relic_id}.png` |
| Regular enemy  | 128×128 | 4 | `battle_scene/assets/images/enemies/{sprite_id}/attack/{sprite_id}_attack_{0..3}.png` |
| Boss enemy     | 192×192 | 4 | `battle_scene/assets/images/enemies/{sprite_id}/attack/{sprite_id}_attack_{0..3}.png` |

(Boss vs regular: bosses are the ids in `BOSS_BY_FLOOR`; the catalog generator's
enemy Tier column tells you which.)

## Step 3 — Write `docs/codex-prompt-<slice>.md` (the briefing)

This is the copy-paste-into-Codex file. Structure (mirror the existing one):
- One line: "Copy everything below the `---` into your codex session."
- Step 1: files to read first (the asset spec above, `art-style-reference.md`,
  `project-rules.md` §1–§5, `adr/0008-...`, `catalog-all.md`) + one reference PNG per
  asset type so output matches existing visual weight.
- Step 2: deliverables (counts + path patterns, which enemies are 192 vs 128).
- Step 3: the non-negotiable pipeline rules (same as spec §1).
- Step 4: one-item-at-a-time loop (compose prompt = theme + accent + anchor → generate
  on magenta → chroma-key → verify silhouette at in-game scale → save to exact path).
- Step 5: set/batch coherence checks.
- Step 6: delivery order + ship small batches (one commit/push per category).
- Step 7: "Don't touch" list (ADR-0005 boundary).
- Step 8: commit message format.

## Guardrails

- Match every `id` and output path EXACTLY to the JSON — a wrong path means Codex's
  PNG never replaces the placeholder.
- One neon accent per item; name a specific color, not "neon".
- Do not generate, edit, or describe the pixels yourself, and do not run any art
  pipeline — you're writing the contract, not filling it. This is a docs-only task;
  no `.gd`/`.json`/`.tscn` edits, so no smoke test needed.
- If a detail is genuinely ambiguous (e.g. which existing sprite a new enemy
  temporarily borrows), the spec should say "if ambiguous, stop and ask the human" —
  Codex asks the human, not Claude.
