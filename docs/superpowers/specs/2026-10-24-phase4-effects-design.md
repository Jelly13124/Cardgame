# Phase 4 — Effect definitions, card variables, one description generator

Status: decided by the agent under the owner's delegation ("follow the STS2
architecture as much as possible"). Gameplay must not change; every card text
that exists today must read the same in battle.

Roadmap items: S2-02 (one effect type's knowledge in 7 places), S2-03 (card
numbers and texts copied several times; gallery and discover show hand-written
text), S2-04 (upgrades replace whole effect lists or use a hidden formula),
S4-05 (enemy intent labels hand-write numbers).

## Problem

- Adding an effect type touches: the handler registration
  (`combat_effects.gd`), the card-face description `match` in `play_card.gd`
  (~25 branches), `play_card.ENEMY_TARGET_EFFECTS`, `DataValidator`
  (`ALLOWED_EFFECT_TYPES` + per-type checks), the upgrade formula
  (`card_upgrade.gd`), discover theme detection and the damage preview.
- The card face builds its text from `effects`, but the base gallery and
  discover use the hand-written `CARD_<id>_DESC` rows, which drift from the
  JSON numbers.
- 17 cards repeat their whole effect list in `upgrade.effects` to change one
  number; 21 cards rely on an implicit formula.
- Enemy actions carry hand-written `label`s like `"⚔ 10"` that duplicate the
  amount and are not translated (used for the "interrupted" message).

## STS2 reference

A card's numbers are `DynamicVars` (`Damage`, `Block`, …); its description is a
localization template filled from those vars by one code path, used by the
card face, the upgrade preview and every other view. Upgrades are var deltas
(`DynamicVars.Damage.UpgradeValueBy(2)`). Intents are generated from the move's
intent type and computed value.

## Design

### Effect definitions — one place per type

- `core/effects/effect_registry.gd`: `register(type, handler, contexts, def := {})`
  stores an optional definition per type:
  - `target`: `"enemy"` (needs an enemy target), `"self"`, `"all"`, `"none"`;
  - `params`: required keys (validator);
  - `upgrade`: default upgrade deltas `{field: delta}` (the old formula);
  - `describe`: `func(effect: Dictionary, view: Dictionary) -> PackedStringArray`
    returning the card-face lines (empty for keyword-only effects).
  `definition(type)`, `targets_enemy(type)` and `types(context)` read them.
- The combat handler module (`battle_scene/combat/combat_effects.gd`) registers
  each type with its handler and definition together; the describers move
  there from `play_card.gd` verbatim.
- `battle_scene/combat/effect_catalog.gd` (static) builds one shared registry
  (combat + enemy + run contexts) for code that runs outside a battle:
  validator, card UI, upgrade resolver, discover.
- Derived from the catalog (their own lists are deleted):
  `DataValidator` allowed card effect types and required params,
  `play_card.ENEMY_TARGET_EFFECTS`, `card_upgrade.formula`.

### One description generator

- `battle_scene/card_description.gd` (static) owns the card text: header
  logic, per-effect lines from the definitions, keyword tags (Replay, Retain,
  Exhaust …), keyword colouring and the glossary. `play_card.gd` keeps layout
  only and calls it. The `view` passed to describers holds the stats, the
  pipeline preview values and the card's own data.
- The base gallery, discover candidates, shop cards and the upgrade preview
  all show generator text (gallery/discover stop reading `CARD_<id>_DESC`).
  Authored text remains only for effect types whose definition has no
  describer (today `discover`, which reads its authored description).

### Card variables and upgrade deltas

- A card may declare `vars` (`{"damage": 6, "weak": 1}`); any effect field
  may be `"$name"`. The ModelDb loader (the owner of card data) keeps the raw
  list as `effects_template` and stores `effects` with numbers substituted, so
  every existing consumer reads plain numbers.
- `upgrade` gains `vars` (deltas, e.g. `{"damage": 3}`); `card_upgrade.resolve`
  applies them to `vars` and re-substitutes `effects_template`. `upgrade.effects`
  (structural replacement) and `cost` stay; a card with neither falls back to
  the definitions' default deltas (the old formula, now explicit per type).
- All 45 cards are migrated by `tools/migrate_card_vars.py`: numeric effect
  fields become vars named by role (`damage`, `block`, `draw`, `energy`,
  `<status>`, …); an `upgrade.effects` list that differs only in numbers
  becomes `upgrade.vars`; formula cards get explicit `upgrade.vars`.
- Validator: every `$name` resolves to a var; `upgrade.vars` keys exist.

### Enemy intents

Monster actions lose `label`; the interrupt message uses the generated intent
text (the same text as the intent tooltip). An optional `move` key names a
localized move (`ENEMY_<id>_MOVE_<move>`) for flavour.

## Acceptance

- Golden test: for every card, base and upgraded, the generated description
  (outside battle, default stats) and the resolved `effects` are identical to
  snapshots taken from main before the refactor.
- Adding an effect type changes one file (its registration with handler and
  definition) plus data; a test registers a fixture type and sees the
  validator, targeting and description pick it up.
- Gallery and discover show the generator's text.

## Out of scope

Multi-level upgrades (one level today), localization of authored card titles,
event effect describers.
