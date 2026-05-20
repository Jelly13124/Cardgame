# Enemies Catalog

**Last updated:** 2026-05-18
**Total combatants:** 8 (2 original + 4 standard + 1 elite + 1 boss)

## Paths

| Resource | Path |
|---|---|
| Enemy JSON definitions | `battle_scene/card_info/enemy/{id}.json` |
| Sprite folder (per enemy) | `battle_scene/assets/images/enemies/{sprite_id}/` |
| Animation subfolders | `idle/`, `attack/`, optional `charge/` (boss telegraph) |
| Frame naming | `idle/{sprite_id}_idle_{0-3}.png` + `attack/{sprite_id}_attack_{0-3}.png` (+ optional `charge/{sprite_id}_charge_{0-3}.png`) |
| Generated art pipeline (intermediates) | `battle_scene/assets/images/enemies/{sprite_id}/generated_sheet/` |
| Spawn / runtime code | `battle_scene/enemy_entity.gd` (factory + animation), `battle_scene/enemy_ai.gd` (action exec) |
| Schema validator | `battle_scene/data_validator.gd` `validate_enemy()` + `validate_encounter_pools()` |
| Encounter selection | `run_system/core/run_manager.gd` `select_encounter()` |
| Encounter pools | `run_system/core/run_manager.gd` `ENCOUNTER_POOLS_*` / `ELITE_ROSTER` / `BOSS_ROSTER` |

## Quick stats

| Tier | Count | IDs |
|---|---|---|
| Original | 2 | trash_robot, wasteland_killer |
| Standard (Tactical Toolkit) | 4 | scrap_rat, riot_hound, rust_brute, mortar_cart |
| Elite | 1 | armored_patrol |
| Boss | 1 | junkyard_tyrant |

| Trait | Enemies |
|---|---|
| Applies status to player | riot_hound (Weak), armored_patrol (Vulnerable) |
| Telegraph + interruptible big attack | mortar_cart, junkyard_tyrant |
| AoE attack | mortar_cart (`attack_all`) |
| Heals self | _none yet_ |

## Summary table

| ID | Name | HP | Tier | Sprite ID | Pattern length | Frames |
|---|---|---|---|---|---|---|
| `trash_robot` | Trash Robot | 30 | original | `trash_robot` | 4 | ✅ |
| `wasteland_killer` | Wasteland Killer | 20 | original | `wasteland_killer` | 3 | ✅ |
| `scrap_rat` | Scrap Rat | 12 | standard | `scrap_rat` | 3 | ✅ |
| `riot_hound` | Riot Hound | 25 | standard | `riot_hound` | 3 | ✅ |
| `rust_brute` | Rust Brute | 40 | standard | `rust_brute` | 4 | ✅ |
| `mortar_cart` | Mortar Cart | 28 | standard | `mortar_cart` | 5 | ✅ |
| `armored_patrol` | Armored Patrol | 50 | elite | `armored_patrol` | 4 | ✅ |
| `junkyard_tyrant` | Junkyard Tyrant | 110 | boss | `junkyard_tyrant` | 9 | ✅ |

## Encounter pools (where each enemy spawns)

Defined in `run_system/core/run_manager.gd`. `select_encounter(type, floor)` is called by `map_scene.gd._on_node_clicked()` before transitioning into battle.

### `ENCOUNTER_POOLS_EARLY` — floor 0-3
- `[scrap_rat]`
- `[trash_robot]`
- `[scrap_rat, scrap_rat]`
- `[wasteland_killer]`

### `ENCOUNTER_POOLS_MID` — floor 4-7
- `[riot_hound]`
- `[rust_brute]`
- `[trash_robot, scrap_rat]`
- `[mortar_cart]`
- `[wasteland_killer, scrap_rat]`

### `ENCOUNTER_POOLS_LATE` — floor 8-10
- `[riot_hound, riot_hound]`
- `[rust_brute, scrap_rat]`
- `[mortar_cart, scrap_rat]`
- `[rust_brute, riot_hound]`

### `ELITE_ROSTER` — elite map nodes (any floor)
- `[armored_patrol]`

### `BOSS_ROSTER` — floor 11 boss node
- `[junkyard_tyrant]`

