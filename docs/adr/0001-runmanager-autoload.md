# ADR-0001: RunManager as autoload singleton

## Status
Accepted

## Date
2026-05-18

## Context
The game has scene transitions between hero select → map → battle → loot → map → ... → boss → loot. Each scene needs to read and write shared run state: player HP, gold, deck, equipped relics, current floor, current encounter, map progression, etc.

Godot scenes are independent — they don't share memory across `change_scene_to_file()`. We need some mechanism to persist that state across scene loads.

## Decision
`RunManager` is registered as an **autoload singleton** in `project.godot`. It is a `Node` instance that exists for the lifetime of the game process. Any script (in any scene) references it directly by the global identifier `RunManager`:

```gdscript
if RunManager.is_run_active:
    RunManager.gold += 10
```

No `get_node_or_null("/root/RunManager")` lookups. No DI passing through scene-load APIs.

## Alternatives Considered

### Alternative 1: Dependency injection (constructor / setter)
- **Pros:** Highly testable. Each scene gets a `RunManager` reference at load, can be mocked.
- **Cons:** Godot's `change_scene_to_file()` doesn't natively support passing arguments to the new scene's root. Would need an awkward parking-spot pattern (set a global var, scene reads it on `_ready`). Boilerplate every scene transition.
- **Why rejected:** Friction every time you switch scenes; solving with a parking-spot global just reinvents the singleton anyway.

### Alternative 2: `SaveData` Resource passed between scenes
- **Pros:** Natural fit for save/load (just `ResourceSaver.save(save_data, ...)`).
- **Cons:** Each scene would `load()` the resource and operate on its own copy, requiring careful write-back on every state change. Easy to miss a write and get state drift.
- **Why rejected:** Synchronization burden too high during active battle (block / energy / HP all changing constantly). We can still wrap `RunManager` in a save Resource later when we add persistence.

### Alternative 3: Autoload singleton ← CHOSEN
- **Pros:** Godot-native. Always available without lookup. Editor knows about it for autocompletion. One source of truth.
- **Cons:** Global state — hard to unit-test in isolation. A single mutating autoload couples every scene to one concrete type.
- **Why rejected → why accepted:** For a solo dev pre-Steam game with no unit tests planned, the testability cost is theoretical. The convenience is concrete.

## Consequences

**Positive:**
- Any script writes `RunManager.field` directly — IDE autocomplete works.
- No `get_node_or_null("/root/RunManager")` boilerplate (we removed all 7 sites in the maintainability refactor).
- Field typo becomes compile-time-ish error (Godot flags at parse time).

**Negative / Trade-offs:**
- `RunManager` will accumulate responsibilities and grow into a god class. Already 450+ lines covering HP, gold, deck, map gen, encounter pools, debug input. Splitting it later will require touching every caller.
- Cannot easily mock for unit tests.
- The `is_run_active` flag has to be checked everywhere — there's no compile-time distinction between "during a run" and "outside a run" state.

**Risks (and mitigations):**
- *Risk:* god class outgrows comprehension. *Mitigation:* deferred maintainability work to split into `PlayerState` / `MapState` / `RunResources` / `MapGenerator` once it crosses ~600 lines.
- *Risk:* autoload init order issues if other autoloads depend on `RunManager`. *Mitigation:* currently only one autoload, so N/A. Document load order in `project.godot` if a second autoload is added.

## Revisit Triggers
- We add unit tests as a first-class practice (mocking becomes a hard need)
- We add multiplayer / netplay (singleton clashes with multi-session state)
- `run_manager.gd` exceeds 600 lines (split required regardless)
- We need multiple concurrent runs in memory (e.g. spectator mode)

## Related
- Most affected files: `run_system/core/run_manager.gd`, plus 7 callers (loot_reward, map_scene, hero_select, battle_scene, enemy_ai, deck_manager, battle_top_bar)
- Related: ADR-0006 (preload pattern) — `RunManager` autoload bypasses the cold-start class_name issue because Godot guarantees autoloads are registered before user script parsing
