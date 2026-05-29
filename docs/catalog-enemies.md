# Enemies Catalog

**Last updated:** 2026-05-28
**Total combatants:** 13 (9 standard + 1 elite + 3 boss)

## Paths

| Resource | Path |
|---|---|
| Enemy JSON definitions | `battle_scene/card_info/enemy/{id}.json` |
| Sprite folder (per enemy) | `battle_scene/assets/images/enemies/{sprite_id}/` |
| Animation subfolders | `attack/`, optional `charge/` (boss telegraph) |
| Frame naming | `attack/{sprite_id}_attack_{0-3}.png` (+ optional `charge/{sprite_id}_charge_{0-3}.png`) |
| Rest pose | `attack/{sprite_id}_attack_0.png`; no separate `idle/` assets |
| Generated art pipeline (intermediates) | Optional, but must not contain canceled animation outputs |
| Spawn / runtime code | `battle_scene/enemy_entity.gd` (factory + animation), `battle_scene/enemy_ai.gd` (action exec) |
| Schema validator | `battle_scene/data_validator.gd` `validate_enemy()` + `validate_encounter_pools()` |
| Encounter selection | `run_system/core/run_manager.gd` `select_encounter()` |
| Encounter pools | `run_system/core/run_manager.gd` `ENCOUNTER_POOLS_*` / `ELITE_ROSTER` / `BOSS_BY_FLOOR` |

## Quick stats

| Tier | Count | IDs |
|---|---|---|
| Standard | 9 | trash_robot, wasteland_killer, scrap_rat, riot_hound, rust_brute, mortar_cart, slag_walker, acid_spitter, chrome_hound |
| Elite | 1 | armored_patrol |
| Boss | 3 | rust_titan (floor 4), ash_warden (floor 8), junkyard_tyrant (floor 11) |

| Trait | Enemies |
|---|---|
| Applies status to player | riot_hound (Weak), chrome_hound (Weak), armored_patrol (Vulnerable), acid_spitter (Poison), ash_warden (Burn + Vulnerable) |
| Telegraph + interruptible big attack | mortar_cart, rust_titan, ash_warden, junkyard_tyrant |
| AoE attack | mortar_cart (`attack_all`) |
| Heals self | _none yet_ |

## Summary table

| ID | Name | HP | Tier | Sprite ID | Pattern length | Frames |
|---|---|---|---|---|---|---|
| `acid_spitter` | Acid Spitter | 18 | standard | `acid_spitter` | 3 | ✅ |
| `armored_patrol` | Armored Patrol | 50 | elite | `armored_patrol` | 4 | ✅ |
| `ash_warden` | Ash Warden | 95 | boss | `ash_warden` | 7 | ✅ |
| `chrome_hound` | Chrome Hound | 32 | standard | `chrome_hound` | 4 | ✅ |
| `junkyard_tyrant` | Junkyard Tyrant | 110 | boss | `junkyard_tyrant` | 9 | ✅ |
| `mortar_cart` | Mortar Cart | 28 | standard | `mortar_cart` | 5 | ✅ |
| `riot_hound` | Riot Hound | 25 | standard | `riot_hound` | 3 | ✅ |
| `rust_brute` | Rust Brute | 40 | standard | `rust_brute` | 4 | ✅ |
| `rust_titan` | Rust Titan | 75 | boss | `rust_titan` | 6 | ✅ |
| `scrap_rat` | Scrap Rat | 12 | standard | `scrap_rat` | 3 | ✅ |
| `slag_walker` | Slag Walker | 28 | standard | `slag_walker` | 4 | ✅ |
| `trash_robot` | Trash Robot | 30 | standard | `trash_robot` | 4 | ✅ |
| `wasteland_killer` | Wasteland Killer | 20 | standard | `wasteland_killer` | 3 | ✅ |

> All enemies now use dedicated per-enemy sprite art (Codex wave-3 delivery, 2026-05-29).

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
- `[slag_walker]`
- `[acid_spitter, scrap_rat]`

### `ENCOUNTER_POOLS_LATE` — floor 8+
- `[riot_hound, riot_hound]`
- `[rust_brute, scrap_rat]`
- `[mortar_cart, scrap_rat]`
- `[rust_brute, riot_hound]`
- `[chrome_hound]`
- `[chrome_hound, scrap_rat]`
- `[slag_walker, acid_spitter]`

### `ELITE_ROSTER` — elite map nodes (any floor)
- `[armored_patrol]`

### `BOSS_BY_FLOOR` — per-floor boss assignments (mid-act + final)
- `4 → rust_titan` (act-1 boss)
- `8 → ash_warden` (act-2 boss)
- `11 → junkyard_tyrant` (final boss)

