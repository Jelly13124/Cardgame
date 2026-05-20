# ADR-0002: `card_info` as Dictionary, not typed Resource

## Status
Accepted

## Date
2026-05-18

## Context
Card definitions live as JSON files in `battle_scene/card_info/player/{id}.json`. Each card has a name, type, cost, rarity, an `effects[]` array, and a few optional flags (`retain`, `front_image`, etc.).

When a card is instantiated at runtime, the JSON is parsed into a `Dictionary` and stored on the `Card` instance as `card_info: Dictionary`. Every code path reads via `card.card_info.get("type", "skill")`, `card.card_info.get("retain", false)`, etc.

Godot offers a more typed alternative: define a `CardData` Resource class with explicit properties (`@export var type: String`, `@export var cost: int`, ...), serialize to `.tres` instead of `.json`, and pass typed `CardData` references around.

Same situation exists for enemies (`enemy.json` → Dictionary) and relics.

## Decision
Stay with **`Dictionary` from parsed JSON** for card / enemy / relic data. Do not migrate to typed `Resource` classes.

Mitigate the typo / silent-failure risk with a **load-time schema validator** (`DataValidator` in `battle_scene/data_validator.gd`) that scans every JSON at startup and fails loud on unknown keys, unknown effect types, missing required fields, and (for enemies) unknown action types or status names.

## Alternatives Considered

### Alternative 1: Typed `CardData` Resource (with `.tres`)
- **Pros:** Full IDE autocomplete on `card.cost` vs `card.card_info.get("cost", 0)`. Typo becomes compile-time error. `effects[]` could be typed too (each effect = its own `Effect` Resource subclass with polymorphic `apply()`).
- **Cons:** JSON is currently the source of truth — easily hand-edited and grep'd. Migrating to `.tres` loses that. Resource serialization in Godot has gotchas (sub-resource references, version migration when fields change). Subclassing Effect into 13 types adds a lot of files without changing runtime behavior.
- **Why rejected:** The migration cost is high (~30 JSONs + every card-reading code path + every effect-handling site) and the type-safety win is largely replicated by the validator.

### Alternative 2: `Dictionary` + JSON Schema validation ← CHOSEN
- **Pros:** Keep JSON ergonomics (grep, hand-edit, codex can generate). Single startup validator catches typos before play. Adding new effect types = 2 places (combat_engine + validator).
- **Cons:** No editor autocompletion on `card_info.X` (it's untyped Dictionary). Reading `card_info.get("foo", default)` is slightly noisier than `card.foo`.
- **Why chosen:** Validator gives 80% of the typo protection for 10% of the migration cost.

### Alternative 3: Pure `Dictionary`, no validation (status quo before P3 of refactor)
- **Pros:** Simplest, no validator to maintain.
- **Cons:** Typos surface in playtest, not at load. Already burned us once.
- **Why rejected:** Unacceptable as content scales toward Steam (100+ cards, 50+ enemies).

## Consequences

**Positive:**
- JSON files remain the single hand-editable source of truth.
- Codex can read/write JSON directly without learning Godot's Resource serialization.
- DataValidator runs on every startup; typos become startup errors, not playtest bugs.

**Negative / Trade-offs:**
- All consumers of `card_info` use `.get("key", default)` instead of typed property access. Verbose and silent-failure-prone for keys the validator doesn't yet know about.
- IDE doesn't autocomplete `card_info` fields.
- The validator must be kept in sync — every new effect type means updating both `combat_engine._apply_effect()` and `DataValidator.ALLOWED_EFFECT_TYPES`.

**Risks (and mitigations):**
- *Risk:* validator drifts out of date with code. *Mitigation:* the "adding a new effect" checklist in `docs/catalog-cards.md` explicitly says "update both". If automation is wanted later, a unit test could parse `combat_engine.gd` and diff against the validator constants.
- *Risk:* a typo in a key the validator doesn't yet check (e.g. an optional flag) silently no-ops. *Mitigation:* validator emits `push_warning` for unknown top-level keys per card.

## Revisit Triggers
- Card count exceeds ~100 and `.get()` boilerplate becomes painful to read
- We add visual editing tools (then `.tres` + `CardData` becomes cleaner)
- We need polymorphic effects (e.g. an effect that itself produces sub-effects)
- IDE auto-suggest becomes a bottleneck

## Related
- Most affected files: `battle_scene/data_validator.gd`, `battle_scene/combat_engine.gd`, `battle_scene/play_card.gd`, all `card_info/**/*.json`
- Related: ADR-0005 (codex owns content generation — codex prefers JSON over .tres)
