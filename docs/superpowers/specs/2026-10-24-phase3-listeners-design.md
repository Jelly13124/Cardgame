# Phase 3 — Listener model (STS2 hooks, GDScript subset)

Status: decided by the agent under the owner's delegation ("follow the STS2
architecture as much as possible"). Gameplay must not change.

Roadmap items: S3-02 (closed trigger set, stateless relics), S1-03 (power and
relic behaviour inside the combat core), S1-04 (hand-written turn flow), S3-03
(status definitions scattered), S3-04 (relic entries rebuilt on every
calculation), S6-05 (bounty string events), S6-03 (ascension thresholds).

## Problem

Phase 1 gave combat one hook broadcaster (`core/combat/combat_hooks.gd`) for
damage, block, status stacks and four reactions. The rest is still closed:

- The turn flow in `battle_scene.gd` / `player.gd` calls named systems in a
  fixed order and contains power logic (Metallicize, Feel No Pain, Covering
  Reload, ascension A3 energy).
- `relic_effect_system.gd` rebuilds relic entries on every query, keeps the
  only relic state (`once_per_combat`), and exposes ad-hoc queries
  (`attack_limit_per_turn`, `crit_mult`, `first_attack_auto_crit`, …) that
  callers ask by name.
- A status is defined in six places (colour, label, description, decay list,
  validator list, rule code).
- Crit rules read `all_in`, `deadeye`, `hot_streak`, `overload_protocol` by
  name.
- Bounties count progress through `bounty_event("<string>")` calls spread over
  battle, enemy, run and UI code; ascension levels are numeric thresholds in
  five files.

## STS2 reference

Every model (`PowerModel`, `RelicModel`, …) is an `AbstractModel` with virtual
hooks (`ModifyDamageAdditive`, `AfterSideTurnStart`, `ModifyHandDraw`,
`AfterCardPlayed`, `AfterCardExhausted`, …). `Hook.*` iterates the listeners of
the combat state (creatures' powers, the players' relics, …) at fixed points;
the core never names content. A power is an instance on its creature
(`Amount` = stacks, its own fields); a relic is an instance on the player and
may hold counters. Power metadata (`Type` buff/debuff, `StackType`, vars, icon
from the id) lives on the model. Ascension is a named enum checked where it
applies.

## Design

### Listener base — `core/listeners/listener.gd`

`RefCounted` with `owner` (the creature or null), `hooks` (the broadcaster),
`id` (content id or rule name). Helpers: `commands()`, `alive(creature)`,
`stacks(creature, status)`. Every hook is optional; the broadcaster calls a
listener only for methods it defines (`has_method`, as today). Subclasses live
under `core/listeners/` (rules, statuses, relics, sets, ascension, bounty).

### Hook set — `core/combat/combat_hooks.gd`

Kept: `modify_damage_additive / _multiplicative / _reduction / _cap`,
`modify_block_additive / _multiplicative`, `modify_status_stacks`,
`after_damage_given / _received`, `after_attack`, `after_block_gained`.

New value hooks (each receives a small calc with `value` and context fields,
see `core/combat/hook_value.gd`):

| Hook | Replaces |
|---|---|
| `modify_hand_draw(calc)` (value 3 or first-round count) | `deck_manager.draw_cards(3)` literal |
| `modify_turn_energy(calc)` | A3 `player.pay_energy(1)` in battle_scene |
| `modify_attack_limit(calc)` (0 = no cap; `calc.round`) | `attack_limit_per_turn` + `first_turn_bonus_allowance` |
| `modify_attack_replays(calc)` | `attack_replay_bonus` |
| `modify_crit_multiplier(calc)` | `crit_mult` + All In's 2.0 |
| `should_force_crit(calc) -> bool` (first `true` wins; the listener queues its own spend) | `first_attack_auto_crit` + Deadeye |
| `can_crit_overload(calc) -> bool` | Overload Protocol check |

New reactions (may be coroutines, dispatched in listener order):

