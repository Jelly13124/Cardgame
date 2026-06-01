# Conventions — Data Files (JSON)

The game's content lives in JSON: cards, enemies, relics, and encounter pools. These files are the source of truth for balance and content — gameplay code reads them, never the reverse.

---

## Locations

| File type | Location | Validator |
|---|---|---|
| Player cards | `battle_scene/card_info/player/{id}.json` | `DataValidator.validate_card()` |
| Enemies (incl. elites + boss) | `battle_scene/card_info/enemy/{id}.json` | `DataValidator.validate_enemy()` |
| Relics | `run_system/data/relics/{id}.json` | `DataValidator.validate_relic()` |
| Encounter pools | constants in `run_system/core/run_manager.gd` | `DataValidator.validate_encounter_pools()` |

---

## Naming

- Filename = the `id` / `name` field inside, no extension. `strike.json` → `name: "strike"`.
- `id` / `name` is **lower-snake-case**: `stun_baton`, `junkyard_tyrant`. No spaces, no caps, no dots.
- Display title is the human-readable `title` field — separate from `id`. `Stun Baton` is the title; `stun_baton` is the id.

---

## Required fields

### Cards
```json
{
  "name": "card_id",          // matches filename
  "title": "Display Name",
  "type": "attack|skill|ability",
  "cost": 1,
  "effects": [ ... ]
}
```
Optional: `description`, `front_image`, `side`, `rarity` (`common|uncommon|rare`), `retain` (bool).

### Enemies
```json
{
  "id": "enemy_id",            // matches filename
  "name": "Display Name",
  "sprite_id": "sprite_id",    // folder name under enemies/
  "max_health": 30,
  "action_pattern": [ ... ]
}
```
Each action entry needs `type` (one of `ALLOWED_ENEMY_ACTION_TYPES`). `attack_status` actions also need `status` + `stacks`. Attacks marked `"interruptible": true` can be cancelled by 1 stack of shock.

Optional `phases` (array) — HP-threshold phase transitions. Each phase has `hp_below` (fraction in `(0, 1]`), an `action_pattern` (validated like the top-level one), and an optional `on_enter` array of actions fired once on entering the phase.

### Relics
```json
{
  "id": "relic_id",
  "title": "Display Name",
  "effects": [
    { "trigger": "trigger_name", "type": "effect_type", ... }
  ]
}
```

---

## Effect types (cards)

Authoritative list in `DataValidator.ALLOWED_EFFECT_TYPES`. As of this writing:

- Damage: `deal_damage`, `deal_damage_all`, `scale_damage_by_attacks`
- Defense: `gain_block`
- Resources: `gain_energy`, `draw_cards`
- Attributes: `gain_strength`, `gain_constitution`, `gain_intelligence`, `gain_luck`, `gain_charm`
- Status: `apply_status`, `apply_status_self`, `apply_status_all`, `apply_shock`, `apply_shock_all`
- Marker: `exhaust_self`

When adding a new effect type, update **both** `combat_engine._apply_effect()` and `DataValidator.ALLOWED_EFFECT_TYPES`.

---

## Enemy action types

Authoritative list in `DataValidator.ALLOWED_ENEMY_ACTION_TYPES`:

- `attack` — single damage to player
- `attack_status` — damage + apply status to player
- `attack_all` — AoE damage (currently single-player target, with louder messaging)
- `block` — self-block
- `heal` — self-heal
- `telegraph` — no-op + "CHARGING" intent badge, sets up next action as interruptible
- `summon` — spawns add enemies mid-combat. Required: `enemy_ids` (array of enemy ids); optional `count` (default 1). Capped at `MAX_ENEMIES_ON_FIELD` (4) — spawns past the cap are skipped. e.g. `{"type":"summon","enemy_ids":["scrap_shard"],"count":2}`
- `buff_self` — applies a status to the acting enemy itself. Required: `status` (∈ `ALLOWED_STATUS_NAMES`, e.g. `strength_up`), `stacks`. e.g. `{"type":"buff_self","status":"strength_up","stacks":3}`

---

## Status names

Authoritative list in `DataValidator.ALLOWED_STATUS_NAMES`:

`poison`, `burn`, `weak`, `vulnerable`, `strength_up`, `double_damage`, `shock`

**Shock is enemy-only** (see `docs/adr/0004-shock-enemy-only.md`).

---

## Validation lifecycle

`DataValidator.validate_all_data_at_startup()` runs in `RunManager._ready()`. It scans all four data sources and reports failures via `push_error`. In debug builds it `assert(false)` to crash loud; in release builds it logs and continues.

To verify locally:
```bash
godot --headless --path . --quit-after 5
```
Expected output: `DataValidator: all card/enemy/relic JSON files passed schema check.`

If you see `X validation failure(s)`, the error log above explains what's wrong (missing field, unknown effect type, typo in status name, encounter pool references a missing enemy id, etc.).

---

## Conventions, not rules (yet)

- **Cost range:** cards currently use 0, 1, or 2 energy. We haven't formalized a max — but cost 3+ should justify itself.
- **HP / damage scale:** enemy HP ranges from 12 (swarmer) to 110 (boss). Player has 50 max HP. Damage from individual cards: 2-12; from boss: up to 22 per hit. Scaling rules aren't formal yet — adjust by playtest.
- **Rarity weights** (for loot draft): common 70 / uncommon 25 / rare 5. Defined in `loot_reward.gd`.

---

## Common mistakes

- ❌ Typo'd key like `"retian": true` — validator catches as warning ("unknown top-level key 'retian'").
- ❌ Effect type spelled `deal_dmg` instead of `deal_damage` — validator catches as error.
- ❌ Enemy `sprite_id` doesn't match a folder under `enemies/` — game runs with `ColorRect` placeholder, **no error** because frames are warn-only (Codex may be generating them). If you intended to use an existing sprite, double-check spelling.
- ❌ Adding new effect type to JSON but forgetting `combat_engine` handler — validator catches via `ALLOWED_EFFECT_TYPES`, but only if you also updated that list. If you updated `combat_engine` but not the validator, JSON will validate OK at startup, then `combat_engine` will `push_error` + assert at runtime on first use.
