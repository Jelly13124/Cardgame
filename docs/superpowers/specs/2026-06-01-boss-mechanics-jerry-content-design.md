# Combat Depth Night — Boss Mechanics · Jerry's Kit · Attribute Content (design)

**Date:** 2026-06-01
**Status:** Locked by owner for an autonomous overnight build (directions 1+2+3,
medium intensity). Numbers are first-pass and live in JSON / named constants.
**Owner decisions:** do all three (A bosses, B Jerry, C content); medium scope;
boss depth = bespoke mechanics (summon / enrage / gimmick) — chosen earlier.
**Priority if cut short:** A (bosses) first, then B (Jerry), then C (content).

## Context

Three acts each end in a boss (`ACT_BOSSES = [rust_titan, ash_warden,
junkyard_tyrant]`), but bosses use flat cycling `action_pattern`s — no phases, no
signature mechanics. Two heroes exist (`cowboy_bill`, `hero_jerry_killer`) but
Jerry has no distinct kit. The luck/charm attribute + crit + event systems
shipped, but little content leans on them.

Verified facts this builds on:
- `enemy_ai._execute_action()` supports actions: `attack`, `attack_status`,
  `attack_all`, `block`, `heal`, `telegraph`. (No summon/self-buff yet.)
- Combat already supports multiple enemies: `enemy_ai.spawn_enemy_units()` adds
  EnemyEntity children to `enemy_container`; `_on_enemy_died()` declares victory
  when `enemy_container.get_child_count() == 0`.
- Relic triggers in `relic_effect_system.gd`: `player_turn_start`,
  `player_attack_damage`, `enemy_attack_damage`, `combat_victory`. `combat_victory`
  already handles `heal` + `gain_gold` (no new hook needed for Jerry).
- Card effect `scaling` field: `combat_engine._apply_effect` does
  `amount += int(player.get(scaling))` for any attribute incl. `luck`/`charm`.
  So luck/charm-scaling cards are pure JSON.
- `validate_event`, `ALLOWED_ENEMY_ACTION_TYPES`, `INITIAL_CARD_POOL` are the
  registration points.

## Non-Goals
- New ART (ADR-0005 — Codex). New enemies/relics/cards reference paths; missing
  art falls back. Flag a Codex art contract as follow-up; do not hand-author PNGs.
- No new card *effect types* for content (reuse existing + `scaling`). New ENEMY
  action types (summon/buff_self) ARE added (bosses need them).
- No balance overhaul of existing content.

---

## A. Boss bespoke mechanics (sub-project C)

### A1. New enemy action types
Add to `enemy_ai._execute_action()` match + `ALLOWED_ENEMY_ACTION_TYPES`:

- **`summon`** — `{"type":"summon","enemy_ids":["scrap_shard"],"count":2,"label":"☠ SUMMON"}`.
  Spawns `count` adds (cycling through `enemy_ids`) via a new
  `enemy_ai.spawn_summon(enemy_id)` that instantiates an EnemyEntity, positions it,
  `add_child` to `enemy_container`, connects `died → _on_enemy_died`. Cap the field
  at `MAX_ENEMIES_ON_FIELD = 4` (skip spawns beyond the cap). Summoned adds are NOT
  act-scaled bosses, so normal scaling applies.
- **`buff_self`** — `{"type":"buff_self","status":"strength_up","stacks":3,"label":"💪 ENRAGE"}`.
  Applies a status to the acting enemy itself: `enemy.add_status(status, stacks)`.
  Allowed self-statuses: `strength_up` (ramps its attacks), `block`-like handled
  via existing `block` action (not here). Validate `status` ∈ ALLOWED_STATUS_NAMES.

`summon`/`buff_self` join `STATUS_BEARING_ACTIONS`? No — only `attack_status` needs
a player `status`. `buff_self` needs `status` too → add a validator check that
`buff_self` has a `status` in ALLOWED_STATUS_NAMES; `summon` requires non-empty
`enemy_ids` whose ids resolve to enemy JSON (validate in `validate_encounter_pools`
style or in `validate_enemy`).

