# Asset Spec — UI icons: equipment-slot icons + Tool Belt relic

**Owner:** Codex (ADR-0005 — Codex generates all PNGs under `**/assets/images/**`).
**Status:** Requested.
**Companion specs:** `docs/asset-spec-currency-icons.md` (the 3 currency icons — still
pending, number-free) and a curse-card-art spec (the 5 curse illustrations — TODO,
separate, those are 512×320 card art, not icons).

## Context

Two icon gaps surfaced in the UI taste pass + the curse/tool work:

1. **Equipment-slot icons** — the 5 equip slots (head / chest / weapon / hands /
   accessory) render as **colored letter boxes** (`H` / `C` / `W` / `Hd` / `Ac`) via
   `EquipmentIcon.set_empty()` (`run_system/ui/equipment_icon.gd`). Letters read as a
   programmer placeholder. They appear in the character panel slots, the warehouse
   loadout board, and every empty equip cell — high visibility.
2. **Tool Belt relic icon** — the new `tool_belt` relic
   (`run_system/data/relics/tool_belt.json`) references
   `run_system/assets/images/relics/tool_belt.png`, which **does not exist**, so the
   relic shelf falls back to a text medallion.

## Deliverables

### A. Equipment-slot icons — 5 PNGs, **64×64**, into `battle_scene/assets/images/ui/slots/`

(Parallel to the existing `ui/attributes/*.png` attribute icons, same size/treatment.)

| File | Slot | Subject | Tint (existing slot color) |
|---|---|---|---|
| `slots/head.png` | Head | a riveted salvage helmet / visor cap | rust red |
| `slots/chest.png` | Chest | a patched plate / armored vest | steel blue |
| `slots/weapon.png` | Weapon | a salvaged revolver (Bill's sidearm silhouette) | brass yellow |
| `slots/hands.png` | Hands | a work glove / gauntlet | olive green |
| `slots/accessory.png` | Accessory | a charm / pendant (skull-badge or gear-trinket motif) | faded violet |

**Treatment:** these are **category markers**, so keep them the simplest readable
silhouette per the UI-icon rule — **one clear shape, one main color** (the slot tint
above) + the thick dark cartoon outline. No scene, no extra props, no text. They sit in
a ~44–74px square cell on a dark slot fill, so the silhouette must read at small size.

### B. Tool Belt relic icon — 1 PNG, **128×128**, `run_system/assets/images/relics/tool_belt.png`

(Matches the other relic icons — see `relics/crit_clip.png` for size/treatment.)

- Subject: a **worn leather tool belt / bandolier** with a couple of salvage tools
  tucked in (a wrench + a canister), brass buckle. Reads as "carry more tools."
- A bit more material detail than the slot icons (relics are hero items, rendered
  ~48px) but still flat-cartoon, low noise, one warm accent.

## Hard requirements (both sets)

- **PNG with alpha, transparent background**, centered subject, even padding.
- **NO text / numbers / letters / UI frame baked in.**
- Style = the locked **Offbeat Adult Sci-Fi Cartoon Wasteland**: thick dark cartoon
  outline, 2–3 value cel shading, low texture noise, one or two bright accent glows.
  Match the in-game exemplars (Cowboy Bill, the building art under
  `home/buildings_runtime/`, the existing `relics/*.png` + `ui/attributes/*.png`).
- Sizes are output contracts only (per project rules — never imply pixel art).

Use the mandatory prompt anchor from `docs/art-style-reference.md` (§Prompt Anchor),
plus: **"single game UI icon, one clear silhouette, no text, no number, no label, no
UI frame, transparent background."**

## Wiring after delivery (code side — Claude)

- **Slot icons:** in `equipment_icon.gd` `set_empty()` (and the filled-slot path),
  load `res://battle_scene/assets/images/ui/slots/<slot>.png` into the `_texture_rect`
  instead of the `SLOT_LETTERS` label (keep the letter as the missing-art fallback).
- **Tool Belt:** no code change — `tool_belt.json` already points at the path; the relic
  medallion + chip pick it up automatically once the PNG lands.

## Review gate

Deliver **one sample first** (e.g. `slots/weapon.png` + `tool_belt.png`) to
`docs/art/previews/ui_icons_<date>/` for approval before batching the rest — same
discipline as the other art (don't batch a UI-icon set unattended).
