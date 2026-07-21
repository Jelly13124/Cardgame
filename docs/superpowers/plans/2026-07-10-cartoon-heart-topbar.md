# Cartoon Heart Top Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the shared map/battle top bar's generic HP and XP bars with the approved sparse comic HUD using the existing UI03 cartoon heart and UI07 lightweight frame language.

**Architecture:** Keep `run_top_bar.gd` as the single shared map/battle component. Build deterministic Godot controls for heart + HP, compact level/XP + short cyan tick, caps, one tool tray, and the existing right utility group; reuse current imported PNG assets instead of generating a duplicate heart that may drift from the approved kit.

**Tech Stack:** Godot 4, GDScript, existing UI03/UI07 PNG assets, headless contract tests, screenshot capture scene.

## Global Constraints

- Preserve the current 80 px charcoal top-bar shell and irregular lower edge.
- Use `res://run_system/assets/images/ui_kit_lightline/icon_heart.png` for HP.
- Do not render a long HP progress bar or a long XP progress bar.
- XP remains visible as compact level/value text with a short cyan tick only.
- Keep caps as a frameless icon + number and tools as exactly one recessed slot.
- Keep floor, deck, settings, and timer functionality unchanged.
- The map and battle must continue to share the same top-bar implementation.

---

### Task 1: Lock the shared HUD contract

**Files:**
- Modify: `tests/ui_sts2_hud_contract_test.gd`
- Test: `tests/ui_sts2_hud_contract_test.tscn`

**Interfaces:**
- Consumes: runtime nodes built by `run_top_bar.gd`.
- Produces: contract names `HeartIcon`, `HpLabel`, `XpLabel`, and `XpTick` and the absence of `HpBar`/`XpBar`.

- [ ] Add assertions for the approved heart texture, compact labels, short tick, and removal of both progress bars.
- [ ] Run the HUD contract test and confirm it fails because the existing code still creates progress bars.

Run: locate the project Godot executable, then execute `godot --headless --path . --scene res://tests/ui_sts2_hud_contract_test.tscn`.
Expected: exit 1 with the new shared-top-bar assertions failing.

### Task 2: Implement the comic vitals component

**Files:**
- Modify: `run_system/ui/run_top_bar.gd`
- Test: `tests/ui_sts2_hud_contract_test.gd`

**Interfaces:**
- Consumes: `RunManager` HP, max HP, level, XP, and XP-to-next-level state already used by the existing refresh methods.
- Produces: named deterministic controls `HeartIcon`, `HpLabel`, `XpLabel`, and `XpTick`.

- [ ] Replace `_make_stat_bar` usage with a horizontal HP group using the cartoon heart and large value label.
- [ ] Build a compact XP group with secondary text and a maximum-width short cyan tick whose fill reflects XP progress.
- [ ] Update refresh logic without changing the source-of-truth data or signals.
- [ ] Keep caps, one tool shelf, relic row, floor, deck, settings, and timer behavior intact.
- [ ] Run the focused contract test and confirm exit 0.

### Task 3: Verify map and battle integration

**Files:**
- Use: `tests/ui_sts2_hud_visual_capture.tscn`
- Verify: `run_system/ui/run_top_bar.gd`

**Interfaces:**
- Consumes: the shared top bar in map and battle hosts.
- Produces: map and battle screenshots for visual inspection.

- [ ] Run the complete HUD contract test fresh.
- [ ] Run the visual capture scene and inspect both screenshots for clipping, overlap, hierarchy, and playfield obstruction.
- [ ] Run a headless project parse and `git diff --check` on touched files.
- [ ] Report any unrelated pre-existing dirty files without modifying them.