### A2. Phase system
Enemy JSON gains an optional `phases` array:
```json
"phases": [
  { "hp_below": 0.5,
    "on_enter": [ {"type":"buff_self","status":"strength_up","stacks":3,"label":"💢 ENRAGE"} ],
    "action_pattern": [ ... phase-2 moves ... ] }
]
```
Mechanism (in `enemy_entity.gd`, checked after the entity takes damage): when
current HP first drops below `hp_below * max_health` for a phase not yet entered,
(a) run its `on_enter` actions once (route through `enemy_ai._execute_action`
or apply directly), (b) replace the entity's live `action_pattern` with the
phase's, resetting the action pointer. Track `_entered_phases` to fire once.
Multiple phases allowed (ordered by descending `hp_below`; enter the deepest
crossed). Non-boss enemies may use phases too, but only bosses ship with them.

Validator: if `phases` present, each entry needs `hp_below` (0–1) +
`action_pattern`; `on_enter` optional; actions validated like `action_pattern`.

### A3. Boss-death ends the fight
A boss dying should win the combat even if summoned adds remain. Mark bosses:
`enemy_entity` exposes `is_boss` = `enemy_id in RunManager.ACT_BOSSES` (or a JSON
`"boss": true`). In `enemy_ai._on_enemy_died()`, if the died entity was a boss (or
no boss remains AND field empty), free remaining adds and `declare_victory()`.
Simplest robust rule: when ANY boss entity dies, queue_free all other enemies then
declare victory. (Bosses are always solo-spawned at act top, so "a boss died" =
"the act boss died".)

