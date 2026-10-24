# Phase 4 Effect Definitions & Card Vars Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One definition per effect type, one card description generator used everywhere, card numbers written once as vars with upgrade deltas, generated enemy interrupt text.

**Architecture:** effect definitions registered next to handlers in `combat_effects.gd`, read through a static `effect_catalog.gd`; `battle_scene/card_description.gd` owns card text; ModelDb substitutes `$var` refs and keeps `effects_template`; `card_upgrade.gd` applies var deltas.

**Tech Stack:** Godot 4.6.3 GDScript, Python migration script, `tools/run_tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-10-24-phase4-effects-design.md`

## Global Constraints

- Every card's resolved effects and battle text (base and upgraded) stay byte-identical to the golden snapshot taken in Task 1.
- `core/` stays free of UI; `addons/` untouched; uid preloads; no new `class_name`.

## Review Focus

- Description differences hidden by the golden test's default stats (Strength/Constitution > 0, pipeline values in battle, ability-power descriptions, relic replay keyword).
- Cards whose `upgrade.effects` changed structure (not just numbers) must keep the replacement.
- `$var` refs in nested effect fields (e.g. `end_turn_in_hand`, enemy patterns) and missing vars must fail validation, not silently become 0.
- Gallery/discover text now generated: a card with an authored-only description (discover) must still read its authored text.

---

### Task 1: Golden snapshots
Create `tests/card_text_golden_test.gd` + `.tscn` with a `--capture` path (env `CAPTURE_GOLDEN=1`) that writes `tests/fixtures/golden/cards.json`: for every card id → `{text, effects, up_text, up_effects}` (text from a factory-built card outside battle, locale `en`; upgraded via `CARD_UPGRADE.resolve`). Capture on the unchanged code, commit the fixture; the normal run compares and fails on any difference. Commit `test: golden card text and effects`.

### Task 2: Effect definitions and catalog
Modify `core/effects/effect_registry.gd` (`register(type, handler, contexts, def := {})`, `definition`, `targets_enemy`), `battle_scene/combat/combat_effects.gd` (definitions with `target`, `params`, `upgrade` for every combat type), create `battle_scene/combat/effect_catalog.gd` (static `registry()`), and derive `DataValidator` card effect types/params, `play_card.data_requires_enemy_target`, `card_upgrade.formula` from it. Test `tests/effect_definitions_test.gd`: a fixture type registered with `{target: "enemy", params: ["amount"], upgrade: {amount: 1}}` is accepted by the validator, needs an enemy target, and its upgrade bumps `amount`; the catalog's combat types equal the old `ALLOWED_EFFECT_TYPES` set. Golden test stays green. Commit `refactor(effects): one definition per effect type`.

### Task 3: Description generator
Create `battle_scene/card_description.gd`; move `_build_description`, `_color_num`, keyword tags, `_colorize_keywords` and glossary from `play_card.gd`; per-type lines become `describe` callables in the definitions (verbatim). Golden + full suite green. Commit `refactor(cards): one card description generator`.

### Task 4: Card vars and upgrade deltas
Modify `core/content/model_db.gd` (substitute `$name` in card effects/upgrade effects; keep `effects_template`; load error for an unknown var), `run_system/core/card_upgrade.gd` (apply `upgrade.vars`), `battle_scene/data_validator.gd`; create `tools/migrate_card_vars.py` and migrate `content/cards/*.json`. Test additions in `tests/model_db_test.gd` (substitution, unknown var error) and golden green. Commit `refactor(cards): card numbers as vars with upgrade deltas`.

### Task 5: Generated text in gallery, discover, shop, upgrade preview
Gallery (`home_base_scene.gd`) and discover (`play_card` authored path) use the generator. Test: gallery slot text for `base:strike` equals the generator text. Commit `feat(ui): every card view shows the generated description`.

### Task 6: Intent text instead of labels
Remove `label` from `content/monsters/*.json`; interrupt message uses the enemy's generated intent text; validator rejects `label`. Test in `tests/enemy_intent_parity_test.gd` or new: interrupt text for an attack action contains the amount. Commit `refactor(enemies): generated intent text replaces hand-written labels`.
