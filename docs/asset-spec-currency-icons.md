# Asset Spec — Home-base currency icons (number-free)

**Owner:** Codex (ADR-0005 — Codex generates all PNGs under `run_system/assets/images/**`).
**Status:** Requested. The current icons are broken (see below); the home-base
HUD renders **number-only chips** until clean art lands.

## Problem

The shipped currency icons baked a **placeholder number into the art**:
- `run_system/assets/images/home/currency/caps.png` — a "1" stamped top-right.
- `run_system/assets/images/home/currency/scrap.png` — "232" stamped across it.
- `run_system/assets/images/home/currency/core.png` — verify; if it carries a
  baked number, regenerate too.

Beside the live value the chip already shows, the baked number reads as a
duplicated/garbled number (the user's "数字重复/和图标里的数字叠在一起" bug).

`home_base_scene.gd` `_make_currency_chip()` now renders number-only chips and no
longer loads these PNGs. Once clean (number-free) icons are delivered, re-enable
the icon (re-add a `TextureRect` loading `home/currency/{id}.png` to the chip).

## Deliverables (3 PNGs, overwrite in place)

| File | Currency | Subject |
|---|---|---|
| `run_system/assets/images/home/currency/core.png` | Core (meta) | a glowing cyan power-core / energy crystal shard |
| `run_system/assets/images/home/currency/caps.png` | Caps | a single dented bottle-cap (the wasteland "money") |
| `run_system/assets/images/home/currency/scrap.png` | Scrap | a small bolt-and-gear / scrap-metal nugget cluster |

### Hard requirements
- **NO text, NO numbers, NO letters baked in.** Pure icon only. (This is the whole point.)
- **Transparent background** (PNG with alpha), centered subject, even padding.
- **Square**, delivered at **128×128** (rendered ~54px in-game; size is an output
  contract only, per project rules).
- Style = the locked **Offbeat Adult Sci-Fi Cartoon Wasteland**: thick dark
  cartoon outline, 2–3 value cel shading, low texture noise, one or two bright
  accent glows. Match the existing in-game exemplars (Cowboy Bill, the building
  art under `home/buildings_runtime/`).
- Per-currency accent: core = cyan glow, caps = warm red/orange, scrap = warm
  grey-green metal. Readable as a small icon against a dark chip.

Use the mandatory prompt anchor from `docs/PRD.md` (Art Style section), with the
addition: **"single icon, no text, no number, no label, no UI frame."**

## Wiring after delivery
Re-add the icon to `home_base_scene.gd` `_make_currency_chip()` (a `TextureRect`
54×54 loading `res://run_system/assets/images/home/currency/{id}.png` before the
number label) and restore the `icon_id` parameter usage. The number-only fallback
can stay as the missing-art path.
