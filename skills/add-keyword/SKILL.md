---
name: add-keyword
description: Create a new reusable keyword ability for unit cards
---

# Add Keyword

## Overview
Creates a new keyword ability that can be attached to any card (unit, hero, or spell) via its JSON `"keywords"` array. Keywords are modular behaviors (Shield, Taunt, Battle Cry, etc.) that hook into the combat lifecycle.

## Keyword Architecture

All keywords extend `KeywordBase` (`battle_scene/units/keywords/keyword_base.gd`).

**Available lifecycle hooks:**
| Hook | When it fires | Return |
|------|--------------|--------|
| `on_damage_taken(amount)` | Before damage is applied | Modified damage `int` |
| `on_deploy(row, slot_index)` | When unit is first played from hand | `void` |
| `on_before_attack(targets, row)` | Before attack resolves | Modified targets `Array` |
| `on_after_attack(targets, row)` | After attack resolves | `void` |
| `on_death()` | When unit health reaches 0 | `void` |

## Required Steps

### 1. Create the Keyword Script
- **Location:** `battle_scene/units/keywords/{keyword_name}.gd`
- **File name = keyword name** (this is how it's auto-loaded from JSON)

**Template:**
```gdscript
extends "res://battle_scene/units/keywords/keyword_base.gd"

## Description of what this keyword does
func on_deploy(row: Node, slot_index: int) -> void:
    if not is_instance_valid(unit) or not unit.get_parent(): return
    # Your keyword logic here
```

### 2. Choose the Right Hook
- **Defensive ability** (Shield, Armor) → `on_damage_taken()`
- **Entry effect** (Battle Cry) → `on_deploy()`
- **Attack modifier** (Wipe, Cleave) → `on_before_attack()`
- **Post-combat trigger** → `on_after_attack()`
- **Death trigger** (Deathrattle) → `on_death()`

### 3. Delegate to Custom Scripts (for card-specific effects)
If the keyword is a **generic trigger** (like Battle Cry) where each card does something different:
```gdscript
func on_deploy(row: Node, slot_index: int) -> void:
    if not is_instance_valid(unit) or not unit.get_parent(): return
    if unit.custom_script_instance and unit.custom_script_instance.has_method("execute_battle_cry"):
        unit.custom_script_instance.execute_battle_cry(row, slot_index)
```
Then create card-specific logic in `battle_scene/units/script_overrides/`.

If the keyword has **universal behavior** (like Shield always blocks 1 hit), implement it directly:
```gdscript
func on_damage_taken(amount: int) -> int:
    unit.show_notification("SHIELD BLOCKED!", Color.CYAN)
    # Remove shield after one use
    var idx = unit.keyword_instances.find(self)
    if idx != -1:
        unit.keyword_instances.remove_at(idx)
    return 0  # Block all damage
```

### 4. Wire to Cards
Add the keyword name to any card's (unit, hero, or spell) JSON `"keywords"` array:
```json
"keywords": ["your_keyword_name"]
```

The `_load_keywords()` function in `unit_card.gd` automatically discovers and instantiates the script based on the keyword name.

## Existing Keywords Reference
| Keyword | File | Behavior |
|---------|------|----------|
| `battle_cry` | `battle_cry.gd` | Generic trigger → delegates to `execute_battle_cry()` |
| `end_of_turn` | `end_of_turn.gd` | Fires at end of player turn |
| `taunt` | `taunt.gd` | Forces enemies to attack this unit first |
| `shield` | `shield.gd` | Blocks damage once |
| `one-time` | `one-time.gd` | Card goes to BlackHole pile instead of discard (permanently removed) |

## Important Rules
- **File name must match keyword name exactly** (lowercase, underscores)
- Keywords are loaded via `_load_keywords()` in `unit_card.gd` — no manual registration needed
- Use `unit.show_notification()` for visual feedback
- Use `unit.card_container` (not `unit.get_parent()`) to check board placement
- The `unit_stats_changed` signal on `battle_scene` propagates stat changes for passive listeners like Robot Bill
