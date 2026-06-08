# StS2 Ironclad Port + Home-Base Layout — Design

**Date:** 2026-06-08
**Status:** Approved (overnight unattended run)

## Goal

Two independent workstreams approved for an overnight run:

1. **Home-base layout** — re-arrange the home base entry screen to "2 buildings
   left / 2 right / START door centre, Warehouse icon directly above the door".
2. **Content enrichment** — scan the full Slay the Spire 2 Ironclad card pool
   (87 cards) and full relic pool, audit which fit our engine + attribute system,
   re-skin the survivors to our cyber/scrap/yin-yang setting, and wire them into
   the correct per-hero card pools.

No push. Codex art WIP stays out of our commits. Smoke-gate every phase.

## Non-negotiable project rules in play

- `class_name` banned → `preload` + `extends` (ADR-0006).
- Two-place rule: every new effect/status/relic/action type registers in BOTH the
  handler (`combat_engine` / `status_effect_system` / `relic_effect_system`) AND
  the matching `ALLOWED_*` list in `battle_scene/data_validator.gd`.
- New cards need pool wiring (INITIAL_CARD_POOL or HERO_EXCLUSIVE_CARDS); relics
  need a drop-pool entry. JSON alone does not appear in-game.
- Smoke gate: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
  must tail `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`
- Regenerate `python scripts/gen_catalog_html.py` after content changes.
- Codex owns PNGs — new cards ship with a `front_image` path + an `asset-spec`
  contract; art does not block the run (warn-only fallback).

## Current architecture (verified)

- **Cards** live in `battle_scene/card_info/player/*.json`. Schema:
  `name,title,rarity,type,cost,polarity,description,front_image,side,effects[],matched_bonus[]`.
  Each card has a `_plus` upgraded twin.
- **Attribute → card scaling** (`combat_engine._apply_effect`):
  - `strength` auto-adds to every `deal_damage` / `deal_damage_all`.
  - `constitution` auto-adds to every `gain_block`.
  - `deal_damage_str_mult` = STR × mult (no double-STR).
  - `scale_damage_by_attacks` = base + per × attacks-played-this-turn.
  - `intelligence/luck/charm` are growable attributes but have no hard-wired card
    scaling today (luck/crit flow through relics + affixes).
- **Card pools** (`meta_progress.gd`):
  - `INITIAL_CARD_POOL` = always-available colourless/base pool.
  - `HERO_EXCLUSIVE_CARDS[hero_id]` = only offered when that hero is active
    (today only `hero_fengshui_master`).
  - `get_unlocked_card_pool()` = union(INITIAL, unlocked_cards, active hero exclusives).
- **Effect whitelist** (`data_validator.gd`): see ALLOWED_EFFECT_TYPES,
  ALLOWED_STATUS_NAMES, ALLOWED_RELIC_EFFECT_TYPES.

## Phase 0 — Home-base layout

Modify `run_system/ui/home_base_scene.gd` so the 5 buildings render as:

```
        [ Warehouse ]
[Forge ]            [Market ]
[Clinic]   ( DOOR ) [Outpost]
            START
```

- Two flank columns (left: Forge, Clinic; right: Market, Outpost).
- Centre column: Warehouse tile on top, START door below it.
- Keep existing accent colours, click→`_open_building_screen(id)`, Core/Caps/Scrap
  top bar, and the direct-launch START behaviour (pending hero/asc).
- Pure layout change — no new building logic.

## Phase 1 — Scan + audit (document only, no cards yet)

WebFetch the full Ironclad card list and full relic list (untapped.gg / stratgg /
wiki.gg). Produce `docs/sts2-port-audit.md`: one row per card and per relic, each
tagged:

- **PORT-AS-IS** — expressible with the existing effect/status/relic whitelist
  (damage, block, draw, energy, apply status, exhaust_self, STR/CON scaling).
- **PORT-NEW-MECH** — Ironclad signature that needs a new engine mechanic. The
  whole run may add **at most 4–6** new effect/status types total. List the
  candidate mechanics ranked; anything beyond the budget downgrades to SKIP.
- **SKIP** — depends on systems we lack (potions, specific events, energy relics)
  or duplicates an existing card.

Each PORT row records: original name, our re-skinned `name`/`title`, cost, rarity,
target pool (bill / fengshui / colourless), effects mapping, attribute lean.

## Phase 2 — Attribute mapping + re-skin rules

- StS **Strength → strength** (auto +STR damage; strength-scaling cards map directly).
- StS **Dexterity / block archetype → constitution** (auto +CON block).
- High-variance / crit / chance → **luck** (crit system).
- Spell/tech/utility → **intelligence**.
- Buff/economy/social → **charm**.
- Re-skin names + flavour to cyber/scrap/yin-yang (e.g. Demon Form → "Overdrive
  Core", Bludgeon → "Scrap Maul"). English `title`, Chinese in CSV. Numbers may be
  retuned to our power curve — this is a reconstruction, not a copy.

## Phase 3 — Card wiring

- Write each survivor as a base JSON + `_plus` twin in `battle_scene/card_info/player/`.
- Assign pool by re-skinned theme:
  - Strength / block / exhaust bruiser → **Bill exclusive** (new `"cowboy_bill"`
    key in HERO_EXCLUSIVE_CARDS).
  - Flip / balance / dual-nature → **Feng Shui Master** (append to existing list).
  - Pure neutral utility (no attribute lean) → **colourless** INITIAL_CARD_POOL.
- Register any new effect/status type in handler + validator (two-place rule).
- `front_image` points at a not-yet-existing PNG (warn-only fallback); write
  `docs/asset-spec-sts2-cards.md` for Codex.
- Add CSV translation rows (en + zh) for every new card title/description.

## Phase 4 — Relic wiring

- Re-skin + reconstruct the audit's PORT relics into `run_system/data/relics/*.json`.
- Map effects to ALLOWED_RELIC_EFFECT_TYPES; add new relic trigger types only
  within the same 4–6 mechanic budget.
- Add to the correct rarity drop pool (common/uncommon/rare); never `unique`
  unless hero-starting.
- CSV rows + asset-spec for icons.

## Verification (every phase)

1. `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh` → green.
2. CSV reimport: `"C:/Program Files/Godot/Godot.exe" --headless --path . --import`.
3. `python scripts/gen_catalog_html.py` → refresh catalogs.
4. Commit per phase with a clear message. **Do not push.** Stage only our files —
   never Codex art WIP / `*.import` / `*.uid` / `*.translation` sidecars.

## Out of scope / deferred

- A standalone third "Warrior" hero (rejected — cards distribute into existing pools).
- Boss-exclusive / event-exclusive StS relics that need systems we lack.
- Final card/relic art (Codex follow-up via asset-spec).
