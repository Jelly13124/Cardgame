# Overnight Report — Base/Shop/Forge UI + Tool-System Overhaul (2026-06-25)

**Branch:** `overnight-0615` · **Spec:** `docs/superpowers/specs/2026-06-25-base-shop-forge-tools-overhaul.md`
**Mode:** `/goal` autonomous. Smoke-gated + **off-screen MCP screenshot verified** each phase.
**Not pushed** (per the autonomous-run workflow — mixed/local commits stay local).

## What the owner asked for (9 items → 7 commits)

1. 黑市 equipment on a **shelf** (icon + rarity border + price), not a text list; card-unlock shows **real cards**.
2. Building **tier-upgrade moved to the overview** (button by the floating label → confirm popup); drop the detail-page action card.
3. Warehouse **hero portrait** picker + **empty stash slot frames**.
4. Forge **bench**: stash + a drop slot; drag an item in → list its affixes → **Dismantle** or **Reforge a chosen affix**.
5. Tool rework: **1 base slot**, extra tools **held in the backpack**, an **equip system**, and a **+1 tool slot relic**.
6. (mid-run) **All base detail pages fullscreen** — a 40-slot stash can't live in a small centered card.

## Commits

| Commit | Phase | What |
|---|---|---|
| `965b404` | spec | overnight spec |
| `33d26f0` | P1 | unlock/upgrade → overview button + confirm popup; detail pages services-only |
| `ff902e9` | P2 | market equipment shelf tiles + real card art (unlock + card-shop) |
| `3314b3e` | P3 | warehouse hero-portrait picker + empty stash slot frames |
| `e173d8b` | P4 | forge bench redesign + **per-affix reforge** (`affix_pool.reroll_at`, `reforge_stash_item_affix`) |
| `6cfc32f` | P5 | tool rework: 1 base slot + backpack-held + equip system + **Tool Belt** relic |
| `4dfd86c` | P7 | building detail pages **fullscreen**; warehouse 8-col **40-slot** grid |
| `5353f49` | P6 | catalog (Tool Belt) + PRD/PROJECT_STRUCTURE + confirm-popup guard |

## Verification

- **Per-phase off-screen MCP screenshots** (background mode, no visible window): overview three-state
  buttons + confirm dialog; market shelf + real-card grids; warehouse portrait + 40-slot grid; forge
  bench with affix rows + reforge buttons; equipment-panel tool slots + backpack tool cells; all five
  buildings fullscreen (warehouse / market / forge / clinic verified, outpost shares the shell).
- **Forge per-affix reforge logic test**: reforging affix 0 rerolled `attr_strength → attr_luck`, left
  the other affix untouched, spent 50 scrap (600 → 550).
- **Tool backend logic test**: equip/unequip move a tool between a backpack cell and a slot; the Tool
  Belt relic adds exactly +1 slot (2 → 3 with the Outpost Tool Rack also active).
- **gdscript-reviewer**: clean across all 10 changed `.gd` files (lambda capture, Variant inference,
  falsy-zero, signal arity, validator contract, JSON wiring all checked).
- **Smoke gate**: `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`

## New content

- Relic **`tool_belt`** (工具腰带, uncommon, +1 tool slot) — `tool_slots` passive relic effect (added to
  `ALLOWED_RELIC_EFFECT_TYPES`); auto-enters the reward + shop pools. In the browsable catalog.

## Follow-ups / handoff to Codex (ADR-0005 — art is Codex's)

- `tool_belt` relic has **no icon yet** (`run_system/assets/images/relics/tool_belt.png`). The UI falls
  back to a text medallion cleanly; Codex should deliver the PNG.
- The three currency icons (core/caps/scrap) are still **text placeholders** in `home_base_scene` (from
  the prior session) — Codex regen pending; restore the `TextureRect` once the clean icons land.

## Test save (slot_1)

Left generous for base testing: every building **T2** (room to buy T3), **Core 500 / Caps 3000 / Scrap
800**, 12 stash items.

## Session hygiene

McpBridge stripped from `project.godot`; `mcp_bridge.gd`/`.uid` removed.