> `DataValidator.validate_encounter_pools()` checks at startup that every ID listed above has a matching `{id}.json` file. Typos fail loud at startup, not mid-combat.

## Per-enemy details

### `trash_robot` (HP 30)
- Sprite: `battle_scene/assets/images/enemies/trash_robot/`
- JSON: `battle_scene/card_info/enemy/trash_robot.json`

**Action pattern (loops):**
| # | Type | Amount | Label |
|---|---|---|---|
| 1 | attack | 6 | ⚔ 6 |
| 2 | attack | 8 | ⚔ 8 |
| 3 | block | 6 | 🛡 6 |
| 4 | attack | 10 | ⚔ 10 |

### `wasteland_killer` (HP 20)
- Sprite: `battle_scene/assets/images/enemies/wasteland_killer/`
- JSON: `battle_scene/card_info/enemy/wasteland_killer.json`

**Action pattern (loops):**
| # | Type | Amount | Label |
|---|---|---|---|
| 1 | block | 8 | 🛡 8 |
| 2 | block | 8 | 🛡 8 |
| 3 | attack | 12 | ⚔ 12 |

### `scrap_rat` (HP 12) — swarmer
- Sprite: `battle_scene/assets/images/enemies/scrap_rat/`
- JSON: `battle_scene/card_info/enemy/scrap_rat.json`

**Action pattern (loops):**
| # | Type | Amount | Label |
|---|---|---|---|
| 1 | attack | 4 | ⚔ 4 |
| 2 | attack | 4 | ⚔ 4 |
| 3 | attack | 6 | ⚔ 6 |

### `riot_hound` (HP 25) — applies Weak
- Sprite: `battle_scene/assets/images/enemies/riot_hound/`
- JSON: `battle_scene/card_info/enemy/riot_hound.json`

**Action pattern (loops):**
| # | Type | Amount | Status | Label |
|---|---|---|---|---|
| 1 | attack_status | 5 | weak 1 | ⚔ 5 +Weak |
| 2 | attack | 5 | — | ⚔ 5 |
| 3 | block | 4 | — | 🛡 4 |

### `rust_brute` (HP 40) — tank
- Sprite: `battle_scene/assets/images/enemies/rust_brute/`
- JSON: `battle_scene/card_info/enemy/rust_brute.json`

**Action pattern (loops):**
| # | Type | Amount | Label |
|---|---|---|---|
| 1 | block | 10 | 🛡 10 |
| 2 | attack | 8 | ⚔ 8 |
| 3 | attack | 8 | ⚔ 8 |
| 4 | block | 10 | 🛡 10 |

### `mortar_cart` (HP 28) — telegraph + interruptible AoE
- Sprite: `battle_scene/assets/images/enemies/mortar_cart/`
- JSON: `battle_scene/card_info/enemy/mortar_cart.json`

**Action pattern (loops):**
| # | Type | Amount | Flag | Label |
|---|---|---|---|---|
| 1 | block | 4 | — | 🛡 4 |
| 2 | block | 4 | — | 🛡 4 |
| 3 | telegraph | — | — | 💢 CHARGING |
| 4 | attack_all | 12 | **interruptible** | 💥 12 |
| 5 | block | 4 | — | 🛡 4 |

> Apply 1 Shock during the CHARGING turn → the `attack_all 12` is cancelled the next turn with "INTERRUPTED" notification.

### `armored_patrol` (HP 50) — elite, applies Vulnerable
- Sprite: `battle_scene/assets/images/enemies/armored_patrol/`
- JSON: `battle_scene/card_info/enemy/armored_patrol.json`

**Action pattern (loops):**
| # | Type | Amount | Status | Label |
|---|---|---|---|---|
| 1 | block | 12 | — | 🛡 12 |
| 2 | attack | 8 | — | ⚔ 8 |
| 3 | block | 12 | — | 🛡 12 |
| 4 | attack_status | 10 | vulnerable 1 | ⚔ 10 +Vuln |