> `BOSS_ROSTER` still exists as a legacy alias holding only the final boss; new bosses must be added to `BOSS_BY_FLOOR` to actually spawn. `is_boss_floor(floor_idx)` is the canonical check used by both map gen and `select_encounter()`.

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

### `rust_titan` (HP 75) — boss, floor 4 (act-1)
- Sprite: `battle_scene/assets/images/enemies/rust_titan/`
- JSON: `battle_scene/card_info/enemy/rust_titan.json`

**Action pattern (loops — 6 actions):**
| # | Type | Amount | Flag | Label |
|---|---|---|---|---|
| 1 | attack | 8 | — | ⚔ 8 |
| 2 | block | 10 | — | 🛡 10 |
| 3 | attack | 12 | — | ⚔ 12 |
| 4 | telegraph | — | — | 💢 WIND-UP |
| 5 | attack | 18 | **interruptible** | 💥 SLAM 18 |
| 6 | block | 8 | — | 🛡 8 |

> One Slam window per cycle — cancel with Shock during WIND-UP.

### `ash_warden` (HP 95) — boss, floor 8 (act-2)
- Sprite: `battle_scene/assets/images/enemies/ash_warden/`
- JSON: `battle_scene/card_info/enemy/ash_warden.json`

**Action pattern (loops — 7 actions):**
| # | Type | Amount | Status | Flag | Label |
|---|---|---|---|---|---|
| 1 | attack_status | 6 | burn 2 | — | 🔥 6 + B2 |
| 2 | attack | 11 | — | — | ⚔ 11 |
| 3 | block | 12 | — | — | 🛡 12 |
| 4 | attack_status | 8 | vulnerable 1 | — | ⚔ 8 + V1 |
| 5 | telegraph | — | — | — | 💢 IGNITING |
| 6 | attack | 20 | — | **interruptible** | 💥 BLAST 20 |
| 7 | attack | 9 | — | — | ⚔ 9 |

> Status-heavy sentinel: stacks Burn + Vulnerable before the interruptible Blast. Cancel the Blast with Shock during IGNITING.

### `slag_walker` (HP 28) — standard (mid)
- Sprite: `battle_scene/assets/images/enemies/slag_walker/`
- JSON: `battle_scene/card_info/enemy/slag_walker.json`

**Action pattern (loops):**
| # | Type | Amount | Label |
|---|---|---|---|
| 1 | block | 6 | 🛡 6 |
| 2 | attack | 9 | ⚔ 9 |
| 3 | attack | 6 | ⚔ 6 |
| 4 | block | 6 | 🛡 6 |

### `acid_spitter` (HP 18) — standard (mid), applies Poison
- Sprite: `battle_scene/assets/images/enemies/acid_spitter/`
- JSON: `battle_scene/card_info/enemy/acid_spitter.json`

**Action pattern (loops):**
| # | Type | Amount | Status | Label |
|---|---|---|---|---|
| 1 | attack_status | 4 | poison 2 | ☠ 4 + P2 |
| 2 | attack | 6 | — | ⚔ 6 |
| 3 | attack_status | 3 | poison 3 | ☠ 3 + P3 |

> Low HP, high Poison output — kill fast or the stacking damage adds up.

### `chrome_hound` (HP 32) — standard (late), applies Weak
- Sprite: `battle_scene/assets/images/enemies/chrome_hound/`
- JSON: `battle_scene/card_info/enemy/chrome_hound.json`

**Action pattern (loops):**
| # | Type | Amount | Status | Label |
|---|---|---|---|---|
| 1 | attack | 8 | — | ⚔ 8 |
| 2 | attack | 8 | — | ⚔ 8 |
| 3 | attack_status | 5 | weak 1 | ⚔ 5 + W1 |
| 4 | block | 10 | — | 🛡 10 |

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
3. Add `{id}` to a pool in `run_manager.gd`: regular → `ENCOUNTER_POOLS_*`, elite → `ELITE_ROSTER`, boss → `BOSS_BY_FLOOR[floor_idx]` (NOT the legacy `BOSS_ROSTER`).
4. Generate sprites → `battle_scene/assets/images/enemies/{sprite_id}/{anim}/{sprite_id}_{anim}_0..3.png` (192×192 for boss, 128×128 otherwise).
5. Restart the editor — DataValidator validates JSON + cross-checks every encounter pool ID at startup.

## Known limitations (deferred)

- Enemies can't `gain_strength` mid-combat (would need `gain_strength_self` action type).
- Enemies can't summon other enemies (would need `summon` action type + AI rework for new spawns mid-fight).
- No HP-threshold phase transitions for any enemy yet (Boss is single-phase).
- No enemy steals gold (would need `steal_gold` action type and Map-screen feedback).
- Enemy block resets to 0 at the start of each enemy turn (`enemy_entity.start_turn()`). If you want persistent block, that needs a flag.
