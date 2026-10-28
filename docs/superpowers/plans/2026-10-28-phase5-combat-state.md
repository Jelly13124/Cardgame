# Phase 5 Combat State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Combat rules run on data objects (Creature, Piles, CombatState, CombatManager) without a scene tree; nodes only display.

**Architecture:** Strangler order. Data objects first, with the existing nodes delegating their state to them (tests stay green after every task); then the manager takes over the flow and the nodes become views; then files move to `core/combat/` and `ui/battle/`.

**Tech Stack:** Godot 4.6.3 GDScript; tests via `tools/run_tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-10-28-phase5-combat-state-design.md`

## Global Constraints

- Preload by uid with a `# res://path` comment; no new `class_name`; `addons/` untouched.
- `core/` uses no scene tree and no UI path (`python tools/check_layers.py`).
- New scenes/scripts get uids (`tools/assign_scene_uids.gd`, then `--import`); `python tools/godot_refs.py check` clean.
- Gameplay numbers, text, pacing and RNG stream usage unchanged; all existing tests green after every task.
- Every Godot run through `tools/run_tests.ps1` (isolated APPDATA).

## Review Focus

1. Death fires once: a creature killed by a multi-hit card, by Thorns and by Burn in the same action emits `died` once and the fight ends once.
2. Boss death with live adds ends the fight immediately and the adds stop acting.
3. Combat ends while cards wait in the play queue: waiting plays are dropped, cards land in the discard view, no card stays in HOLDING.
4. Reshuffle mid-draw with a second draw requested (relic draw during turn-start draw) never double-draws.
5. Hand view and piles never disagree (counts on the pile icons equal `Piles` sizes after every action).

---

### Task 1: Creature and StatusEffects in core

**Files:** Create `core/combat/creature.gd`, move `battle_scene/status_effect_system.gd` → `core/combat/status_effects.gd` (badges out), create `ui/battle/status_badges_view.gd`; modify `battle_scene/player.gd`, `battle_scene/enemy_entity.gd` to own a `creature` and delegate `health`, `max_health`, `block`, attributes, energy, statuses to it. Test: `tests/creature_test.gd`.

- [ ] Test: damage 10 into 4 block → `{blocked 4, hp_lost 6}`, signals fire, `died` once at 0 HP even when hit again; `lose_hp` ignores block; `heal` caps; player `start_turn` resets block/energy and runs Metallicize after the reset.
- [ ] Implement; nodes keep their public API through property delegation; badges rebuilt by the view on `status_changed`.
- [ ] Full suite green; commit `refactor(combat): creature data object owns HP, block and statuses`.

### Task 2: MonsterMoves and Intents

**Files:** Create `core/combat/monster_moves.gd`, `core/combat/intents.gd`; modify `battle_scene/enemy_entity.gd`. Test: `tests/monster_moves_test.gd`.

- [ ] Test: pattern cycles; ramp uses count; one hit past two thresholds enters only the deepest phase, queues its on_enter and resets the pointer; stun consumes the move.
- [ ] Implement; enemy node delegates; intent text test and parity tests unchanged.
- [ ] Commit `refactor(combat): monster move state machine and intents in core`.

### Task 3: CardInstance and Piles

**Files:** Create `core/combat/card_instance.gd`, `core/combat/card_pile.gd`, `core/combat/piles.gd`; `battle_scene/deck_manager.gd` → `ui/battle/hand_view.gd` mirroring piles. Test: `tests/piles_test.gd`.

- [ ] Test: same seed → same draw order; draw past an empty draw pile reshuffles discard once and emits `reshuffled`; a draw requested during a draw is appended (no double draw); retain cards stay in hand on discard_hand.
- [ ] Implement; card nodes carry `instance`; `_in_play`/`cost_override`/`uid` meta replaced.
- [ ] Commit `refactor(combat): card instances and piles own the deck state`.

### Task 4: CombatState, CombatManager, presenter

**Files:** Create `core/combat/combat_state.gd`, `combat_manager.gd`, `combat_presenter.gd`, `enemy_turn.gd`; move `battle_scene/combat/*` → `core/combat/`, `relic_effect_system.gd` → `core/combat/relic_listeners.gd`; fold `combat_engine.gd`, `turn_manager.gd`, `enemy_ai.gd` into the manager; create `ui/battle/battle_presenter.gd`, `ui/battle/creature_view.gd`; battle scene drives the manager. Tests: `tests/combat_simulation_test.gd`, `tests/rapid_play_test.gd`; update `tests/support/fake_battle.gd` and contract tests.

- [ ] Test (simulation): config with 10-card starter deck vs one `base:trash_robot`, null presenter, seed "SIM1": the fight reaches victory; a second run with the same seed gives the same log; a 1-HP player reaches defeat; no Node is created.
- [ ] Test (rapid play): three Strikes queued in one frame give the same enemy HP and log as three queued one by one.
- [ ] Implement; victory/defeat from state; nodes become views over creatures.
- [ ] Full suite green; commit `refactor(combat): combat state and manager run fights without a scene`.

### Task 5: Directory moves

**Files:** UI files to `ui/battle/` and `ui/battle/card_framework_adapters/`; `card_description.gd`, `data_validator.gd` to `core/content/`; battle scene to `ui/battle/battle_screen.tscn`; update `docs/PROJECT_STRUCTURE.md`.

- [ ] Move with `git mv`, keep uids, rewrite `# res://` comments (`tools/godot_refs.py convert`), layer check clean.
- [ ] Full suite green; commit `refactor(ui): battle presentation lives in ui/battle`.

### Task 6: Playtest

- [ ] Windowed playtest (Cowboy Bill and the polarity hero): play cards, end turns, kill an enemy, win, lose; screenshots `tmp/p5-*.png`; compare with phase 4 behavior.
