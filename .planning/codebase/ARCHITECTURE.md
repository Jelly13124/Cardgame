# ARCHITECTURE
This document breaks down the logical design, layer structures, and state management systems of the application.

## Core Patterns
- **Singleton Pattern (Autoload)**: Global game state across scenes is managed by singletons (primarily `RunManager`).
- **Data-Driven Architecture**: Cards are rarely hardcoded; behavior is constructed via JSON definitions which dictates type, cost, attack, health, and modular keyword assignments.
- **Component Injection Model**: Larger complexes, like the `BattleScene`, spawn dedicated manager classes (e.g. `deck_manager.gd`) during initialization and inject Node references (like the specific Deck, Hand, Discard Pile) directly into them rather than relying purely on tree paths.

## Abstraction Layers
1. **Global Persistence Layer**: `run_manager.gd`. Retains deck composition (`player_deck` Array), `current_health` of Hero, `gold`, and `core` resources independent of which scene is currently loaded.
2. **Framework Layer**: `addons/card-framework`. Entirely agnostic to "Rick and Morty" theme. Handles `DraggableState` machine (Idle, Hovering, Holding, Moving) and math (hand fan splines).
3. **Application Layer**: `battle_scene.gd` logic. Encapsulates turn-based state (energy regeneration, drawing phase, attack phase). Reads global state to populate initial deck.
4. **Visual Layer**: `unit_card.gd`. Extends framework cards to process exact game specs. Modifies `TokenFace` vs `FrontFace` UI depending on current zone location.

## Data Flow (Run Initialization to Battle End)
`RunManager.start_new_run()` sets `current_hero_id` -> User loads into `battle_scene.tscn` -> `battle_scene.gd` instantiates `deck_manager.gd` -> Deck Manager reads global `RunManager.player_deck` -> instructs `CardFactory` -> `CardFactory` parses JSON and creates `UnitCard` nodes -> moved to `Hand` component container -> Turn progression cycles.