### A4. Summoned add enemies (new content JSON)
Create small adds in `battle_scene/card_info/enemy/`:
- `scrap_shard` — ~10 HP, `attack 4` pattern. (Junkyard Tyrant's minions.)
- `ember_wisp` — ~8 HP, `attack_status 3 + burn`. (Ash Warden's adds.)
These are summon-only (NOT added to encounter pools).

### A5. Three boss kits (rewrite their JSON)
- **rust_titan (Act 1) — Enrage Bruiser.** Base: block/attack/telegraph/slam cycle
  (current). `phases`: at `hp_below 0.5`, `on_enter` buff_self strength_up 3;
  phase-2 pattern = faster telegraph→big-slam + block, hits harder via the stacked
  strength. No summons. Teaches "burst before enrage."
- **ash_warden (Act 2) — Attrition Debuffer.** Base: `attack_status` (weak /
  vulnerable / burn) + block. `phases`: at 0.5, `on_enter` summon `ember_wisp` x1;
  phase-2 = heavier burn/weak + periodic re-summon. Identity: status pressure.
- **junkyard_tyrant (Act 3, final) — Summoner King.** Base: attack + early summon
  `scrap_shard` x1, attack_all telegraph. `phases`: at 0.5, `on_enter` summon
  `scrap_shard` x2 + buff_self strength_up 2; phase-2 = attack_all nuke + summon +
  heal. The finale board-control fight.

Bosses keep their own HP (act scaling already exempts ACT_BOSSES).

---

## B. Jerry's distinct kit

`hero_jerry_killer.json` gets a distinct identity: **aggressive executioner who
profits from kills** (contrast: Bill = luck/crit).

- **Starting relic** `bounty_tags` (NEW relic JSON, ZERO new code — uses the
  existing `combat_victory` trigger which already supports `heal` + `gain_gold`):
  `{"trigger":"combat_victory","type":"gain_gold","amount":12}` +
  `{"trigger":"combat_victory","type":"heal","amount":3}`. "Every kill pays and
  patches you up." Set `hero_jerry_killer.json` `"starting_relic":"bounty_tags"`.
- **Starter deck**: strike-heavy aggression from EXISTING cards — e.g.
  `["strike","strike","strike","strike","double_tap","scrap_strike","defend","defend","brace"]`
  (more attacks + a multi-hit, less block than Bill). Pick from the existing 60.
- **Starting attributes**: `{strength:5, constitution:3, intelligence:2, luck:2,
  charm:3}` (high STR, low LUCK — opposite of Bill's crit lean).
- No engine changes; pure JSON + the new relic. Verified: `start_new_run` already
  grants `starting_relic`; `validate_hero` has no unknown-key block.

---

## C. Attribute-leaning content

All new cards use EXISTING effect types + the `scaling` field (no engine/validator
changes for cards). New cards must be added to `MetaProgress.INITIAL_CARD_POOL`
(the draft/loot pool) to appear in-game — that is the wiring step.

### C1. New cards (~5; ids + JSON + pool wiring + zh names)
- `lucky_shot` — attack, common: `deal_damage 4, scaling:"luck"` (damage grows
  with luck). Crit-synergy with Bill.
- `silver_tongue` — skill, common: `apply_status weak 2, scaling:"charm"` (charm
  deepens the debuff) + minor block.
- `gunslinger` — attack, uncommon: `deal_damage 6` + `draw_cards 1` (aggression).
- `windfall` — skill, uncommon: `gain_block 4, scaling:"luck"` + draw 1.
- `executioner` — attack, rare: `deal_damage 9, scaling:"strength"` (Jerry/STR
  payoff). 
(Final per-card numbers tuned by the implementer against content-balance norms;
these are starting points. Each needs CARD_<id>_TITLE/DESC zh in a translations
CSV following the existing card-translation key convention, English JSON fallback.)

### C2. New relics (~2; existing triggers only)
- `rabbits_foot` — common, `combat_victory → gain_gold 6` flavored as luck (cheap
  econ; pairs with luck build).
- `adrenaline_pump` — uncommon, `player_turn_start (round 1) → gain_energy 1`
  (reuses the existing player_turn_start `gain_energy` arm). Aggro tempo.
No new relic code (both use existing trigger+type arms).

### C3. New events (~2; + zh)
Two more `random_events/*.json` following the existing schema (one charm-gated
option, one luck_check), e.g. `mutant_bazaar` (charm haggle) and `fortune_shrine`
(luck gamble). Add their `EVENT_<ID>_*` rows to `ui_events.csv` (en+zh) so they
render Chinese like the existing four.

---

## Testing
Per phase: temp headless boot-scene logic tests + `scripts/smoke_test.sh` green
before commit (never commit red). Key tests:
- A1: `summon` adds an EnemyEntity to the container (count grows, capped at 4);
  `buff_self` adds the status to the acting enemy.
- A2: an entity with `phases` swaps its `action_pattern` + runs `on_enter` once
  when HP first crosses `hp_below`; doesn't re-fire.
- A3: when a boss EnemyEntity dies with adds present, victory is declared and adds
  are freed.
- A4/A5: the new add + reworked boss JSON pass DataValidator (incl. new action
  types); `select_encounter("boss")` still returns the act boss.
- B: `start_new_run("hero_jerry_killer")` grants `bounty_tags`, loads Jerry's deck
  + attributes (STR 5).
- C1: new cards pass validation, are in INITIAL_CARD_POOL, and a `scaling:"luck"`
  card's damage rises with luck (assert via combat_engine.calculate or _apply).
- C2/C3: relics + events pass validation; events resolve; zh keys resolve.

A battle headless smoke (boot battle_scene with a boss encounter, run a few
frames) confirms summon/phase paths don't push_error.

## Build order (priority)
A1 → A2 → A3 → A4 (adds) interleaved with A5 (kits) → B (Jerry) → C1 → C2 → C3 →
integration review. A is highest value; B and C are independent of each other and
of A's internals (only depend on shipped systems).

## Risks / notes
- Summon + victory interaction: ensure `_on_enemy_died` boss-death rule frees adds
  BEFORE the count check, and that summoning during the boss turn can't deadlock
  the turn loop (spawn between actions, not mid-iteration of the same array).
- Phase transition must fire from the damage path (after `take_damage`), guarded
  so it triggers at most once per phase and not during death resolution.
- New cards in INITIAL_CARD_POOL slightly dilute the draft pool — acceptable;
  numbers are first-pass for a tuning pass later.
- Missing art for new adds/relics/cards → placeholder/letter fallback (rule 5).
