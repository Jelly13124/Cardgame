# Conventions — Gameplay Code (GDScript)

Project-specific gameplay-code conventions and known-violation notes.

These are conventions the project **tries** to follow. Where we currently violate one, the violation is documented inline so it shows up in code review and doesn't get "fixed" without a deliberate decision.

---

## ✅ Active rules

### 1. All gameplay values come from external config / data files
Card costs, damage amounts, enemy HP, status durations — defined in JSON under `card_info/` and `data/`, never hardcoded in GDScript.

- **Why:** content authors can change balance without touching code; `DataValidator` validates the data shape at startup.
- **Enforced by:** `DataValidator` schema check on every project startup. Hardcoded numbers in GDScript bypass this — flag in review.

### 2. Use delta time for time-dependent calculations
Anything that should feel the same at 60 fps and 144 fps must use `delta` from `_process(delta)` or `tweens`, not fixed frame counts.

- **Enforced by:** code review only.
- **Current state:** mostly OK (we use tweens for animations); be careful if adding `_process()`-based timers later.

### 3. Reference custom classes via `preload`, not global `class_name`
```gdscript
# ✅ Correct
const ENEMY_ENTITY_SCRIPT = preload("res://battle_scene/enemy_entity.gd")
var enemy = ENEMY_ENTITY_SCRIPT.create(id)

# ❌ Wrong — fails on cold editor scan
var enemy: EnemyEntity = EnemyEntity.create(id)
```

- **Why:** Godot's `class_name` global registry is parse-order-dependent. Cold scans fail.
- **Exception:** autoloads (e.g. `RunManager`) are safe to reference globally — Godot guarantees their registration before user script parsing.

### 4. Access `RunManager` directly, never via `get_node_or_null`
```gdscript
# ✅ Correct
if RunManager.is_run_active:
    RunManager.gold += 10

# ❌ Wrong — boilerplate, fragile path string, no autocomplete
var rm = get_node_or_null("/root/RunManager")
if rm and rm.get("is_run_active"):
    rm.gold += 10
```

- **Why:** autoload guarantees `RunManager` exists; the `get_node_or_null` dance is dead defensive code.

### 5. Fail loud at startup, not silent in playtest
For data that ships with the game (cards, enemies, encounter pools):
- Use `push_error` + `assert` in the load path, not `push_warning`.
- `DataValidator` covers JSON; per-file load code (e.g. `EnemyEntity.create()`) should also assert on missing critical data.

For generated sprite assets: warn-only with a `ColorRect` fallback is OK because regeneration may be in flight.

### 6. New effect / action / status types must be registered in 2 places
Adding a new effect type to combat:
1. Add handler in `combat_engine._apply_effect()`.
2. Add the type string to `DataValidator.ALLOWED_EFFECT_TYPES`.

Same pattern for enemy action types (`ALLOWED_ENEMY_ACTION_TYPES`) and status names (`ALLOWED_STATUS_NAMES`).

- **Why:** the validator IS the schema. If validator doesn't know a type, it'll be silently allowed by JSON but the game might handle it inconsistently.

---

## ⚠️ Known violations (deliberate)

### A. UI/data layer coupling
**Rule (from Donchitos):** "NO direct references to UI code — use events/signals for cross-system communication."

**Our state:** `battle_scene.gd` directly calls `ui_manager.show_notification(...)`, `_update_ui_labels()`, etc. `combat_engine.gd` reaches up to `main.show_notification(...)`. Tight coupling between gameplay and UI.

**Why we ignore the rule:** decoupling via signals would require a project-wide event bus refactor (see the "M5" item in the audit). Cost is high; current pain is low. Tracked as deferred maintainability work.

**Reconsider when:** event bus becomes worth the cost (e.g. adding analytics, replay system, AI playtester).

### B. Static singleton (RunManager autoload)
**Rule (from Donchitos):** "No static singletons for game state — use dependency injection."

**Our state:** `RunManager` IS a static singleton.

**Why we ignore the rule:** for solo development before Steam launch, the
autoload's convenience and consistent global run state exceed the current
testability cost.

**Reconsider when:** we add unit tests as a first-class practice; or net play; or `run_manager.gd` exceeds 600 lines.

### C. Contract tests instead of a unit-test framework
**Rule (from Donchitos):** "Write unit tests for all gameplay logic — separate logic from presentation."

**Our state:** there is no third-party unit-test framework, but `tests/*.tscn` now
contains headless Godot contract tests for card systems, demo pools, encounters,
inventory, shops, transitions, UI layout, and combat feedback. DataValidator and
the clean headless boot remain the broad startup gates; manual/windowed playtests
are still required for feel and final visuals.

**Reconsider when:** contract-test setup becomes repetitive enough to justify a
shared test runner/plugin, or before Steam launch.

---

## Suggested workflow when adding gameplay

1. Define the JSON schema first (in `DataValidator` if new field types).
2. Implement the handler in `combat_engine.gd` / `enemy_ai.gd` / etc.
3. Add JSON content files.
4. Headless validate: `godot --headless --path . --quit-after 5` — should print `DataValidator: all card/enemy/relic JSON files passed schema check.`
5. Run the relevant `tests/*_contract_test.tscn` scene headlessly.
6. Playtest the new content in editor when behavior or visuals changed.
7. Regenerate `docs/catalog_html/` with `python scripts/gen_catalog_html.py`.

## When in doubt

- Read `docs/project-rules.md`, `docs/PROJECT_STRUCTURE.md`, and the relevant
  file under `docs/conventions/`.
- Update those current documents when a major system changes; do not create a
  separate historical decision file.
