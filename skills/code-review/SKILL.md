---
name: code-review
description: Perform an architectural code review of the Godot card game project
---

# Code Review

## Overview
Performs a structured code review of the card game project, checking for architectural issues, fragile patterns, and potential bugs.

## Review Checklist

### 1. String Fragility
- [ ] Check for raw `has_node("path/to/node")` patterns — should use `@export` variables or `get_node_or_null()`
- [ ] Check for raw string type comparisons like `type == "hero"` — should use `CardType` enum
- [ ] Check for hardcoded keyword strings — should match existing keyword script filenames exactly

### 2. Node Reference Safety
- [ ] Use `card_container` property instead of `get_parent()` to check board placement
- [ ] Use `is_instance_valid()` before accessing nodes that may have been freed
- [ ] Use `get_node_or_null()` instead of `$Path` for nodes that may not exist

### 3. Signal Architecture
- [ ] Stat changes should emit `unit_stats_changed` signal (via `add_permanent_stats` / `add_temporary_stats`)
- [ ] Avoid direct cross-script method calls where signals would decouple better
- [ ] Check signal connections are cleaned up when nodes are freed

### 4. State Management
- [ ] DraggableState transitions follow `allowed_transitions` rules
- [ ] `is_manual_attacking` flag is properly reset on cancel/complete
- [ ] `is_game_over` guards are present on all game-state-changing functions

### 5. Combat System
- [ ] Taunt enforcement is checked before allowing attacks
- [ ] `can_attack` flag is set/reset correctly each turn
- [ ] Attack animations properly restore card state (z_index, position, DraggableState)
- [ ] Board slot bounds use `TOTAL_SLOTS` (7) not hardcoded `3` or `4`

### 6. Energy & Resources
- [ ] `can_afford()` is checked before allowing card plays
- [ ] `spend_energy()` is called after successful deployment
- [ ] Spell fizzles refund energy correctly

### 7. Deck Management
- [ ] `deck_manager` handles all draw/shuffle logic (not `battle_scene` directly)
- [ ] Reshuffle from discard pile works when deck is empty
- [ ] Hand capacity limits are enforced

### 8. UI Consistency
- [ ] Card type-specific UI elements (attack/health circles) hide for spells
- [ ] Hero gold border/banner styling applies correctly
- [ ] Token view mode hides full card face and vice versa
- [ ] Font scaling relies on MSDF (no `_crisp_text` workarounds)

## Review Process

### Step 1: Scan Core Files
Examine these files in order of importance:
1. `battle_scene/battle_scene.gd` — Main game logic (God Object risk)
2. `battle_scene/unit_card.gd` — Card UI and combat stats
3. `battle_scene/deck_manager.gd` — Draw/shuffle logic
4. `battle_scene/battle_row.gd` — Board placement rules
5. `addons/card-framework/draggable_object.gd` — Drag state machine

### Step 2: Scan Script Directories
- `battle_scene/units/keywords/` — All keyword implementations
- `battle_scene/units/hero_scripts/` — Hero passive scripts
- `battle_scene/units/script_overrides/` — Unit-specific override scripts
- `battle_scene/spells/logic/` — Spell effect scripts

### Step 3: Cross-Reference JSON Data
- `battle_scene/card_info/player/units/` — Player card definitions
- `battle_scene/card_info/enemy/` — Enemy card definitions
- Verify all `passive_script_path` and `script_path` fields point to existing files
- Verify all keyword names in JSON have matching `.gd` files

### Step 4: Report
Produce a summary with:
- **Critical** — Bugs that will crash or break gameplay
- **Warning** — Architectural issues that make future changes dangerous
- **Info** — Suggestions for cleaner patterns

## Known Architectural Decisions
- `battle_scene.gd` is intentionally the main orchestrator (signals connect here)
- Cards use `card_info` dictionary from JSON (not typed classes) for flexibility
- The `card-framework` addon manages drag/drop state machine externally
- `deck_manager` is a runtime-instantiated Node (not in the scene tree by default)
