# STRUCTURE
This document outlines the directory layout, key locations, and specific naming conventions.

## Directory Layout
- **`.planning/`**: Agent workflow templates and meta-documentation (STACK, ARCHITECTURE, etc).
- **`addons/card-framework/`**: Submodule containing general, reusable logic that operates the card containers, hover scaling, math (splines) and physics. Should remain independent of the specific game's logic.
- **`battle_scene/`**: The core active battle map.
  - `card_info/`: Divided into `player/` and `enemy/`. Also further categorized into `units/` and `spells/`. Holds the `.json` configurations.
  - `units/keywords/`: Subscripts applied programmatically based on the configuration (e.g., `taunt.gd`, `one-time.gd`).
  - `units/hero_scripts/`: Defines specific Hero implementations.
- **`run_system/`**: Rogue-lite mechanics beyond the single battle.
  - `core/run_manager.gd`: Autoload tracking run progression and resources (gold, core).
  - `ui/`: Meta-progression interfaces like hero selection grids prior to starting a run.

## Naming Conventions
- **Code Files (.gd):** `snake_case` corresponding to logical components (e.g., `deck_manager.gd`).
- **Nodes/Classes:** `PascalCase` matching typical GDScript rules.
- **JSON Configurations:** Consistent prefixing for clarity (`unit_defend_drone.json`, `spell_shield.json`).
