# Enemies Catalog

**Last updated:** 2026-06-04
**Total combatants:** 15

## Paths

| Resource | Path |
|---|---|
| Enemy JSON definitions | `battle_scene/card_info/enemy/{id}.json` |
| Sprite folder (per enemy) | `battle_scene/assets/images/enemies/{sprite_id}/` |
| Animation subfolders | Runtime uses `attack/`; `hurt/` is optional and plays on real damage; `charge/` is optional for telegraphs |
| Frame naming | `attack/{sprite_id}_attack_{N}.png`, `hurt/{sprite_id}_hurt_{N}.png`, `charge/{sprite_id}_charge_{N}.png` |
| Rest pose | `attack/{sprite_id}_attack_0.png`; no separate `idle/` assets |
| Generated art pipeline (intermediates) | Optional, but must not contain canceled animation outputs or unused old-style animation folders |
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
| Summon-only add | 2 | scrap_shard (Junkyard Tyrant), ember_wisp (Ash Warden) |

> Summon-only adds have no encounter-pool entry — they spawn only via a boss `summon` action mid-fight, so the generator flags them UNLISTED. That is expected.

| Trait | Enemies |
|---|---|
| Applies status to player | riot_hound (Weak), chrome_hound (Weak), armored_patrol (Vulnerable), acid_spitter (Poison), ash_warden (Burn + Weak + Vulnerable), ember_wisp (Burn) |
| Telegraph + interruptible big attack | mortar_cart, rust_titan, ash_warden, junkyard_tyrant |
| AoE attack | mortar_cart, junkyard_tyrant (`attack_all`) |
| HP-threshold phase transition | rust_titan, ash_warden, junkyard_tyrant (all enrage at 50% HP) |
| Summons adds | ash_warden (ember_wisp), junkyard_tyrant (scrap_shard) |
| Buffs own Strength | rust_titan, junkyard_tyrant (`buff_self` strength_up) |
| Heals self | junkyard_tyrant (phase-2 `heal`) |

## Summary table

_Tier is a best-effort read of `run_manager.gd` encounter constants — `UNLISTED` means the enemy JSON exists but is in no pool/roster. For the two summon-only adds (scrap_shard, ember_wisp) that is expected: they spawn only via a boss `summon` action. Pattern length is the BASE `action_pattern` only; bosses also carry a phase-2 `action_pattern` (see per-enemy details)._

| ID | Name | HP | Tier | Sprite ID | Pattern length | Frames |
|---|---|---|---|---|---|---|
| `acid_spitter` | Acid Spitter | 18 | standard | `acid_spitter` | 3 | ✅ |
| `armored_patrol` | Armored Patrol | 50 | elite | `armored_patrol` | 4 | ✅ |
| `ash_warden` | Ash Warden | 95 | boss | `ash_warden` | 7 | ✅ |
| `chrome_hound` | Chrome Hound | 32 | standard | `chrome_hound` | 4 | ✅ |
| `ember_wisp` | Ember Wisp | 8 | summon-only | `ember_wisp` | 1 | ✅ |
| `junkyard_tyrant` | Junkyard Tyrant | 110 | boss | `junkyard_tyrant` | 8 | ✅ |
| `mortar_cart` | Mortar Cart | 28 | standard | `mortar_cart` | 5 | ✅ |
| `riot_hound` | Riot Hound | 25 | standard | `riot_hound` | 3 | ✅ |
| `rust_brute` | Rust Brute | 40 | standard | `rust_brute` | 4 | ✅ |
| `rust_titan` | Rust Titan | 75 | boss | `rust_titan` | 6 | ✅ |
| `scrap_rat` | Scrap Rat | 12 | standard | `scrap_rat` | 3 | ✅ |
| `scrap_shard` | Scrap Shard | 10 | summon-only | `scrap_shard` | 1 | ✅ |
| `slag_walker` | Slag Walker | 28 | standard | `slag_walker` | 4 | ✅ |
| `trash_robot` | Trash Robot | 30 | standard | `trash_robot` | 4 | ✅ |
| `wasteland_killer` | Wasteland Killer | 20 | standard | `wasteland_killer` | 3 | ✅ |