### `junkyard_tyrant` (HP 110) — boss, single phase
- Sprite: `battle_scene/assets/images/enemies/junkyard_tyrant/`
- JSON: `battle_scene/card_info/enemy/junkyard_tyrant.json`
- Native frame size: 192×192 (1.5× normal scale under the 128-native art rule).

**Action pattern (loops — 9 actions):**
| # | Type | Amount | Flag | Label |
|---|---|---|---|---|
| 1 | attack | 10 | — | ⚔ 10 |
| 2 | attack | 12 | — | ⚔ 12 |
| 3 | block | 12 | — | 🛡 12 |
| 4 | telegraph | — | — | 💢 CHARGING |
| 5 | attack | 22 | **interruptible** | 💥 CRUSHING 22 |
| 6 | attack | 14 | — | ⚔ 14 |
| 7 | block | 10 | — | 🛡 10 |
| 8 | telegraph | — | — | 💢 CHARGING |
| 9 | attack | 22 | **interruptible** | 💥 CRUSHING 22 |

> Two Crushing Blow windows per cycle. Both can be cancelled with Shock during the CHARGING turn.

## Supported enemy action types

Defined in `enemy_ai.gd` `_execute_action()`. Allowed types tracked in `data_validator.gd` `ALLOWED_ENEMY_ACTION_TYPES`.

| Action type | Behavior | JSON shape |
|---|---|---|
| `attack` | Damage player. Plays attack sprite + lunge animation. | `{type, amount, label}` |
| `attack_status` | Damage + apply named status to player. | `{type, amount, status, stacks, label}` |
| `attack_all` | Damage player (effectively same as `attack` since single player); louder messaging. | `{type, amount, label, optional interruptible}` |
| `block` | Self-block + scale pulse. | `{type, amount, label}` |
| `heal` | Self-heal. | `{type, amount, label}` |
| `telegraph` | No damage. Flashes "CHARGING" tint. Sets up next-turn interruptible attack. | `{type, label}` |

### Action flags
- `interruptible: true` on any attack — if the enemy has ≥1 Shock stack when the action fires, consume 1 Shock and cancel the attack. Used on the action AFTER a telegraph for mortar_cart and the Boss.

## Status effects

Defined in `battle_scene/status_effect_system.gd`. Allowed names tracked in `data_validator.gd` `ALLOWED_STATUS_NAMES`.

| Status | Holder | Decay | Behavior |
|---|---|---|---|
| `poison` | any | -1 per turn start | Deals stack damage at turn start. |
| `burn` | any | none | Deals stack damage at turn start. |
| `weak` | any | -1 per turn end | Outgoing attack damage × 0.5. |
| `vulnerable` | any | -1 per turn end | Incoming attack damage × 1.5. |
| `strength_up` | any | -1 per turn end | Adds stack to Strength. |
| `double_damage` | player only | manual consume | Next attack card deals 2× damage. |
| `shock` | enemy only | manual consume (by enemy_ai or interruptible attacks) | Skips one enemy action OR cancels one interruptible attack. |

## Adding a new enemy — checklist

1. Create `battle_scene/card_info/enemy/{id}.json` with `id`, `name`, `sprite_id`, `max_health`, `action_pattern[]`.
2. Ensure each pattern entry's `type` is one of the supported action types above (validator will fail loud otherwise).
3. Add `{id}` to a pool in `run_manager.gd` (`ENCOUNTER_POOLS_*` / `ELITE_ROSTER` / `BOSS_ROSTER`).
4. Generate sprites → `battle_scene/assets/images/enemies/{sprite_id}/{anim}/{sprite_id}_{anim}_0..3.png` (192×192 for boss, 128×128 otherwise).
5. Restart the editor — DataValidator validates JSON + cross-checks every encounter pool ID at startup.

## Known limitations (deferred)

- Enemies can't `gain_strength` mid-combat (would need `gain_strength_self` action type).
- Enemies can't summon other enemies (would need `summon` action type + AI rework for new spawns mid-fight).
- No HP-threshold phase transitions for any enemy yet (Boss is single-phase).
- No enemy steals gold (would need `steal_gold` action type and Map-screen feedback).
- Enemy block resets to 0 at the start of each enemy turn (`enemy_entity.start_turn()`). If you want persistent block, that needs a flag.
