# ADR-0006: Reference custom classes via `const X = preload(...)`, not global `class_name`

## Status
Accepted

## Date
2026-05-19

## Context
Godot 4 supports two ways to reference a custom class from another file:

**Option A — global `class_name` registry:**
```gdscript
# in card_animator.gd
class_name CardAnimator
extends Node

# in battle_scene.gd
var card_animator: CardAnimator  # type reference by global name
```

**Option B — local preload constant:**
```gdscript
# in battle_scene.gd
const CARD_ANIMATOR_SCRIPT = preload("res://battle_scene/card_animator.gd")
var card_animator: Node  # typed as parent class
```

Option A is more ergonomic when it works. But on a **cold editor scan** — first launch after `git clone`, after `.godot/` cache deletion, or after a hot-reload involving new `class_name` files — the Godot parser processes files in an undefined order. If `battle_scene.gd` is parsed before the `class_name CardAnimator` registration completes, you get:

```
Parse Error: Could not find type "CardAnimator" in the current scope.
```

We hit this exact bug after adding two new `class_name` types (`CardAnimator`, `MapRenderer`) during the maintainability refactor. The project failed to load on a fresh editor restart.

## Decision
**Reference custom classes by `const X = preload("res://path/to/file.gd")` and `X.method()` / `X.new()`, not by the global `class_name`.**

Specifically:
- Type annotations use the parent class (e.g. `var enemy: Node2D`, not `var enemy: EnemyEntity`) OR drop the annotation.
- Static method calls go through the preload constant: `ENEMY_ENTITY_SCRIPT.create(id)`, not `EnemyEntity.create(id)`.
- The `class_name X` line in the defining file can stay — it doesn't hurt — but no other file relies on the global name.

The single exception is **autoload singletons** (e.g. `RunManager`): Godot guarantees autoload registration happens before any user script is parsed, so referencing them by their global name is safe.

## Alternatives Considered

### Alternative 1: Keep `class_name` references everywhere ← REJECTED
- **Pros:** More ergonomic. Type names look clean.
- **Cons:** Fails on cold scan, which is exactly when you most want the project to load (new contributor, CI runner, fresh checkout).
- **Why rejected:** Cold-scan failure is catastrophic — the editor literally can't load. Recovery requires deleting `.godot/` cache and restarting until parse order happens to work, which is brittle and confusing.

### Alternative 2: Use only `preload` constants ← CHOSEN
- **Pros:** Parse-order independent — `preload` resolves at parse time using string paths, no registry lookup. Works on every cold scan.
- **Cons:** Slightly more boilerplate (`const X = preload("res://...")` line + the `X.` prefix on calls). Loses some IDE assistance on type annotations.
- **Why chosen:** Cold-scan reliability is non-negotiable; ergonomic cost is small.

### Alternative 3: Mix of both based on perceived risk
- **Pros:** Type ergonomics where "safe", preload where "risky".
- **Cons:** "Safe" is unpredictable — adding any new `class_name` file in the future can break previously-working references via new parse-order interactions.
- **Why rejected:** The whole point of a rule is removing surprise. Mixed approach reintroduces it.

## Consequences

**Positive:**
- Project loads reliably on cold editor scan, fresh checkout, after `.godot/` cache deletion.
- Adding new classes doesn't risk breaking unrelated files.
- Behavior is deterministic regardless of file order.

**Negative / Trade-offs:**
- Each file using a custom class has a `const X = preload(...)` line at the top.
- Type annotations downgrade from specific (`EnemyEntity`) to parent class (`Node2D`) where the script type isn't an autoload.
- New contributors must know this rule, otherwise they'll write `class_name`-style references that work locally (with warm cache) but break for everyone else.

**Risks (and mitigations):**
- *Risk:* a contributor reintroduces `class_name`-style references. *Mitigation:* `docs/conventions/gameplay-code.md` calls this out explicitly. A future lint hook could grep for `var x: SomeCustomClassName` patterns.
- *Risk:* preload constants drift (file moves, constant doesn't update). *Mitigation:* Godot itself errors at parse time if `preload("res://wrong/path.gd")` doesn't exist — fail-loud.

## Revisit Triggers
- Godot fixes the cold-scan parse-order issue (then ergonomics tips back to `class_name`)
- We adopt a build tool that enforces parse order
- A tooling alternative emerges (e.g. typed autoload references that are class_name-safe)

## Related
- Affected files: every script that previously referenced a custom class by global name — `battle_scene.gd`, `map_scene.gd`, `enemy_ai.gd`, `combat_engine.gd`, `play_card.gd`, `relic_effect_system.gd`
- The bug that prompted this: cold-scan parse errors on `CardAnimator`, `MapRenderer`, and 5 older `EnemyEntity.create()` / `StatusEffectSystem.format_name()` sites
- ADR-0001 (autoload `RunManager`) — the documented exception