> All enemies, including summon-only adds, now use dedicated per-enemy sprite art. The runtime supports continuous 4-to-16-frame attack, hurt, and charge folders. Newly refactored enemies should target 8-frame attack and 8-frame hurt sheets in the active Offbeat Adult Sci-Fi Cartoon Wasteland style.

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

### `scrap_shard` (HP 10) — summon-only add
- Sprite: `battle_scene/assets/images/enemies/scrap_shard/`
- JSON: `battle_scene/card_info/enemy/scrap_shard.json`
- Spawned only by Junkyard Tyrant's `summon` action; never appears in an encounter pool.

**Action pattern (loops):**
| # | Type | Amount | Label |
|---|---|---|---|
| 1 | attack | 4 | ⚔ 4 |

### `ember_wisp` (HP 8) — summon-only add
- Sprite: `battle_scene/assets/images/enemies/ember_wisp/`
- JSON: `battle_scene/card_info/enemy/ember_wisp.json`
- Spawned only by Ash Warden's `summon` action; never appears in an encounter pool.

**Action pattern (loops):**
| # | Type | Amount | Status | Label |
|---|---|---|---|---|
| 1 | attack_status | 3 | burn 2 | 🔥 3 + B2 |

### `junkyard_tyrant` (HP 110) — boss, floor 11 (final), two phases
- Sprite: `battle_scene/assets/images/enemies/junkyard_tyrant/`
- JSON: `battle_scene/card_info/enemy/junkyard_tyrant.json`
- Native frame size: 192×192 (1.5× normal scale under the 128-native art rule).
- Bespoke kit: summons `scrap_shard` adds, an interruptible `attack_all` Scrapstorm, and a phase-2 self-`heal`. Killing the Tyrant ends the fight even if its summoned adds are still alive.

**Phase 1 — base `action_pattern` (HP ≥ 50%, loops — 8 actions):**
| # | Type | Amount | Flag | Label |
|---|---|---|---|---|
| 1 | attack | 10 | — | ⚔ 10 |
| 2 | summon | scrap_shard ×1 | — | ☠ SCRAP x1 |
| 3 | attack | 12 | — | ⚔ 12 |
| 4 | block | 12 | — | 🛡 12 |
| 5 | telegraph | — | — | 💢 CHARGING |
| 6 | attack_all | 14 | **interruptible** | 💥 SCRAPSTORM 14 |
| 7 | attack | 14 | — | ⚔ 14 |
| 8 | block | 10 | — | 🛡 10 |

**Phase 2 — on dropping below 50% HP (`hp_below: 0.5`):**
- `on_enter` (one-shot): summon `scrap_shard` ×2 (☠ SCRAP x2) + `buff_self` strength_up 2 (💢 ENRAGE).
- Then loops a new 5-action pattern:

| # | Type | Amount | Flag | Label |
|---|---|---|---|---|
| 1 | telegraph | — | — | 💢 OVERLOAD |
| 2 | attack_all | 18 | **interruptible** | 💥 SCRAPSTORM 18 |
| 3 | summon | scrap_shard ×1 | — | ☠ SCRAP x1 |
| 4 | heal | 12 | — | ✚ 12 |
| 5 | attack | 16 | — | ⚔ 16 |

> Cancel either Scrapstorm with Shock during the preceding CHARGING / OVERLOAD turn. The phase-2 ENRAGE permanently raises its Strength, and its self-heal can stall an under-tuned deck — race the kill.

### `rust_titan` (HP 75) — boss, floor 4 (act-1), two phases
- Sprite: `battle_scene/assets/images/enemies/rust_titan/`
- JSON: `battle_scene/card_info/enemy/rust_titan.json`
- Bespoke kit: enrages at 50% HP, gaining a big stack of `buff_self` strength_up and a harder phase-2 loop.

**Phase 1 — base `action_pattern` (HP ≥ 50%, loops — 6 actions):**
| # | Type | Amount | Flag | Label |
|---|---|---|---|---|
| 1 | attack | 8 | — | ⚔ 8 |
| 2 | block | 10 | — | 🛡 10 |
| 3 | attack | 12 | — | ⚔ 12 |
| 4 | telegraph | — | — | 💢 WIND-UP |
| 5 | attack | 18 | **interruptible** | 💥 SLAM 18 |
| 6 | block | 8 | — | 🛡 8 |

**Phase 2 — on dropping below 50% HP (`hp_below: 0.5`):**
- `on_enter` (one-shot): `buff_self` strength_up 3 (💢 ENRAGE).
- Then loops a new 5-action pattern:

