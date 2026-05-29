---
name: new-content
description: Scaffold a new card, enemy, relic, hero, or base-upgrade JSON for this Godot roguelite with the schema-correct shape AND the exact wiring steps so it actually shows up in-game. Use whenever adding game content — it prevents the recurring "JSON created but never wired into the draft pool / encounter table / art path" class of bug. Invoke as /new-content <type> <id> (e.g. /new-content card siphon).
---

# Adding game content

This project is data-driven: gameplay content is JSON validated at boot by `battle_scene/data_validator.gd`. Creating the JSON is only half the job — each content type has a **wiring step** that, if skipped, means the content exists but never appears in-game. Three review findings have been exactly this (JSON pointing at placeholder art; card not in draft pool).

Pick the section for the requested `<type>`. Write the JSON to the exact path, then DO every wiring step, then run `bash scripts/smoke_test.sh`.

## card → `battle_scene/card_info/player/<id>.json`

```json
{
  "name": "<id>",
  "title": "Display Name",
  "rarity": "common|uncommon|rare",
  "type": "attack|skill|ability",
  "cost": 1,
  "description": "Deal [b]4+Strength[/b] damage.",
  "front_image": "player/<id>.png",
  "side": "player",
  "effects": [ { "type": "deal_damage", "amount": 4, "scaling": "strength" } ]
}
```
- Allowed effect types + status names live in `data_validator.gd` (`ALLOWED_EFFECT_TYPES`, `ALLOWED_STATUS_NAMES`). Don't invent new ones without adding a combat_engine handler.
- Also create `<id>_plus.json` (the rest-site upgrade) — same shape, +50-67% on the numbers, title gets a `+`, `front_image` reuses the BASE `player/<id>.png`.
- **Wiring (pick one):**
  - Always-available → add `"<id>"` to `MetaProgress.INITIAL_CARD_POOL` in `run_system/core/meta_progress.gd`.
  - Unlockable → add to a tier's `unlocks` array in `run_system/data/base_upgrades/card_research.json`.
- **Art:** `front_image` may temporarily point at an existing PNG as a placeholder; once codex delivers `cards/player/<id>.png`, flip the path. Don't leave it on a placeholder if real art exists.

## enemy → `battle_scene/card_info/enemy/<id>.json`

```json
{
  "id": "<id>",
  "name": "Display Name",
  "sprite_id": "<existing_sprite_folder>",
  "max_health": 30,
  "action_pattern": [
    { "type": "attack", "amount": 8, "label": "⚔ 8" },
    { "type": "block",  "amount": 6, "label": "🛡 6" }
  ]
}
```
- Action types: `attack`, `attack_status` (needs `status`+`stacks`), `attack_all`, `block`, `heal`, `telegraph`. See `ALLOWED_ENEMY_ACTION_TYPES`.
- `sprite_id` points at a folder under `battle_scene/assets/images/enemies/`. Reuse an existing one as placeholder until codex makes a dedicated folder; bosses are 192×192, regular 128×128.
- **Wiring (pick one):**
  - Regular → add to `ENCOUNTER_POOLS_EARLY/MID/LATE` in `run_system/core/run_manager.gd`.
  - Elite → `ELITE_ROSTER`.
  - Boss → `BOSS_BY_FLOOR[floor_idx]` (NOT the legacy `BOSS_ROSTER`). If it's a NEW boss floor, also confirm `is_boss_floor()` picks it up (it reads BOSS_BY_FLOOR keys).
- `DataValidator.validate_encounter_pools()` fails at boot if a referenced id has no JSON — so wire + create together.

## relic → `run_system/data/relics/<id>.json`

```json
{
  "id": "<id>",
  "title": "Display Name",
  "description": "After combat, gain 5 Gold.",
  "icon": "res://run_system/assets/images/relics/<id>.png",
  "rarity": "common|uncommon|rare",
  "effects": [ { "trigger": "combat_victory", "type": "gain_gold", "amount": 5 } ]
}
```
- Supported triggers/types live in `battle_scene/relic_effect_system.gd`: triggers `player_turn_start` (+optional `round`, `once_per_combat`), `player_attack_damage`, `enemy_attack_damage`, `combat_victory`; types `gain_energy`, `gain_block`, `add_damage`, `reduce_damage`, `heal`, `gain_gold`. Anything else needs a new handler there first.
- **Wiring:** relics auto-enter the unowned pool via `RunManager.get_unowned_relic_ids()` (scans the dir). No list to update — just ensure the `icon` path resolves to a real PNG (don't leave a placeholder when real art exists).

## hero → `run_system/data/heroes/<id>.json`

```json
{
  "id": "<id>",
  "name": "Display Name",
  "sprite_id": "cowboy_bill",
  "tint": "#ffffff",
  "max_health": 50,
  "starter_deck": ["strike", "strike", "defend", "defend"],
  "starting_attributes": {"strength": 3, "constitution": 3, "intelligence": 3, "luck": 3, "charm": 3},
  "description": "..."
}
```
- Required keys enforced by `validate_hero` in `data_validator.gd`.
- `tint` red-shifts a placeholder sprite until codex makes a real folder; `sprite_id` points at `battle_scene/assets/images/heroes/<folder>/`.
- **Wiring:** `hero_select.gd` is data-driven — it auto-discovers every hero JSON and renders a clickable portrait card, so a new hero appears with **no scene/code change**. Just provide the `sprite_id` portrait (`heroes/<sprite_id>/<sprite_id>_portrait.png`; falls back to a warning if missing). A locked hero needs a `*_unlock` base upgrade (see below) + a lock branch in `_make_hero_card` (currently only `hero_jerry_killer` is gated on `jerry_unlock`).

## base_upgrade → `run_system/data/base_upgrades/<id>.json`

```json
{
  "id": "<id>",
  "name": "DISPLAY NAME",
  "description": "...",
  "effect_key": "max_hp_bonus",
  "tiers": [
    {"level": 1, "cost": 30, "effect_value": {"hp": 10}, "effect_text": "+10 max HP"}
  ]
}
```
- `effect_key` MUST be in `ALLOWED_BASE_UPGRADE_EFFECT_KEYS` (`data_validator.gd`) — add it there if new.
- **Wiring:** add `"<id>"` to `UPGRADE_ORDER` in `run_system/ui/home_base_scene.gd` so the panel renders. Then implement the effect:
  - run-start effects → read via `_get_meta_effect_value("<id>")` in `RunManager._apply_meta_upgrades`.
  - purchase-time effects (like card unlock) → handle in `MetaProgress.purchase_upgrade` by `effect_key`.

## Always finish with

```bash
bash scripts/smoke_test.sh
```
Expected: `[OK] DataValidator: all schemas passed.` If it lists a schema failure, the JSON shape is wrong — fix before considering the content added. Do NOT commit until smoke is green. Codex (not Claude) owns generating the actual PNG art per ADR-0005.