| Hook | Called from |
|---|---|
| `before_combat_start()` | battle start (set Block, relic battle-start stats) |
| `after_turn_start(side, round)` | after draw-independent turn setup (relic/set turn effects, Metallicize) |
| `after_turn_end(side)` | turn end (intangible decay stays in the status container) |
| `after_card_played(play)` | card resolved (bounty "play attack cards") |
| `after_card_exhausted(card)` | Exhaust (Feel No Pain) |
| `after_reload(source)` | `restore_attack_allowance` (Covering Reload) |
| `after_crit(calc)` / `after_non_crit(calc)` | crit commit (Hot Streak, All In's Loaded, Ricochet Loader) |
| `after_combat_victory()` | victory (relic heal / gold, bounty kill counts) |

Listener order (stable, documented in combat_hooks): rule listeners
(attribute, crit core), status listeners of every live creature (player first,
then enemies in container order, each in status-application order), relic
listeners in `RunManager.relics` order, equipment-set listener, ascension
listener. This keeps the current order of reactions (status rules ran before
relics).

`combat_hooks` gets its listeners from a provider callable set by the battle,
so status listeners that appear or vanish mid-combat are seen without
re-registration (STS2 `IterateHookListeners`).

### Statuses

- New ModelDb category `status`, dir `content/statuses/`, one JSON per status
  (19 today): `id`, `kind` (`buff|debuff`), `decay` (`turn_end` = −1 at its
  owner's turn end, `opponent_turn_end` = −1 when the opponent's turn ends,
  `none`), `color` (`#rrggbb`), `label` (fallback glyph), `description`
  (English fallback for `UI_COMBAT_STATUS_<KEY>_DESC`), optional `script`
  (`res://` path of its listener) and optional `vars` (e.g. Weak `mult: 0.5`).
- Runtime status keys stay the key entry of the id (`MODEL_ID.key_entry`), so
  base keys are the existing bare names (`weak`) and every card/enemy JSON and
  stack dictionary is unchanged; a mod status would be `<ns>_<entry>`.
- `StatusEffectSystem` keeps storage and badge UI but reads colour, label,
  description and decay from the definition (its four constant tables and
  `TURN_END_DECAY` are deleted). When a status first gains stacks it creates
  that status's listener instance (if the definition has `script`) with
  `owner` = the creature; the instance is dropped when stacks reach 0.
- Status behaviour moves from `status_rules.gd` / `crit_rules.gd` /
  `battle_scene.gd` / `player.gd` into `core/listeners/statuses/<key>.gd`:
  weak, vulnerable, frail, intangible (cap), thorns (incl. the Arc Spines relic
  check through a hook query `thorns_apply_short_circuit`), reactive_plating,
  burn and regen (owner turn start), metallicize, feel_no_pain,
  covering_reload, hot_streak, all_in, deadeye, overload_protocol.
  `status_rules.gd` is deleted; `crit_rules.gd` keeps only the roll, the
  multiplier pipeline and preview semantics.
- `DataValidator.ALLOWED_STATUS_NAMES` is derived from the `status` category.

### Relics — `core/listeners/data_relic.gd`

- At battle start one listener instance is built per held relic (S3-04: no
  per-query rebuild). `data_relic.gd` maps each JSON effect's `trigger` to the
  hooks above, exactly reproducing today's behaviour, and keeps instance state
  (`used_once`, and a generic `counters` dictionary for scripts).
- Escape hatch: a relic JSON may name `"script": "res://…"`; that script
  (extending `data_relic.gd` or `listener.gd`) is instantiated instead. The
  validator checks the path exists.
- `relic_effect_system.gd` is reduced to building and registering relic
  listeners; its query methods are deleted, callers use the value hooks.
- Proof (spec acceptance): a test injects a fixture relic "every third attack
  card grants 3 Block" as data + a 15-line script through `ModelDb.inject_dir`
  and sees it trigger on the 3rd and 6th attack.

### Equipment sets — `core/listeners/equipment_set.gd`

`battle_scene/equipment_set_system.gd` moves to `core/listeners/` as a listener
using `before_combat_start` and `after_turn_start`; behaviour unchanged.

### Ascension — `content/ascension/`

- ModelDb category `ascension`: one JSON per level (`a1_tough_enemies` … with
  `level`, `params`, title/description keys). `RunManager.has_ascension(id)` and
  `ascension_param(id, key)` replace the numeric checks in `enemy_entity.gd`,
  `run_manager.gd` (×3), `battle_scene.gd` and `shop_scene.gd`.
- The A3 first-turn energy penalty becomes an ascension listener using
  `modify_turn_energy`.

### Bounties — run events

- `RunManager.bounty_event("<string>")` calls are replaced by typed
  emitters owned by the code that changes run state: `enemy_killed(enemy)`,
  `card_played(card_info)`, `card_upgraded(card_id)`, `gold_earned(n)`,
  `run_extracted()`; they broadcast to run listeners (`core/listeners/bounty_tracker.gd`).
  The tracker maps objective types to these events; the validator derives the
  objective list from the tracker. The UI no longer reports bounty progress
  (`card_upgrade_modal.gd` calls `RunManager.upgrade_card`, which emits).

### Acceptance

- `battle_scene.gd`, `combat_engine.gd`, `player.gd` contain no status or relic
  id string except `bullet` (the attack-allowance badge, a UI mirror); a test
  scans for every status key and relic entry.
- Every existing test passes unchanged in meaning (preview parity, crit,
  gunslinger, scrap guard, short circuit, intangible, combat flow).
- The fixture relic test above passes.

## Out of scope

Rules/presentation split and a combat state object (phase 5), act data
(phase 6), persistent per-run relic counters across combats, new content.

## Risks

Crit preview semantics (forced crits shown once per preview play, never a
random crit) and reaction order are the most fragile parts; the preview parity
and crit tests pin them, and the listener order above preserves today's order.
