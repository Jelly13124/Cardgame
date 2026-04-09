---
name: code-review
description: Perform a structured code review of the Slay the Spire-style card game project
---

# Code Review

## Overview
Performs a structured review against the current STS-style architecture. Checks for correctness, extensibility, and integration health between the battle system, run system, and card framework.

---

## Review Checklist

### 1. Card Play Flow
- [ ] `play_card.gd` routes attack cards to `start_spell_targeting()`, skill/ability to drag zone
- [ ] `is_resolving` lock in `battle_scene.gd` prevents double-firing during `await`
- [ ] `CardPlayZone.move_cards()` passes `null` target to `play_spell()` for skills
- [ ] Discard happens AFTER `resolve_card_effect()` completes (not before)
- [ ] End-of-turn uses `discard_pile.move_cards(remaining)` (not `add_card` loop)

### 2. Combat Engine (Data-Driven)
- [ ] All card effects resolved via `effects[]` array in JSON — no card-specific GDScript
- [ ] `"scaling"` field correctly maps to player attribute (`strength`, `defense`, etc.)
- [ ] Legacy fallback only fires for cards missing `effects[]` array
- [ ] New effect types are added only in `CombatEngine._apply_effect()` match block

### 3. Enemy System
- [ ] Enemy loaded via `EnemyEntity.create("id")` reading JSON from `card_info/enemy/`
- [ ] `action_pattern` cycles correctly (no index overflow)
- [ ] Intent label updates after each `consume_next_action()` call
- [ ] `_on_enemy_died()` only emits `victory_declared` when container is empty (check count, not signals)
- [ ] Multiple enemies offset by 130px — verify they don't overlap with Player at `x=400`

### 4. Turn & Energy Management
- [ ] `TurnManager` emits `turn_started`, `turn_ended`, `round_changed`, `energy_changed`
- [ ] `player.start_turn()` resets block AND energy at start of player turn
- [ ] `enemy.start_turn()` resets enemy block at start of enemy turn
- [ ] Draw count is exactly 3 per round (both `first_round_draw` and `draw_cards(3)`)
- [ ] Discard-and-reshuffle triggers when deck hits 0 during `draw_cards()`

### 5. RunManager Integration
- [ ] `RunManager.current_health` written back after battle (player HP persistence)
- [ ] `RunManager.current_encounter` set by MapScene before loading battle
- [ ] `RunManager.player_attributes` dict read into `PlayerEntity` on battle start
- [ ] `RunManager.player_deck` used by `deck_manager.reset_deck()` when run is active
- [ ] `loot_reward.gd` draft_pool contains only valid card IDs that exist as JSON files

### 6. UI / UX
- [ ] `CharacterHUD.update_stats()` called after every HP/block change
- [ ] Block badge hidden when block == 0, shown with correct value otherwise
- [ ] `BattleUIManager` Q/E shortcuts open draw/discard pile viewers without crash
- [ ] `show_pile_viewer()` does NOT call `set_view_mode()` or `refresh_ui()` (those don't exist)
- [ ] `NotificationLabel` fades out after 1.5s (no permanent text on screen)

### 7. Node Reference Safety
- [ ] All `is_instance_valid()` checks before accessing nodes that may have been freed
- [ ] `get_node_or_null()` used instead of `$Path` for nodes that may not exist
- [ ] `enemy_container.get_children()` iterated with validity check each item

---

## Key Files to Review (in order)

| File | What to check |
|---|---|
| `battle_scene/battle_scene.gd` | is_resolving lock, RunManager init, _start_new_game |
| `battle_scene/combat_engine.gd` | Effect match block coverage, lunge animation restore |
| `battle_scene/enemy_ai.gd` | consume_next_action, victory check race condition |
| `battle_scene/enemy_entity.gd` | Factory JSON parse, action_pattern cycling, intent label |
| `battle_scene/deck_manager.gd` | draw_cards reshuffle, reset_deck RunManager path |
| `battle_scene/play_card.gd` | _handle_mouse_pressed/released routing |
| `battle_scene/card_play_zone.gd` | move_cards override passes null target |
| `run_system/core/run_manager.gd` | player_attributes, current_encounter fields |
| `run_system/ui/loot_reward.gd` | draft_pool card IDs validity |

---

## Known Architecture Decisions (do not flag as bugs)
- `battle_scene.gd` is intentionally the central orchestrator — sub-systems access it via `get_parent()` or `get_tree().current_scene`
- `CardPlayZone` overrides `move_cards()` instead of `on_card_move_done()` because `CardContainer` (unlike `Pile`) never calls `card.move()`, so `_on_move_done` never fires
- Attack cards use `_unhandled_input` / `_handle_mouse_released` chain instead of a targeting overlay (the overlay approach had zero-size bug)
- Enemy proximity detection uses `Rect2` body bounds + 110px fallback because enemies have no `Sprite2D`
