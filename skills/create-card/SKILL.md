---
name: create-card
description: Create a new player card (attack, skill, or ability) with JSON effects data and Wasteland Punk pixel art
---

# Create Card

## Overview
Creates a new card for the roguelite card game. Each card is a JSON file with an `effects` array that the `CombatEngine` resolves generically — no GDScript changes needed for standard effects.

## Card Types

| Type | Play Method | Target |
|---|---|---|
| `attack` | Click → drag arrow → release on enemy | Enemy unit |
| `skill` | Drag card upward into play zone | No target (self) |
| `ability` | Drag card upward into play zone | No target (self) |

---

## Step 1 — Create the JSON File

**Location:** `battle_scene/card_info/player/{card_name}.json`

**Full template:**
```json
{
    "name": "card_id_here",
    "title": "Human Readable Title",
    "type": "attack",
    "cost": 1,
    "description": "Deal [b]6+Strength[/b] damage.",
    "front_image": "player/card_id_here.jpg",
    "side": "player",
    "effects": [
        { "type": "deal_damage", "amount": 6, "scaling": "strength" }
    ]
}
```

**Required fields:** `name`, `title`, `type`, `cost`, `description`, `side`, `effects`  
**Optional fields:** `front_image` (path relative to `battle_scene/assets/images/cards/`)

---

## Step 2 — Choose Effects

The `CombatEngine` resolves every item in `effects[]` in order:

| effect `type` | What it does | `scaling` options |
|---|---|---|
| `deal_damage` | Deal damage to the targeted enemy | `strength`, `luck` |
| `deal_damage_all` | Deal damage to ALL enemies | `strength` |
| `gain_block` | Player gains block this turn | `constitution` |
| `gain_strength` | Permanently increase Strength | — |
| `gain_constitution` | Permanently increase Constitution | — |
| `gain_intelligence` | Permanently increase Intelligence | — |
| `gain_luck` | Permanently increase Luck | — |
| `gain_charm` | Permanently increase Charm | — |
| `gain_energy` | Give extra energy this turn | — |
| `draw_cards` | Draw additional cards | — |
| `apply_status` | Apply status to a target enemy | — |
| `apply_status_self` | Apply status to the player | — |
| `apply_status_all` | Apply status to all enemies | — |

**`scaling`**: adds `player.<scaling>` to `amount` at resolution time.

**Player attributes (五维属性):** `strength` / `constitution` / `intelligence` / `luck` / `charm`

**Multi-effect example:**
```json
"effects": [
    { "type": "deal_damage", "amount": 5, "scaling": "strength" },
    { "type": "draw_cards",  "amount": 1 }
]
```

---

---

## Step 3 — Generate Card Art (Wasteland Punk Pixel Art)

**Card images must be high-quality JPGs** — static illustrations distinguish them from animated character sprites (which are PNG).

**Workflow:**
1. Use the **`gen-card-art`** skill to generate a custom 16-bit wasteland illustration using **Nano**.
2. Follow the `gen-card-art` instructions to convert the result to **JPG** and save it to `battle_scene/assets/images/cards/player/`.
3. Set the resulting path in your JSON:
```json
"front_image": "player/your_card_id.jpg"
```

> **Legacy Cleanup:** Ensure any old `laser_gun.jpg` or `holographic_shield.jpg` placeholders are replaced with your newly generated tactical art.

---

## Step 4 — Add to Deck Pool (if needed)

To include the card in the **starter deck**, add its name to `deck_manager.gd`:
```gdscript
var list = [
    "strike", "strike", "strike", "strike",
    "defend", "defend", "defend", "defend",
    "overdrive",
    "your_new_card"  # ← add here
]
```

To include it in the **draft reward pool** (drawn after battle), add to `loot_reward.gd`:
```gdscript
var draft_pool = ["strike", "defend", "overdrive", "your_new_card"]
```

---

## Architecture Notes

- Card JSON is auto-discovered from `battle_scene/card_info/player/` — no registration needed
- `CombatEngine._apply_effect()` handles all effect dispatch — add new effect types there only
- `PlayCard._handle_mouse_pressed()` routes `attack` vs `skill/ability` based on `card_info["type"]`
- Enemy cards use a different schema — see `create-enemy` skill
- `constitution` is the correct attribute name — `defense` no longer exists
