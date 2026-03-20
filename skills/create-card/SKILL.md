---
name: create-card
description: Create a new unit, spell, or hero card with JSON data, art reference, and optional scripts
---

# Create Card

## Overview
Creates a new card for the game. This includes the JSON data definition, art path setup, and optional keyword/passive script wiring.

## Card Types
- `unit` — Standard deployable unit with attack/health
- `spell` — One-time effect card, no attack/health circles shown
- `hero` — Unique hero unit with passive ability, gold border styling

## Required Steps

### 1. Create the JSON Card Data
- **Location:** `battle_scene/card_info/player/units/{card_name}.json`
- **Enemy cards:** `battle_scene/card_info/enemy/{card_name}.json`

**Required fields for ALL card types:**
```json
{
    "name": "card_id_here",
    "display_name": "Human Readable Name",
    "type": "unit",
    "side": "player",
    "cost": 1,
    "front_image": "player/units/card_id_here.png",
    "description": "Card description text.",
    "race": "robot"
}
```

**Additional fields for units/heroes:**
```json
{
    "health": 5,
    "attack": 3,
    "keywords": []
}
```

**Additional fields for heroes:**
```json
{
    "passive_script_path": "res://battle_scene/units/hero_scripts/hero_name.gd"
}
```

**Additional fields for spells:**
```json
{
    "target_type": "unit"
}
```
`target_type` can be: `"unit"`, `"row"`, or `"none"`.

### 2. Generate Card Art via Nano Banana
Use the `generate_image` tool (Nano Banana) to create the card artwork.
- **Art style:** Rick and Morty cartoon style — bold outlines, vibrant colors, exaggerated proportions, sci-fi theme.
- **Prompt format:** `"Rick and Morty style sci-fi [description of the unit/spell], bold outlines, vibrant colors, card game art, no text"`
- Save the generated image to the correct asset folder:
  - **Player units:** `battle_scene/assets/images/cards/player/units/`
  - **Player heroes:** `battle_scene/assets/images/cards/player/heroes/`
  - **Enemy units:** `battle_scene/assets/images/cards/enemy/`
- Art file name must match the `front_image` path in the JSON.

### 3. Wire Keywords (if applicable)
- Add keyword names to the `"keywords"` array in the JSON.
- Keywords work on **all card types** (units, heroes, AND spells).
- Keywords MUST reference existing keyword scripts in `battle_scene/units/keywords/`.
- **DO NOT** create new keyword scripts here — use the `add-keyword` skill for that.
- Available keywords: `battle_cry`, `end_of_turn`, `taunt`, `shield`, `wipe`, `one-time`

### 4. Wire Custom Scripts (if applicable)
- **Hero passives:** Create script in `battle_scene/units/hero_scripts/` and set `"passive_script_path"` in JSON.
- **Unit overrides:** Create script in `battle_scene/units/script_overrides/` and set `"passive_script_path"` in JSON.
- **Spell logic:** Create script in `battle_scene/spells/logic/` extending `spell_logic_base.gd`. The file name must match the card `"name"` field.

### 5. Add to Starting Decks (if needed)
- Edit the hero's JSON `"starting_pool"` array to include the new card's name.
- Or add it to the draft reward pool in the run system.

## Architecture Notes
- Card UI is handled by `unit_card.gd` with the `CardType` enum: `UNIT`, `SPELL`, `HERO`
- The `card_factory` auto-loads JSON and creates card instances at runtime
- All stat modifications should use `add_permanent_stats()` or `add_temporary_stats()` which emit the `unit_stats_changed` signal
- Card containers use `card_container` property (not `get_parent()`) to determine board placement
