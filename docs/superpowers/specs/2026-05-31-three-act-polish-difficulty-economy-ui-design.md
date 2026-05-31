# Three-Act Polish — Difficulty Curve · Economy · UI (A+B)

**Date:** 2026-05-31
**Status:** Design approved, pending spec review
**Scope:** Sub-projects **A** (economy review + act-aware UI) and **B** (per-act
difficulty scaling) of the "Three-Act Polish" epic. Sub-project **C** (bespoke
boss mechanics) is explicitly **out of scope** here and gets its own spec.

## Context

The run map was recently restructured into three self-contained acts
(`feat(map): 3-act structure`, commit `51138b6`). Each act is its own
`FLOORS_PER_ACT`-tall map ending in a single boss
(`ACT_BOSSES = [rust_titan, ash_warden, junkyard_tyrant]`); clearing a non-final
act's boss offers an extract/push choice, the final act's boss wins the run.

That change left three polish gaps this spec closes:

1. **Flat difficulty across acts.** `select_encounter()` tiers the enemy pool by
   *within-act* floor (EARLY ≤3 / MID ≤7 / LATE >7), and enemy stats come
   straight from JSON. So Act 3's floor-2 trash is identical to Act 1's floor-2
   trash — later acts feel no harder except for the boss.
2. **Weak extract-vs-push tension.** Current Core rewards (act1 extract 50 /
   push 25, act2 extract 90 / push 50, final 150) don't separate "bank it safe"
   from "gamble for more" sharply enough.
3. **Acts are invisible in the UI** outside the map top bar. Run history and the
   character panel still speak only in floors.

## Goals

- Later acts are meaningfully harder via **both** tougher enemy stats and
  tougher enemy *types*.
- The extract/push choice carries real weight: pushing deeper always offers a
  higher-but-at-risk payout; extracting banks a slightly lower sure thing.
- Acts are legible everywhere the player reads run state.
- Bosses are untouched here (their power is tuned in sub-project C).

## Non-Goals (out of scope)

- Boss multi-phase / summon / bespoke mechanics → **sub-project C, separate spec.**
- New enemy or card content.
- Any change to the safe-cell / stash / backpack model (shipped, stable).

---

## B — Per-Act Difficulty Scaling

### B1. Stat scaling (HP × and damage ×)

New helper on `RunManager`:

```gdscript
## Per-act enemy stat multipliers. Bosses (ids in ACT_BOSSES) are exempt —
## their power is tuned per-boss in sub-project C, not via this curve.
const ACT_HP_MULT: Array[float] = [1.0, 1.25, 1.5]
const ACT_DMG_MULT: Array[float] = [1.0, 1.15, 1.30]

func act_hp_mult() -> float:
    return ACT_HP_MULT[clampi(current_act - 1, 0, ACT_HP_MULT.size() - 1)]

func act_dmg_mult() -> float:
    return ACT_DMG_MULT[clampi(current_act - 1, 0, ACT_DMG_MULT.size() - 1)]
```

| Act | HP × | Damage × |
|---|---|---|
| 1 | 1.0 | 1.0 |
| 2 | 1.25 | 1.15 |
| 3 | 1.5 | 1.30 |

- **HP**: applied in `enemy_entity.gd` at spawn, **multiplicatively stacked with
  the existing ascension scaling** (`max_health * (1 + 0.1*ascension)` then
  `* act_hp_mult()`). Skip when the spawned `id` is in `RunManager.ACT_BOSSES`.
- **Damage**: applied in `enemy_ai.gd` to the outgoing amount of `attack`,
  `attack_all`, and `attack_status` actions: `outgoing = round(amount * act_dmg_mult())`.
  Skip when the acting enemy's id is a boss (`enemy.enemy_id in ACT_BOSSES`).
  Block/heal amounts are NOT scaled (only offense).

**Boss exemption mechanism:** `EnemyEntity.create(id)` has the id at spawn; gate
the HP multiply on `not (id in RunManager.ACT_BOSSES)`. For damage, `enemy_ai`
reads the acting entity's `enemy_id` (already stored on `EnemyEntity` at
`enemy_entity.gd:24`, set in `create()`) and gates on the same check.

### B2. Enemy-pool offset by act

