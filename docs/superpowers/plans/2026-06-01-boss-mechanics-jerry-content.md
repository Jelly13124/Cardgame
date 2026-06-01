# Combat-Depth Night Implementation Plan (bosses · Jerry · content)

> Autonomous overnight build. Exact behavior + decisions live in the spec
> `docs/superpowers/specs/2026-06-01-boss-mechanics-jerry-content-design.md` —
> each phase references its spec section. Every phase: write a temp headless
> boot-test (where logic exists) → see it fail → implement per spec → see it pass
> → `scripts/smoke_test.sh` green → delete temp test → commit. NEVER commit if
> smoke is red. Two-place rule: a new enemy action type registers in BOTH
> `enemy_ai._execute_action` AND `data_validator.ALLOWED_ENEMY_ACTION_TYPES`.

**Tech:** Godot 4.6 / GDScript. Godot bin `"C:/Program Files/Godot/Godot.exe"`.
Smoke: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`.
Rules: `class_name` banned (preload); never touch addons/`*.import`/`*.uid`/
generated_sheet; CSV edits need `--headless --import` before testing; no
hand-authored PNGs (missing art falls back). Mixed commits with Codex WIP OK.

**Priority (cut-short order):** A (P1-P4) → B (P5) → C (P6-P7) → review (P8).

---

## Phase 1 — New enemy actions: summon + buff_self  (spec A1)
- **Files:** `battle_scene/enemy_ai.gd` (add `summon`/`buff_self` arms to
  `_execute_action`; add `spawn_summon(enemy_id)`; `const MAX_ENEMIES_ON_FIELD := 4`),
  `battle_scene/data_validator.gd` (`ALLOWED_ENEMY_ACTION_TYPES` += summon,
  buff_self; validate their params: summon→non-empty `enemy_ids`, buff_self→
  `status` ∈ ALLOWED_STATUS_NAMES).
- **Test:** temp battle-context test — instance enemy_ai/battle? Simplest: unit-test
  the validator accepts/rejects the new actions, and assert ALLOWED list contains
  them. Summon spawn behavior is exercised by the battle-boot test in P8 (needs a
  live scene). Smoke green.
- **Commit:** `feat(enemy): summon + buff_self enemy actions (+ validator)`

## Phase 2 — Phase-transition system  (spec A2)
- **Files:** `battle_scene/enemy_entity.gd` (optional `phases` parsed from JSON;
  after `take_damage`, when HP first crosses a phase `hp_below`, run `on_enter`
  once + swap live `action_pattern`, reset pointer, track `_entered_phases`),
  `battle_scene/data_validator.gd` (`validate_enemy`: if `phases` present, each
  needs `hp_below`∈(0,1] + `action_pattern`; `on_enter` optional; validate nested
  actions like action_pattern).
- **Test:** temp test builds an EnemyEntity from an inline JSON with a phase, deals
  damage past the threshold, asserts the active pattern swapped and a `_entered_phases`
  flag set, and that a second crossing does not re-fire. Smoke green.
- **Commit:** `feat(enemy): HP-threshold phase transitions (phases field)`

## Phase 3 — Boss-death ends fight + summon-add enemies  (spec A3, A4)
- **Files:** `battle_scene/enemy_entity.gd` (`is_boss` = enemy_id in
  RunManager.ACT_BOSSES), `battle_scene/enemy_ai.gd` (`_on_enemy_died`: if a boss
  died, free remaining adds then `declare_victory`), create
  `battle_scene/card_info/enemy/scrap_shard.json` (~10 HP, attack 4) +
  `battle_scene/card_info/enemy/ember_wisp.json` (~8 HP, attack_status 3 + burn).
- **Test:** temp test: spawn a boss + an add, kill the boss entity, assert victory
  declared + add freed. New add JSON pass DataValidator. Smoke green.
- **Commit:** `feat(boss): boss death ends the fight + scrap_shard/ember_wisp adds`

## Phase 4 — Three boss kits  (spec A5)
- **Files:** rewrite `battle_scene/card_info/enemy/{rust_titan,ash_warden,junkyard_tyrant}.json`
  with `phases` + new actions per spec (rust=enrage, ash=debuff+summon ember_wisp,
  tyrant=summon scrap_shard + attack_all + heal).
- **Test:** all three validate (incl. new actions/phases); `select_encounter("boss")`
  returns the act boss; a headless battle boot vs each boss runs a few frames with
  no SCRIPT ERROR/push_error (the summon/phase paths fire). Smoke green.
- **Commit:** `content(boss): enrage rust_titan, debuffer ash_warden, summoner junkyard_tyrant`

## Phase 5 — Jerry's kit  (spec B)
- **Files:** create `run_system/data/relics/bounty_tags.json` (combat_victory →
  gain_gold 12 + heal 3; ZERO new code), edit `run_system/data/heroes/hero_jerry_killer.json`
  (`starting_relic":"bounty_tags"`, aggressive `starter_deck`, `starting_attributes`
  STR5/CON3/INT2/LUCK2/CHA3). Optional zh name for the relic.
