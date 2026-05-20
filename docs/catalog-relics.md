# Relics Catalog

**Last updated:** 2026-05-18
**Total relics:** 6 (all common — Tactical Toolkit hasn't added any new relics)

## Paths

| Resource | Path |
|---|---|
| Relic JSON definitions | `run_system/data/relics/{id}.json` |
| Relic icon (PNG) | `run_system/assets/images/relics/{id}.png` |
| Generated icon pipeline (intermediates) | `run_system/assets/images/relics/generated_sheet/` |
| Effect resolver code | `battle_scene/relic_effect_system.gd` |
| Schema validator | `battle_scene/data_validator.gd` `validate_relic()` |
| Run-state relic list | `run_system/core/run_manager.gd` `relics` array |
| Map relic choice UI | `run_system/ui/map_scene.gd` `_open_relic_choice()` |

## Quick stats

| Rarity | Count |
|---|---|
| Common | 6 |
| Uncommon | 0 |
| Rare | 0 |

| Trigger | Relics |
|---|---|
| `player_turn_start` (round 1, once_per_combat) | cracked_battery, steel_plating |
| `player_attack_damage` | sharpened_scrap |
| `enemy_attack_damage` (once_per_combat) | signal_jammer |
| `combat_victory` | lucky_cog, repair_kit |

## Summary table

| ID | Title | Rarity | Trigger | Effect | Once/combat | Icon |
|---|---|---|---|---|---|---|
| `cracked_battery` | Cracked Battery | common | player_turn_start (round 1) | gain_energy 1 | ✓ | ✅ |
| `steel_plating` | Steel Plating | common | player_turn_start (round 1) | gain_block 6 | ✓ | ✅ |
| `sharpened_scrap` | Sharpened Scrap | common | player_attack_damage | add_damage 1 | — | ✅ |
| `signal_jammer` | Signal Jammer | common | enemy_attack_damage | reduce_damage 2 | ✓ | ✅ |
| `lucky_cog` | Lucky Cog | common | combat_victory | gain_gold 5 | — | ✅ |
| `repair_kit` | Repair Kit | common | combat_victory | heal 3 | — | ✅ |

## Per-relic details

### `cracked_battery`
**"At the start of your first turn each combat, gain 1 Energy."**
- Trigger: `player_turn_start` (round 1, once_per_combat)
- Effect: `gain_energy 1`
- JSON: `run_system/data/relics/cracked_battery.json`
- Icon: `run_system/assets/images/relics/cracked_battery.png`

### `steel_plating`
**"At the start of your first turn each combat, gain 6 Block."**
- Trigger: `player_turn_start` (round 1, once_per_combat)
- Effect: `gain_block 6`
- JSON: `run_system/data/relics/steel_plating.json`
- Icon: `run_system/assets/images/relics/steel_plating.png`

### `sharpened_scrap`
**"Your direct attack damage is increased by 1."**
- Trigger: `player_attack_damage` (every attack)
- Effect: `add_damage 1`
- JSON: `run_system/data/relics/sharpened_scrap.json`
- Icon: `run_system/assets/images/relics/sharpened_scrap.png`

### `signal_jammer`
**"The first enemy attack each combat deals 2 less damage."**
- Trigger: `enemy_attack_damage` (once_per_combat)
- Effect: `reduce_damage 2`
- JSON: `run_system/data/relics/signal_jammer.json`
- Icon: `run_system/assets/images/relics/signal_jammer.png`

### `lucky_cog`
**"After combat, gain 5 Gold."**
- Trigger: `combat_victory`
- Effect: `gain_gold 5` (calls `RunManager.add_resources(5, 0)`)
- JSON: `run_system/data/relics/lucky_cog.json`
- Icon: `run_system/assets/images/relics/lucky_cog.png`

### `repair_kit`
**"After combat, heal 3 HP."**
- Trigger: `combat_victory`
- Effect: `heal 3` (calls `player.heal(3)`)
- JSON: `run_system/data/relics/repair_kit.json`
- Icon: `run_system/assets/images/relics/repair_kit.png`

## Supported triggers

Defined in `battle_scene/relic_effect_system.gd`. Each method handles one trigger family.

| Trigger | When fires | Effect types supported | Method |
|---|---|---|---|
| `player_turn_start` | Beginning of every player turn | `gain_energy`, `gain_block` | `on_player_turn_started()` |
| `player_attack_damage` | Modifies outgoing player damage | `add_damage` | `modify_player_attack_damage()` |
| `enemy_attack_damage` | Modifies incoming enemy damage | `reduce_damage` | `modify_enemy_attack_damage()` |
| `combat_victory` | After winning a combat | `heal`, `gain_gold` | `on_combat_victory()` |

### Trigger options
- `round` (int, optional): fires only on this round number (e.g. `1` for first-turn relics).
- `once_per_combat` (bool, optional): fires at most once per battle.

## Adding a new relic — checklist

1. Create `run_system/data/relics/{id}.json` with `id`, `title`, `description`, `icon`, `rarity`, `effects[]`.
2. Each `effects[]` entry needs a `trigger` matching one of the supported triggers above.
3. If introducing a new trigger family, add a method in `relic_effect_system.gd` AND wire it from the appropriate combat hook in `battle_scene.gd` / `combat_engine.gd`.
4. If introducing a new effect type within an existing trigger, add a `match` arm in the relevant `relic_effect_system.gd` method.
5. Generate icon → `run_system/assets/images/relics/{id}.png`.
6. Run the game — DataValidator validates `id`, `title`, and per-effect `trigger` field at startup.

## Known limitations (deferred)

- No relic uses `card_played` trigger yet (the system has no such trigger defined either — would need adding to `combat_engine.gd` after card resolution).
- No relic uses `enemy_killed` trigger.
- No relic uses `card_drawn` trigger.
- The UI theme palette doesn't theme relic icons (they're standalone PNGs); relic icons must follow `docs/art-style-reference.md`.