In `select_encounter(node_type, floor_idx)`, the enemy/unknown branch picks the
pool tier from `floor_idx`. Offset it by act:

```gdscript
const ACT_POOL_OFFSET: int = 4
...
var tier_floor: int = floor_idx + (current_act - 1) * ACT_POOL_OFFSET
if tier_floor <= 3:
    pool = ENCOUNTER_POOLS_EARLY
elif tier_floor <= 7:
    pool = ENCOUNTER_POOLS_MID
else:
    pool = ENCOUNTER_POOLS_LATE
```

Effect: Act 2 enters at the MID pool from its floor 0; Act 3 enters at LATE.
Within an act the pool still climbs with floor. Boss/elite branches unchanged.

---

## A — Economy Review

Re-tune **only** the boss extract/push and final-victory Core values so the
curve separates "safe bank" from "risky gamble." All other Core sources
(elite 8–16, treasure/cache 10–30) are unchanged.

| Node | Current | Proposed |
|---|---|---|
| Act 1 extract (banked immediately) | 50 | **60** |
| Act 1 push-on (into backpack, at death risk) | 25 | **40** |
| Act 2 extract (banked immediately) | 90 | **130** |
| Act 2 push-on (into backpack, at death risk) | 50 | **80** |
| Final boss victory | 150 | **200** |

**Design intent (documented in the constants):**
- *Push-on* Core enters the backpack and is forfeit on death (minus safe cells).
  It is always the larger number at a given act — the gamble pays more if you
  survive to extract/win later.
- *Extract* Core banks to permanent Core immediately — the smaller, guaranteed
  number.
- The deeper the act, the larger both numbers, so a death in Act 3 hurts most.

Implementation: `battle_scene.gd` `EXTRACT_REWARDS` (keyed by act) and
`BOSS_VICTORY_CORE`. No structural change — number edits only.

---

## A — Act-Aware UI

1. **Run history row** (`home_base_scene.gd` + `ui_home.csv` `UI_HOME_RUN_ROW`):
   `{hero}  Floor {floor}  +{core} Core` → include act, e.g.
   `{hero}  Act {act}·F{floor}  +{core} Core`. Reads `summary.act` (already
   written into the run summary by `_teardown_run`). Fallback to act 1 if a
   legacy summary lacks the field.
2. **Character panel vitals** (`UI_EQUIP_VITALS`): prepend the act to the floor
   readout (e.g. `ACT {act} · FLOOR {floor}`). Source: `RunManager.current_act`.
3. **Act-transition toast** (`map_scene.gd`): when the map scene loads on a fresh
   act > 1 (no node visited yet and `current_act > 1`), show a brief popup
   "⟐ ENTERING ACT {n}" via the existing `_show_popup` path. New translation
   key `UI_MAP_ENTER_ACT`.
4. Map top bar `Act: n/3` already shipped in `51138b6` — not repeated here.

---

## Testing

Headless smoke gate (`scripts/smoke_test.sh`) must stay green after every file
touched. Plus a temporary boot scene (`_test_*.tscn`, deleted after) asserting:

- **B1**: a non-boss enemy spawned with `current_act = 2` has
  `round(base_hp * 1.25)` HP; with `current_act = 3`, `* 1.5`. A boss id
  (`rust_titan`) spawned at any act keeps its JSON HP (no act multiply).
- **B1 damage**: `act_dmg_mult()` returns 1.0 / 1.15 / 1.30 for acts 1/2/3.
- **B2**: `select_encounter("enemy", 0)` at act 2 draws from MID; at act 3 from
  LATE (assert via the returned ids being members of the expected pool).
- **A**: `EXTRACT_REWARDS` has the new values; `_extract_rewards_for_act(3)`
  returns `{}` (final act, no extract).
- **A UI**: run summary contains `act`; the formatted history row includes it.

## Risks / Notes

- `act_dmg_mult` rounding: `round()` keeps small attacks meaningful (an 8-dmg
  hit → 9 at act 2). Acceptable.
- Pool offset assumes ENCOUNTER_POOLS_LATE is the intended ceiling; Act 3 floors
  8–11 already used LATE, so no new pool is needed.
- Numbers (multipliers, Core values, pool offset) are first-pass and meant to be
  retuned during playtest; they live in named constants for that reason.
