# Phase 5: Rules/Presentation Split and the Combat State Object

Roadmap: `docs/reviews/sts2-architecture-review/10-roadmap.md` §阶段 5. Findings: S1-05, S1-06,
S1-08, S4-06, S7-01. Decisions were delegated by the user ("you decide everything, follow the
STS2 code structure"); mod loading (phase 8) is out of scope.

## Goal

Combat rules run without a scene tree. A combat is a data object (`CombatState`) driven by a
manager (`CombatManager`); creatures, cards and piles are data; nodes only display them and
play animations. Gameplay, numbers, text and pacing stay exactly as they are.

## STS2 mapping

| STS2 | Here |
|---|---|
| `Core.Entities.Creatures.Creature` | `core/combat/creature.gd` |
| `Core.Entities.Powers` / `PowerModel` set on a creature | `core/combat/status_effects.gd` (moved `StatusEffectSystem`, rules only) |
| `Core.MonsterMoves.MonsterMoveStateMachine` | `core/combat/monster_moves.gd` |
| `Core.MonsterMoves.Intents` | `core/combat/intents.gd` (intent damage + generated intent text) |
| `CardModel` runtime instance | `core/combat/card_instance.gd` |
| `Core.Entities.Cards.CardPile` | `core/combat/card_pile.gd` |
| `PlayerCombatState` piles + `CardPileCmd` draw/shuffle | `core/combat/piles.gd` |
| `Core.Combat.CombatState` | `core/combat/combat_state.gd` |
| `Core.Combat.CombatManager` (+ turn flow) | `core/combat/combat_manager.gd`, `core/combat/enemy_turn.gd` |
| `Core.Commands` (`CreatureCmd`, …) | `core/combat/combat_commands.gd` (moved) |
| `TestMode.IsOn` skipping animation | `core/combat/combat_presenter.gd` (null presenter: every call returns at once) |
| `Core.Nodes.Combat` / `Core.Nodes.Rooms.NCombatRoom` | `ui/battle/` (`battle_screen`, `battle_presenter`, `creature_view`, …) |

## Core layer (`core/combat/`, RefCounted, no scene tree, no UI paths)

- **Creature**: `side` ("player"/"enemy"), `model_id`, `display_name`, `max_health`, `health`,
  `block`, attributes (`strength`, `constitution`, `intelligence`, `luck`, `charm`),
  `status_system`, `is_elite`, `is_boss`. Player-only: `energy`, `max_energy`, polarity state,
  temporary Strength. Enemy-only: `moves` (MonsterMoves), breakable armor.
  Signals: `health_changed`, `block_changed`, `energy_changed`, `stats_changed`,
  `status_changed`, `intent_changed`, `died`. State changes are synchronous:
  `apply_damage(amount) -> Dictionary{blocked, hp_lost, killed}`, `lose_hp`, `heal`,
  `add_block`, `add_status`, `start_turn`, `end_turn`. `died` fires exactly once.
  Kill gold and bounty events leave the creature (run concerns, see Battle screen).
- **StatusEffects**: today's `StatusEffectSystem` minus the badge UI; it emits
  `status_changed` through its owner instead of rebuilding badges.
- **MonsterMoves**: action pattern, pointer, ramp uses, HP-threshold phases, queued on-enter
  actions; `peek()`, `consume()`, `check_phases(health, max_health)`.
- **Intents**: the intent damage preview and the generated intent text move here from
  `enemy_entity.gd` unchanged.
- **CardInstance**: `model_id`, `uid` (run deck uid or ""), `upgraded`, `info` (resolved card
  dictionary), `cost_override` (-1 = none), `in_play`. Replaces node meta.
- **CardPile / Piles**: `draw`, `hand`, `discard`, `exhaust` arrays of CardInstance.
  `Piles.draw(n)` reshuffles the discard into the draw pile with the run `shuffle` stream when
  needed; every move emits `card_moved(card, from, to)` and a reshuffle emits `reshuffled`.
- **CombatState**: player creature, enemies (in field order), piles, round, side to act,
  attack counters, attack allowance, gold-effect triggers, `encounter_has_boss`, `outcome`
  ("" / "victory" / "defeat"). Victory and defeat are decided from this state (S4-06): a boss
  death or the last enemy death ends the fight the moment it happens.
- **CombatManager**: owns state, hooks, commands, effect registry, action queue, presenter.
  `setup(config)`, `start()`, `play_card(card, target) -> bool` (validation, energy, queueing),
  `use_tool(...)`, `end_turn()`, enemy turn via `enemy_turn.gd`. It is the `services` object
  effects receive (replaces the battle scene). Signals for the room: `combat_ended(outcome)`,
  `card_played(card)`, `enemy_died(creature)`, `creature_added(creature)`, `round_changed`,
  `turn_started(side)`, `hand_changed`.
- **Presenter** (`combat_presenter.gd`): every await the rules make for pacing or animation
  goes through it (`wait`, `notify`, `sfx`, `card_windup`, `hit`, `pulse`, `enemy_attack_anim`,
  `death`, `reshuffle`, `discover`, …). The base class is the null presenter used headless.
- Moved into core unchanged in behavior: `combat_commands.gd`, `combat_effects.gd`,
  `effect_catalog.gd`, `relic_effect_system.gd` (`relic_listeners.gd`), `card_description.gd`
  and `data_validator.gd` (both to `core/content/`). Effect handlers reach animation and audio
  only through the presenter.

## Presentation layer (`ui/battle/`)

- `battle_screen.gd` + `battle_screen.tscn` (the old battle scene): builds the manager from
  RunManager, input, targeting, HUD, and room routing after combat (rewards stay here until
  phase 6). Bridges run concerns: card codex/bounty on `card_played`, kill gold and
  `enemy_killed` on `enemy_died`.
- `battle_presenter.gd`: implements the presenter with the existing animations (gunshot,
  shared hit feedback controller, pulses, card flights, notifications, discover modal).
- `creature_view.gd` (player and enemy views), `intent_view.gd`, `status_badges_view.gd`,
  health HUD: subscribe to creature signals (S7-01). Enemy views free themselves after death.
- `hand_view.gd` (from `deck_manager.gd`): mirrors piles into the card-framework containers;
  each card node is bound to its CardInstance.
- Moves: `play_card`, `card_animator`, `combat_fx`, `combat_feedback_controller`,
  `targeting_arrow`, `battle_ui_manager`, `discover_modal`, `battle_scene/ui/*` → `ui/battle/`;
  `card_play_zone`, `no_reorder_hand`, `cached_card_factory` →
  `ui/battle/card_framework_adapters/`. Scenes move with their scripts (uids unchanged).
  `battle_scene/` keeps only `assets/`.

## Ordering (S1-06)

Card plays, tool uses and End Turn are queued actions (existing `action_queue.gd`); the next
starts only when the previous resolution finished. Animations may overlap (cards waiting in
the play zone), resolution does not.

## Testing

- New `tests/combat_simulation_test.gd`: builds a CombatManager from a config (deck, player
  stats, encounter) with the null presenter, plays a full fight to victory and to defeat with
  no battle scene and no nodes; the same seed yields the same log twice.
- New rapid-play test: three plays queued in one frame resolve in order with the same result
  as three plays made one by one.
- New unit tests for Creature (damage/block/death once), MonsterMoves (phases), Piles
  (draw/reshuffle determinism).
- Existing contract, golden, victory and UI tests keep passing (updated for moved paths and the
  `services` object). Playtest with screenshots: a full Act 1 fight with both heroes.

## Out of scope

Rewards/routing out of the battle (phase 6), RunState/ProfileState (phase 7), mod loading.