- **Test:** `start_new_run("hero_jerry_killer")` → RunManager.relics contains
  `bounty_tags`; base_attributes.strength == 5; deck loaded from Jerry's list.
  bounty_tags validates. Smoke green.
- **Commit:** `feat(hero): Jerry — bounty_tags relic + aggressive high-STR kit`

## Phase 6 — Attribute-scaling cards  (spec C1)
- **Files:** create ~5 cards in `battle_scene/card_info/player/`
  (`lucky_shot`, `silver_tongue`, `gunslinger`, `windfall`, `executioner`) using
  EXISTING effect types + `scaling` (luck/charm/strength); add their ids to
  `run_system/core/meta_progress.gd` `INITIAL_CARD_POOL`; add CARD_<id>_TITLE/DESC
  rows (en+zh) to the card translations CSV (match existing card-key convention).
- **Test:** all 5 validate; each id present in INITIAL_CARD_POOL; a `scaling:"luck"`
  card's resolved damage increases when luck is raised (assert via
  combat_engine.calculate_attack_damage or _apply_effect with a stub). zh names
  resolve after reimport. Smoke green.
- **Commit:** `content(cards): 5 luck/charm/str-scaling cards + pool wiring + zh`

## Phase 7 — New relics + events  (spec C2, C3)
- **Files:** create `run_system/data/relics/{rabbits_foot,adrenaline_pump}.json`
  (existing triggers only: combat_victory gain_gold / player_turn_start round-1
  gain_energy); create 2 `run_system/data/random_events/*.json` (one charm-gated,
  one luck_check); add their `EVENT_<ID>_*` rows (en+zh) to `ui_events.csv`.
- **Test:** relics + events validate; `pick_random_event` count grows; an event's
  charm gate + luck_check resolve via RunManager; zh resolves. Smoke green.
- **Commit:** `content: rabbits_foot/adrenaline_pump relics + 2 events (zh)`

## Phase 8 — Integration review + battle boot
- Verify (read real code): summon/buff_self registered in BOTH places; phase
  transition fires once from the damage path and not during death; boss-death frees
  adds before the count check; Jerry grant fires only for his hero; new cards in the
  pool; scaling cards read the attribute; no new card effect types leaked into the
  engine without validator entries; DataValidator passes with all new content.
- Run a headless battle boot against each act boss (set RunManager.current_encounter
  + start_new_run, change to battle_scene, run ~3s) and grep for SCRIPT ERROR /
  push_error — must be clean. Fix Critical/Important inline (re-smoke), commit fixes.
- **Commit (if fixes):** `fix(combat-depth): <what>`

---

## Morning manual playtest
- Fight each act boss: rust_titan enrages at half HP (hits harder); ash_warden
  stacks debuffs + summons an ember; junkyard_tyrant floods scrap_shards + AOE.
  Killing the boss ends the fight even with adds alive.
- Play Jerry: starts with bounty_tags (gold+heal on win), high STR, aggressive deck.
- See the new cards in drafts/shop; `lucky_shot` hits harder at high luck;
  `silver_tongue` weak deepens with charm. New relics + 2 new events appear.