| # | Type | Amount | Flag | Label |
|---|---|---|---|---|
| 1 | telegraph | — | — | 💢 OVERLOAD |
| 2 | attack | 22 | **interruptible** | 💥 RUIN 22 |
| 3 | block | 12 | — | 🛡 12 |
| 4 | buff_self | strength_up 2 | — | 💢 RAGE +2 |
| 5 | attack | 14 | — | ⚔ 14 |

> Once enraged, its `strength_up` stacks (3 on enter, +2 every cycle) make every attack scale up fast — burst it down rather than out-lasting it. Cancel Ruin with Shock during OVERLOAD.

### `ash_warden` (HP 95) — boss, floor 8 (act-2), two phases
- Sprite: `battle_scene/assets/images/enemies/ash_warden/`
- JSON: `battle_scene/card_info/enemy/ash_warden.json`
- Bespoke kit: stacks heavy Burn / Weak / Vulnerable debuffs and `summon`s `ember_wisp` adds at the phase break.

**Phase 1 — base `action_pattern` (HP ≥ 50%, loops — 7 actions):**
| # | Type | Amount | Status | Flag | Label |
|---|---|---|---|---|---|
| 1 | attack_status | 6 | burn 2 | — | 🔥 6 + B2 |
| 2 | attack_status | 7 | weak 1 | — | ⚔ 7 + W1 |
| 3 | block | 12 | — | — | 🛡 12 |
| 4 | attack_status | 8 | vulnerable 1 | — | ⚔ 8 + V1 |
| 5 | telegraph | — | — | — | 💢 IGNITING |
| 6 | attack | 18 | — | **interruptible** | 💥 BLAST 18 |
| 7 | attack | 9 | — | — | ⚔ 9 |

**Phase 2 — on dropping below 50% HP (`hp_below: 0.5`):**
- `on_enter` (one-shot): summon `ember_wisp` ×1 (☠ EMBER SUMMON).
- Then loops a new 6-action pattern with heavier debuffs and a second summon:

| # | Type | Amount | Status | Label |
|---|---|---|---|---|
| 1 | attack_status | 8 | burn 3 | 🔥 8 + B3 |
| 2 | attack_status | 6 | weak 2 | ⚔ 6 + W2 |
| 3 | attack_status | 9 | vulnerable 2 | ⚔ 9 + V2 |
| 4 | block | 10 | — | 🛡 10 |
| 5 | summon | ember_wisp ×1 | — | ☠ EMBER SUMMON |
| 6 | attack_status | 10 | burn 3 | 🔥 10 + B3 |

> Status-heavy sentinel: stacks Burn + Weak + Vulnerable, then summons Ember Wisps that pile on more Burn. Cancel the phase-1 Blast with Shock during IGNITING; in phase 2 the pressure is the stacking status, not a single big hit.

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
| `summon` | Spawns one or more new enemies mid-fight (the listed adds). | `{type, enemy_ids[] (required), count (optional, default 1), label}` |
| `buff_self` | Applies a status to the acting enemy (e.g. `strength_up` to enrage). | `{type, status (required, ∈ status names), stacks, label}` |

### Action flags
- `interruptible: true` on any attack — if the enemy has ≥1 Shock stack when the action fires, consume 1 Shock and cancel the attack. Used on the action AFTER a telegraph for mortar_cart and the Boss.

### HP-threshold phases (`phases[]`)
- A boss JSON may carry an optional `phases[]` array. Each phase has `hp_below` (fraction, e.g. `0.5`), an optional one-shot `on_enter[]` action list (e.g. summon adds + `buff_self` enrage), and a replacement `action_pattern[]` that loops for the rest of the fight.
- When current HP first drops below `hp_below`, the enemy fires `on_enter` and switches to the phase's `action_pattern`. All three bosses (rust_titan, ash_warden, junkyard_tyrant) use a single 50%-HP phase.
- Killing the boss ends the fight immediately, even if its summoned adds (scrap_shard / ember_wisp) are still alive.

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

- No enemy steals gold (would need `steal_gold` action type and Map-screen feedback).
- Enemy block resets to 0 at the start of each enemy turn (`enemy_entity.start_turn()`). If you want persistent block, that needs a flag.
