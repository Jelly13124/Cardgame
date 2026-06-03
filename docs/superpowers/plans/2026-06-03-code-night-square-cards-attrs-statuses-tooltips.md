# Code Night Implementation Plan

> Executes `docs/superpowers/specs/2026-06-03-code-night-square-cards-attrs-statuses-tooltips-design.md`.
> Gate per task: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
> → tail `[OK] DataValidator: all schemas passed.` Commit per task. **No push.**

**Goal:** Square cards, restore STR/CON description split, add Regen/Thorns/Frail/Dodge,
fill three tooltip gaps, add damage preview, drop one dead call.

**Order:** T0 → T1 → T5 → T2a → T2b → T2c → T3a → T3b → T3c → T4.

---

### T0 — Remove card-art shape mask
- Modify: `battle_scene/play_card.gd` (rm MASK_SHADER preload, `_mask_material`, mask block ~200–206).
- Delete: `battle_scene/card_art_mask.gdshader` (+ `.uid`) via `git rm`.
- [ ] Edit play_card.gd; `git rm` shader + uid.
- [ ] Smoke. Expected: green, no `card_art_mask` references.
- [ ] Commit `refactor(cards): remove attack-card art-shape mask — all cards square`.

### T1 — Card description STR/CON breakdown
- Modify: `battle_scene/play_card.gd` `_build_description` numeric calc (mirror combat_engine: mult→base, then +STR for damage / +CON for block; `(base+stat)` split only when stat>0; drop `scaling` path; str_mult & scale_by_attacks keep own formulas).
- [ ] Edit; verify against combat_engine rule.
- [ ] Smoke green.
- [ ] Commit `fix(cards): restore STR/CON breakdown in card descriptions`.

### T5 — Dead-code cleanup
- Modify: `battle_scene/relic_effect_system.gd` — remove only the dead Sharpened Scrap `_mark_used_once` call; keep all once_per_combat calls.
- [ ] Read surrounding match/if; delete the one dead call.
- [ ] Smoke green.
- [ ] Commit `chore(relics): drop dead Sharpened Scrap _mark_used_once call`.

### T2a — Status system: Regen/Thorns/Frail/Dodge core
- Modify: `battle_scene/status_effect_system.gd` (colors/labels/descriptions; regen in on_turn_start; frail in TURN_END_DECAY + `get_block_multiplier()`; `try_consume_dodge()`; thorns persistent getter).
- Modify: `battle_scene/data_validator.gd` ALLOWED_STATUS_NAMES += four.
- [ ] Edit both. Smoke green.
- [ ] Commit `feat(status): add regen/thorns/frail/dodge core + validator`.

### T2b — Combat hooks
- Modify: `battle_scene/combat_engine.gd` (dodge negation in 4 damage branches; frail mult in gain_block; `apply_thorns_reflection` helper + calls after player attacks land).
- Modify: `battle_scene/enemy_ai.gd` (thorns reflect enemy→player; dodge check before enemy hits player; frail on enemy block).
- [ ] Edit both. Smoke green.
- [ ] Commit `feat(combat): wire dodge/thorns/frail resolution hooks`.

### T2c — Content + i18n + wiring
- Create: `battle_scene/card_info/player/{patch_kit,spiked_guard,corrode}.json` (+ `_plus`).
- Modify: `run_system/core/meta_progress.gd` INITIAL_CARD_POOL += three.
- Modify: combat status translation CSV (EN+ZH) for the 4 statuses; reimport headless.
- [ ] Add JSON, wire pool, add i18n rows, reimport.
- [ ] Modify `chrome_hound.json` to add `apply_status_self dodge 1` action.
- [ ] Run content-balance + gdscript-reviewer subagents on new cards; address findings.
- [ ] Smoke green.
- [ ] Commit `feat(content): regen/thorns/frail cards + chrome_hound dodge + i18n`.

### T3a — Enemy intent tooltip
- Modify: `battle_scene/enemy_entity.gd` (intent badge hover → Tooltip; UI_BATTLE_INTENT_* i18n).
- [ ] Edit + i18n. Smoke green.
- [ ] Commit `feat(ui): enemy intent tooltips`.

### T3b — Card keyword glossary tooltip
- Modify: `battle_scene/play_card.gd` (`_on_mouse_entered`/`_on_mouse_exited` → keyword glossary via Tooltip, sourced from STATUS_DESCRIPTIONS; additive to hover tween).
- [ ] Edit. Smoke green.
- [ ] Commit `feat(ui): card keyword glossary tooltip`.

### T3c — Attribute-icon tooltips
- Modify: CharacterHUD + map character-info panel attribute icons → Tooltip; i18n.
- [ ] Locate the attribute icon widgets; add hovers. Smoke green.
- [ ] Commit `feat(ui): attribute icon tooltips`.

### T4 — Attack-damage preview
- Modify: drag-target code (`battle_scene/play_card.gd` and/or `battle_scene.gd`) → floating predicted-damage Label via `calculate_attack_damage`; single-enemy shows immediately; clears on drop/cancel.
- [ ] Locate drag/target flow; implement preview. Smoke green.
- [ ] Commit `feat(combat): attack damage preview on target`.

---

### Final
- [ ] Full smoke green.
- [ ] Leave all commits local (no push). Write morning summary of units done / any skipped + reasons.
