---
name: create-enemy
description: Create a new enemy type (JSON data only). For full pixel art generation, use the add-enemy skill.
---

# Create Enemy

## Overview
Creates the JSON data file for a new enemy. Enemy behaviour is fully data-driven — no GDScript changes needed for standard `attack` / `block` / `heal` patterns.

> For full pipeline including **Wasteland Punk pixel art generation**, use the global `add-enemy` skill instead.

---

## Step 1 — Create the Enemy JSON

**Location:** `battle_scene/card_info/enemy/{enemy_id}.json`

**Template:**
```json
{
    "id": "enemy_id_here",
    "name": "Display Name",
    "sprite_id": "enemy_id_here",
    "max_health": 40,
    "action_pattern": [
        { "type": "attack", "amount": 8,  "label": "⚔ 8"  },
        { "type": "block",  "amount": 10, "label": "🛡 10" },
        { "type": "attack", "amount": 14, "label": "⚔ 14" }
    ]
}
```

**Fields:**

| Field | Type | Description |
|---|---|---|
| `id` | String | Matches the filename (without `.json`) |
| `name` | String | Displayed in the HUD and battle log |
| `sprite_id` | String | Subfolder name under `enemies/` for pixel art frames |
| `max_health` | int | Starting HP |
| `action_pattern` | Array | Ordered list of actions — cycles indefinitely |

**Action types:**

| `type` | Effect | `label` example |
|---|---|---|
| `attack` | Deals `amount` damage to the player | `"⚔ 8"` |
| `block` | Enemy gains `amount` block this turn | `"🛡 10"` |
| `heal` | Enemy heals `amount` HP | `"♥ 5"` |

The `label` is shown in the **intent badge** above the enemy — use emoji for instant readability.

**Design guidelines:**
| Tier | HP | Damage | Pattern |
|---|---|---|---|
| Normal | 20–40 | 5–10 | 2–3 attacks + 1 block |
| Elite | 40–70 | 8–15 | Mix of attack/block/heal |
| Boss | 80–120 | 12–20 | Complex multi-phase (future) |

---

## Step 2 — Generate Pixel Art (mandatory for non-placeholder enemies)

All enemies must have **Wasteland Punk pixel art** sprites. Use the global `add-enemy` skill for the full pipeline:

```powershell
powershell -ExecutionPolicy Bypass -File `
  "c:\Users\Jerry\Desktop\Cardgame\battle_scene\assets\images\enemies\generate_enemy.ps1" `
  -SpriteId     "enemy_id_here" `
  -Description  "your character description, wasteland punk style, post-apocalyptic scrap aesthetic, rusted metal and salvaged parts, single color bold black pixel art outlines, cel-shaded flat colors, earth tone palette with one neon accent color, transparent background, side view, full body, pixel art" `
  -IdleAction   "describe idle behavior" `
  -AttackAction "describe attack motion" `
  -NFrames 4
```

Expected output: `enemies/{sprite_id}/{sprite_id}_idle_0-3.png` + `_attack_0-3.png`

> See `project-rules.md §1` for the mandatory Wasteland Punk prompt suffix.

---

## Step 3 — Add to an Encounter

**During active run** (via `RunManager` before scene transition):
```gdscript
RunManager.current_encounter = ["robot_grunt", "new_enemy_id"]
get_tree().change_scene_to_file("res://battle_scene/battle_scene.tscn")
```

**Quick test fallback** — edit `enemy_ai.gd`:
```gdscript
var enemy_roster: Array[String] = ["new_enemy_id"]
```

Multiple enemies are positioned automatically (130px apart horizontally).

---

## Architecture Notes

- `EnemyEntity.create("enemy_id")` is the factory — reads JSON and returns a ready node
- Sprite frames loaded automatically from `enemies/{sprite_id}/` via `ENEMIES_DIR` constant
- `action_pattern` cycles via `consume_next_action()` → `_action_index % pattern.size()`
- Intent badge updates automatically after each `consume_next_action()` call
- `EnemyAI.execute_enemy_turn()` calls `consume_next_action()` for every enemy each turn
- Death → `died` signal → `EnemyAI._on_enemy_died()` → checks if last enemy → emits `victory_declared`
